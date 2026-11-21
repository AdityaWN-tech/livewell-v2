"""The morning-briefing graph (LangGraph core only; ADR-002, D-90).

    START -> assemble_context -> coach_draft -> (valid draft) -> safety_post
                                     ^   |                         |
                                     |   +-(invalid JSON, retry)   +-> approve -> finalize -> END
                                     +-------(rewrite, once)-------+
                                         (anything else) -----------> fallback -> END

Safety.pre has already run in plain code before this graph is invoked
(briefing.py). `finalize` is reachable only from `safety_post`, so no model
text leaves the graph without the post-check. The model is called at most
MAX_MODEL_CALLS times per briefing (one retry, for invalid JSON or a rewrite).
"""

from __future__ import annotations

import json
import time
import uuid
from typing import Any, TypedDict

from langgraph.graph import END, START, StateGraph
from pydantic import ValidationError

from livewell_agents.model_client import ModelClient, ModelRequest
from livewell_agents.models import (
    COACH_DRAFT_JSON_SCHEMA,
    CoachDraft,
    CoachMessage,
    Route,
    SafetyInfo,
    UserContext,
)
from livewell_agents.prompts import Prompt
from livewell_agents.safety.postcheck import PostCheckResult, post_check
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import (
    BRIEFING_PRIMARY,
    BRIEFING_SECONDARY,
    FallbackBriefing,
)
from livewell_agents.tracing import set_attrs, span

MAX_MODEL_CALLS = 2


class BriefingState(TypedDict, total=False):
    uid: str
    context: UserContext
    withheld_fields: tuple[str, ...]
    prompt: Prompt
    model_context: dict[str, object]
    attempts: int
    feedback: tuple[str, ...]
    draft: CoachDraft | None
    failure: str | None
    served_model: str | None
    post: PostCheckResult | None
    message: CoachMessage
    route: Route


def model_context(ctx: UserContext, withheld: tuple[str, ...]) -> dict[str, object]:
    """What the model sees: the screened context, minus withheld fields and
    minus check-in notes (free text the briefing doesn't need)."""
    out: dict[str, object] = {
        "coach_name": ctx.coach_name,
        "local_date": ctx.local_date.isoformat(),
        "weekday": ctx.local_date.strftime("%A"),
        "streak_days": ctx.streak_days,
        "ed_safe_mode": ctx.ed_safe_mode,
    }
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


def user_message(model_ctx: dict[str, object], feedback: tuple[str, ...]) -> str:
    body = (
        "Write today's morning briefing for this person.\n"
        "<user_context>\n"
        f"{json.dumps(model_ctx, ensure_ascii=False, sort_keys=True)}\n"
        "</user_context>"
    )
    if feedback:
        body += (
            "\nYour previous draft could not be used (reasons: "
            f"{', '.join(feedback)}). Write a new briefing that follows every rule."
        )
    return body


def build_briefing_graph(
    model: ModelClient, engine: RedFlagEngine, fallback: FallbackBriefing
) -> Any:
    def assemble_context(state: BriefingState) -> BriefingState:
        with span("graph.assemble_context", {"lw.node": "assemble_context"}):
            return {
                "model_context": model_context(state["context"], state.get("withheld_fields", ())),
                "attempts": 0,
                "feedback": (),
            }

    def coach_draft(state: BriefingState) -> BriefingState:
        attempt = state.get("attempts", 0) + 1
        with span("graph.coach_draft", {"lw.node": "coach_draft", "lw.attempt": attempt}) as s:
            prompt = state["prompt"]
            started = time.monotonic()
            result = model.generate(
                ModelRequest(
                    purpose="coach_briefing",
                    system=prompt.text,
                    user=user_message(state["model_context"], state.get("feedback", ())),
                    json_schema=COACH_DRAFT_JSON_SCHEMA,
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
            update: BriefingState = {"attempts": attempt, "served_model": result.model}
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

    def after_draft(state: BriefingState) -> str:
        if state.get("draft") is not None:
            return "safety_post"
        retryable = state.get("failure") in ("invalid_json", "truncated")
        if retryable and state.get("attempts", 0) < MAX_MODEL_CALLS:
            return "coach_draft"
        return "fallback"

    def safety_post(state: BriefingState) -> BriefingState:
        draft = state.get("draft")
        assert draft is not None
        with span("graph.safety_post", {"lw.node": "safety_post"}) as s:
            result = post_check(draft, engine)
            set_attrs(
                s,
                {
                    "lw.verdict": result.verdict,
                    "lw.reasons": list(result.reasons),
                    "lw.rule_ids": list(result.rule_ids),
                },
            )
            return {"post": result, "feedback": result.reasons}

    def after_post(state: BriefingState) -> str:
        post = state.get("post")
        assert post is not None
        if post.verdict == "approve":
            return "finalize"
        if post.verdict == "rewrite" and state.get("attempts", 0) < MAX_MODEL_CALLS:
            return "coach_draft"
        return "fallback"

    def finalize(state: BriefingState) -> BriefingState:
        draft, post = state.get("draft"), state.get("post")
        assert draft is not None and post is not None and post.verdict == "approve"
        message = CoachMessage(
            message_id=str(uuid.uuid4()),
            type="briefing",
            text=draft.text.strip(),
            emotion=draft.emotion,
            primary_action=BRIEFING_PRIMARY,
            secondary_actions=list(BRIEFING_SECONDARY),
            safety=SafetyInfo(status="approved", checks=["safety_pre", *post.checks]),
            contains_user_text=True,
            model=state.get("served_model") or "unknown",
            prompt_version=state["prompt"].tag,
        )
        with span("graph.finalize", {"lw.node": "finalize", "lw.message_id": message.message_id}):
            return {"message": message, "route": "coach"}

    def use_fallback(state: BriefingState) -> BriefingState:
        post = state.get("post")
        reason = state.get("failure") or (post.verdict if post else "unknown")
        message = fallback.message(["safety_pre", f"fallback:{reason}"])
        with span(
            "graph.fallback",
            {"lw.node": "fallback", "lw.reason": reason, "lw.message_id": message.message_id},
        ):
            return {"message": message, "route": "fallback"}

    g = StateGraph(BriefingState)
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
