"""The Coach Agent graph, shared by all five modes (LangGraph core only;
ADR-002, D-90; T-AGT-04, D-98).

    START -> assemble_context -> coach_draft -> (valid draft) -> safety_post
                                     ^   |                         |
                                     |   +-(invalid JSON, retry)   +-> approve -> finalize -> END
                                     +-------(rewrite, once)-------+
                                         (anything else) -----------> fallback -> END

Safety.pre (rules, then the input classifier), consent, the prompt and any
retrieval have already run before this graph is invoked (coach.py). The mode
(`ModeSpec`) only changes what the model sees, the prompt, the length limit,
the output schema and the fixed buttons; the safety path is the same for every
mode. `safety_post` runs the rules, the grounding check (a health fact needs a
cited approved passage that was actually provided) and, on a draft both
approve, the output classifier, which can only escalate (a failed classifier
blocks). `finalize` is reachable only from `safety_post`, so no model text
leaves the graph without the post-check. The model is called at most
MAX_MODEL_CALLS times per run (one retry, for invalid JSON or a rewrite).
"""

from __future__ import annotations

import time
import uuid
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Any, TypedDict

from langgraph.graph import END, START, StateGraph
from pydantic import ValidationError

from livewell_agents.content.models import Passage
from livewell_agents.model_client import ModelClient, ModelRequest
from livewell_agents.models import (
    Barrier,
    CoachDraft,
    CoachMessage,
    CoachMode,
    Route,
    SafetyInfo,
    Source,
    UserContext,
    draft_json_schema,
)
from livewell_agents.prompts import Prompt, tag_safe_json
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.postcheck import (
    MAX_CHARS,
    PostCheckResult,
    combine_post,
    escalate_post,
    grounding_check,
    personal_text_check,
    post_check,
)
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import MESSAGE_TYPES, MODE_ACTIONS, CoachFallbacks
from livewell_agents.tracing import set_attrs, span

MAX_MODEL_CALLS = 2

#: Free-text fields a request brings (screened by Safety.pre like the context).
MESSAGE_FIELD = "message"
REFLECTION_FIELD = "reflection.text"


class CoachState(TypedDict, total=False):
    uid: str
    mode: CoachMode
    context: UserContext
    withheld_fields: tuple[str, ...]
    #: Checks already passed before the graph (e.g. safety_pre, the input classifier).
    pre_checks: tuple[str, ...]
    prompt: Prompt
    #: The request's own inputs (message, reflection text, time of day, stats).
    inputs: dict[str, object]
    #: Approved passages from the retriever (grounded modes only).
    passages: tuple[Passage, ...]
    model_context: dict[str, object]
    blocks: dict[str, object]
    attempts: int
    feedback: tuple[str, ...]
    draft: CoachDraft | None
    failure: str | None
    served_model: str | None
    post: PostCheckResult | None
    message: CoachMessage
    route: Route
    barrier: Barrier | None


#: The T-AGT-01 name, kept for callers.
BriefingState = CoachState


# ------------------------------------------------------------------ what the model sees


def model_context(ctx: UserContext, withheld: tuple[str, ...]) -> dict[str, object]:
    """The screened context, minus withheld fields and minus check-in notes
    (free text no mode needs)."""
    out: dict[str, object] = {
        "local_date": ctx.local_date.isoformat(),
        "weekday": ctx.local_date.strftime("%A"),
        "streak_days": ctx.streak_days,
        "ed_safe_mode": ctx.ed_safe_mode,
    }
    # D-96: an instruction-like coach name is withheld like any other field.
    if "coach_name" not in withheld:
        out["coach_name"] = ctx.coach_name
    if "first_name" not in withheld:
        out["first_name"] = ctx.first_name
    if ctx.why and "why" not in withheld:
        out["why"] = ctx.why
    if ctx.focus_driver and "focus_driver" not in withheld:
        out["focus_driver"] = ctx.focus_driver
    if ctx.plan_step and "plan_step.title" not in withheld:
        out["plan_step"] = ctx.plan_step.model_dump(exclude_none=True)
    if ctx.last_checkin:
        c = ctx.last_checkin
        out["last_checkin"] = {
            "days_ago": (ctx.local_date - c.day).days,
            "mood_1_to_5": c.mood,
            "energy_1_to_5": c.energy,
            **({"sleep_1_to_5": c.sleep} if c.sleep is not None else {}),
            **({"stress_1_to_5": c.stress} if c.stress is not None else {}),
        }
    return out


Blocks = tuple[dict[str, object], dict[str, object]]


def _briefing_ctx(ctx: UserContext, withheld: tuple[str, ...], _: Mapping[str, object]) -> Blocks:
    return model_context(ctx, withheld), {}


def _reply_ctx(ctx: UserContext, withheld: tuple[str, ...], inp: Mapping[str, object]) -> Blocks:
    return model_context(ctx, withheld), {"message": inp[MESSAGE_FIELD]}


def _reflection_ctx(
    ctx: UserContext, withheld: tuple[str, ...], inp: Mapping[str, object]
) -> Blocks:
    return model_context(ctx, withheld), {"reflection": inp[REFLECTION_FIELD]}


def _nudge_ctx(ctx: UserContext, withheld: tuple[str, ...], inp: Mapping[str, object]) -> Blocks:
    """A nudge may be read on a lock screen (AGENTS.md: nothing personal or
    health-related in notifications): no name, no Why, no check-in values."""
    out: dict[str, object] = {
        "time_of_day": inp["time_of_day"],
        "weekday": ctx.local_date.strftime("%A"),
        "ed_safe_mode": ctx.ed_safe_mode,
    }
    if "coach_name" not in withheld:
        out["coach_name"] = ctx.coach_name
    if ctx.plan_step and "plan_step.title" not in withheld:
        out["plan_step"] = ctx.plan_step.model_dump(exclude_none=True)
    return out, {}


def _weekly_ctx(ctx: UserContext, withheld: tuple[str, ...], inp: Mapping[str, object]) -> Blocks:
    """The week's numbers come precomputed (Insights Agent, T-AGT-06, later);
    the last single check-in is left out: the trends describe the week."""
    out = model_context(ctx, withheld)
    out.pop("last_checkin", None)
    return out, {"week": inp["stats"]}


@dataclass(frozen=True)
class ModeSpec:
    mode: CoachMode
    prompt_id: str
    #: First line of the model's user message.
    task: str
    max_chars: int
    #: Retrieves approved passages and asks for source_ids (spec 9.4 step 5).
    grounded: bool
    #: Asks for a barrier code (reflection, FR-DLY-05).
    barrier: bool
    build: Callable[[UserContext, tuple[str, ...], Mapping[str, object]], Blocks]
    #: The request's own text field. If it looks like instructions it is
    #: withheld, and with nothing left to answer the fixed text is used.
    primary_field: str | None = None

    @property
    def json_schema(self) -> dict[str, object]:
        return draft_json_schema(sources=self.grounded, barrier=self.barrier)


MODES: dict[CoachMode, ModeSpec] = {
    "briefing": ModeSpec(
        "briefing",
        "coach_briefing",
        "Write today's morning briefing for this person.",
        MAX_CHARS,
        grounded=False,
        barrier=False,
        build=_briefing_ctx,
    ),
    "reply": ModeSpec(
        "reply",
        "coach_reply",
        "Answer this person's message.",
        700,
        grounded=True,
        barrier=False,
        build=_reply_ctx,
        primary_field=MESSAGE_FIELD,
    ),
    "nudge": ModeSpec(
        "nudge",
        "coach_nudge",
        "Write one nudge for today's plan step.",
        160,
        grounded=False,
        barrier=False,
        build=_nudge_ctx,
    ),
    "reflection": ModeSpec(
        "reflection",
        "coach_reflection",
        "Reply to this person's evening reflection.",
        450,
        grounded=False,
        barrier=True,
        build=_reflection_ctx,
        primary_field=REFLECTION_FIELD,
    ),
    "weekly_review": ModeSpec(
        "weekly_review",
        "coach_weekly_review",
        "Write this person's weekly review.",
        750,
        grounded=False,
        barrier=False,
        build=_weekly_ctx,
    ),
}


def _passage_block(passages: tuple[Passage, ...]) -> list[dict[str, object]]:
    return [{"source_id": p.source_id, "title": p.title, "text": p.text} for p in passages]


def user_message(
    spec: ModeSpec,
    model_ctx: dict[str, object],
    blocks: dict[str, object],
    passages: tuple[Passage, ...],
    feedback: tuple[str, ...],
) -> str:
    """Every value is in a tagged block as tag-safe JSON (D-96), so no user,
    passage or model text can open or close a tag."""
    body = f"{spec.task}\n<user_context>\n{tag_safe_json(model_ctx)}\n</user_context>"
    for tag, value in blocks.items():
        body += f"\n<{tag}>\n{tag_safe_json(value)}\n</{tag}>"
    if spec.grounded:
        body += f"\n<passages>\n{tag_safe_json(_passage_block(passages))}\n</passages>"
    if feedback:
        body += (
            "\nYour previous draft could not be used (reasons: "
            f"{', '.join(feedback)}). Write a new one that follows every rule."
        )
    return body


# ------------------------------------------------------------------ graph


def build_coach_graph(
    model: ModelClient,
    engine: RedFlagEngine,
    fallbacks: CoachFallbacks,
    classifier: SafetyClassifier,
) -> Any:
    def spec_of(state: CoachState) -> ModeSpec:
        return MODES[state.get("mode", "briefing")]

    def assemble_context(state: CoachState) -> CoachState:
        with span("graph.assemble_context", {"lw.node": "assemble_context"}):
            ctx, blocks = spec_of(state).build(
                state["context"], state.get("withheld_fields", ()), state.get("inputs", {})
            )
            return {"model_context": ctx, "blocks": blocks, "attempts": 0, "feedback": ()}

    def coach_draft(state: CoachState) -> CoachState:
        attempt = state.get("attempts", 0) + 1
        spec = spec_of(state)
        with span("graph.coach_draft", {"lw.node": "coach_draft", "lw.attempt": attempt}) as s:
            prompt = state["prompt"]
            started = time.monotonic()
            result = model.generate(
                ModelRequest(
                    purpose=spec.prompt_id,
                    system=prompt.text,
                    user=user_message(
                        spec,
                        state["model_context"],
                        state.get("blocks", {}),
                        state.get("passages", ()),
                        state.get("feedback", ()),
                    ),
                    json_schema=spec.json_schema,
                )
            )
            set_attrs(
                s,
                {
                    "lw.model.provider": model.provider,
                    "lw.model": result.model,
                    "lw.model.status": result.status,
                    "lw.input_tokens": result.input_tokens,
                    "lw.output_tokens": result.output_tokens,
                    "lw.duration_ms": int((time.monotonic() - started) * 1000),
                    "lw.model.error": result.error,
                    "lw.model.request_id": result.request_id,
                    "lw.prompt_version": prompt.tag,
                },
            )
            update: CoachState = {"attempts": attempt, "served_model": result.model}
            if result.status != "ok":
                failure = "truncated" if result.status == "truncated" else result.status
                return {**update, "draft": None, "failure": failure, "feedback": ("too_long",)}
            try:
                draft = CoachDraft.model_validate_json(result.text)
            except ValidationError:
                return {
                    **update,
                    "draft": None,
                    "failure": "invalid_json",
                    "feedback": ("invalid_json",),
                }
            set_attrs(s, {"lw.output_chars": len(draft.text)})
            return {**update, "draft": draft, "failure": None}

    def after_draft(state: CoachState) -> str:
        if state.get("draft") is not None:
            return "safety_post"
        retryable = state.get("failure") in ("invalid_json", "truncated")
        if retryable and state.get("attempts", 0) < MAX_MODEL_CALLS:
            return "coach_draft"
        return "fallback"

    def safety_post(state: CoachState) -> CoachState:
        draft = state.get("draft")
        assert draft is not None
        spec = spec_of(state)
        with span("graph.safety_post", {"lw.node": "safety_post"}) as s:
            provided = {p.source_id for p in state.get("passages", ())}
            result = combine_post(
                post_check(draft, engine, max_chars=spec.max_chars),
                grounding_check(draft, provided),
            )
            if spec.mode == "nudge":
                ctx = state["context"]
                personal = (ctx.first_name, ctx.why or "")
                result = combine_post(result, personal_text_check(draft, personal))
            if result.verdict == "approve":
                # A rule hit is final; only an approved draft needs the classifier.
                result = escalate_post(result, classifier.classify_output(draft.text))
            set_attrs(
                s,
                {
                    "lw.verdict": result.verdict,
                    "lw.reasons": list(result.reasons),
                    "lw.rule_ids": list(result.rule_ids),
                },
            )
            return {"post": result, "feedback": result.reasons}

    def after_post(state: CoachState) -> str:
        post = state.get("post")
        assert post is not None
        if post.verdict == "approve":
            return "finalize"
        if post.verdict == "rewrite" and state.get("attempts", 0) < MAX_MODEL_CALLS:
            return "coach_draft"
        return "fallback"

    def finalize(state: CoachState) -> CoachState:
        draft, post = state.get("draft"), state.get("post")
        assert draft is not None and post is not None and post.verdict == "approve"
        spec = spec_of(state)
        cited = set(draft.source_ids)
        used = [p for p in state.get("passages", ()) if p.source_id in cited]
        # One source per content item, in retrieval order.
        sources = {p.source_id: Source(source_id=p.source_id, title=p.title) for p in used}
        primary, secondary = MODE_ACTIONS[spec.mode]
        message = CoachMessage(
            message_id=str(uuid.uuid4()),
            type=MESSAGE_TYPES[spec.mode],
            text=draft.text.strip(),
            emotion=draft.emotion,
            primary_action=primary,
            secondary_actions=list(secondary),
            sources=list(sources.values()),
            driver_tags=sorted({t for p in used for t in p.driver_tags}),
            safety=SafetyInfo(
                status="approved",
                checks=[*state.get("pre_checks", ("safety_pre",)), *post.checks],
            ),
            contains_user_text=True,
            model=state.get("served_model") or "unknown",
            prompt_version=state["prompt"].tag,
        )
        with span("graph.finalize", {"lw.node": "finalize", "lw.message_id": message.message_id}):
            return {
                "message": message,
                "route": "coach",
                "barrier": draft.barrier if spec.barrier else None,
            }

    def use_fallback(state: CoachState) -> CoachState:
        post = state.get("post")
        reason = state.get("failure") or (post.verdict if post else "unknown")
        if post is not None and "classifier_unavailable" in post.reasons:
            reason = "classifier_unavailable"
        message = fallbacks.message(
            spec_of(state).mode,
            [*state.get("pre_checks", ("safety_pre",)), f"fallback:{reason}"],
        )
        with span(
            "graph.fallback",
            {"lw.node": "fallback", "lw.reason": reason, "lw.message_id": message.message_id},
        ):
            return {"message": message, "route": "fallback", "barrier": None}

    g = StateGraph(CoachState)
    g.add_node("assemble_context", assemble_context)
    g.add_node("coach_draft", coach_draft)
    g.add_node("safety_post", safety_post)
    g.add_node("finalize", finalize)
    g.add_node("fallback", use_fallback)
    g.add_edge(START, "assemble_context")
    g.add_edge("assemble_context", "coach_draft")
    g.add_conditional_edges("coach_draft", after_draft, ["safety_post", "coach_draft", "fallback"])
    g.add_conditional_edges("safety_post", after_post, ["finalize", "coach_draft", "fallback"])
    g.add_edge("finalize", END)
    g.add_edge("fallback", END)
    return g.compile()
