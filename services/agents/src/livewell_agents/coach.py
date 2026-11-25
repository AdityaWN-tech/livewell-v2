"""The Coach Agent: one pipeline, five modes (spec 9.3, 9.4; T-AGT-04, D-98).

    briefing       morning briefing (spec 9.7; BriefingService adds the day cache)
    reply          one conversation turn (spec 9.4; POST /v1/conversation/turn)
    nudge          the words of one anchored nudge (FR-DLY-04, FR-TCH-02)
    reflection     the reply to an evening reflection (FR-DLY-05)
    weekly_review  the Sunday review from precomputed stats (FR-DLY-06)

Order, the same for every mode (deterministic rules first, AI second, 9.1):
  1. Safety.pre rules (plain code) over every free-text field: the stored
     context AND the request's own text (chat message, reflection). Emergency
     or crisis -> fixed template at once, no model call of any kind, safety
     event recorded, neutral voice, the user's region numbers (both when the
     region is unknown; never guessed, D-03).
  2. With AI consent (ai_disclosure) only: the safety classifier over the same
     fields. It can only escalate; if it fails, a clear result becomes the
     mode's fixed text (fail safe).
  3. Any red flag -> that category's fixed template. A safety event in the
     last 72 h or a classifier failure -> the mode's fixed text, no model
     (D-91c extended to every mode; also no portal content, FR-SAF-07).
  4. No AI consent -> ConsentRequired, no model call.
  5. The request's own text looked like instructions (withheld) -> the
     mode's fixed text: there is nothing left to answer (15.3 voice misuse).
  6. Prompt from the registry (pending prompts only in dev) -> else fixed text.
  7. Grounded modes (reply): approved passages from the retriever (approved
     only, three layers, D-94); none -> the model is told to state no health
     facts, and Safety.post rejects any health claim without a cited source.
  8. The graph: context -> Coach draft -> Safety.post (rules, grounding, then
     the output classifier) -> CoachMessage, one retry, else the fixed text.
Logs and spans carry ids, codes, counts and durations only (AGENTS.md).
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Protocol

from livewell_agents.content.models import Passage
from livewell_agents.graph import (
    MESSAGE_FIELD,
    MODES,
    REFLECTION_FIELD,
    CoachState,
    build_coach_graph,
)
from livewell_agents.model_client import ModelClient
from livewell_agents.models import CoachMode, CoachResponse, TimeOfDay, UserContext, WeeklyStats
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.events import SafetyEvent, SafetyEventSink
from livewell_agents.safety.precheck import PreCheckResult, escalate_pre, safety_pre
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import MESSAGE_TYPES, CoachFallbacks, safety_message
from livewell_agents.tracing import set_attrs, span

log = logging.getLogger("livewell_agents.coach")

#: Red-flag categories answered at once from fixed templates, before any
#: model call, including the classifier (spec 9.4 step 3).
INTERRUPTING = frozenset({"emergency", "crisis"})
CLASSIFIER_INPUT_CHECK = "safety_classifier_input"
#: Passages asked for per conversation turn.
PASSAGES_K = 3

#: The app's focus choices (users/{uid}.focus_driver) -> content driver tags.
FOCUS_TO_DRIVER = {
    "move_more": "movement",
    "sleep_better": "sleep",
    "eat_better": "nutrition",
    "less_stress": "stress",
    "more_energy": "energy",
    "healthy_routine": "routine",
}


class ConsentRequired(PermissionError):
    pass


class PassageSource(Protocol):
    """ContentRetriever.retrieve (T-AGT-03): approved passages only."""

    def retrieve(
        self,
        query: str,
        driver_tags: Sequence[str] = (),
        k: int = 5,
        region: str | None = None,
        locale: str = "en",
    ) -> list[Passage]: ...


@dataclass(frozen=True)
class ModeInputs:
    """What a request brings besides the stored context."""

    #: reply: the person's chat message (free text, screened).
    message: str | None = None
    #: reflection: the evening answer (free text, screened).
    reflection: str | None = None
    #: nudge: when it will be shown.
    time_of_day: TimeOfDay | None = None
    #: weekly_review: precomputed numbers (no free text).
    stats: WeeklyStats | None = None

    def free_text(self) -> dict[str, str]:
        out: dict[str, str] = {}
        if self.message is not None:
            out[MESSAGE_FIELD] = self.message
        if self.reflection is not None:
            out[REFLECTION_FIELD] = self.reflection
        return out

    def for_mode(self, mode: CoachMode) -> dict[str, object]:
        """The graph's `inputs`; raises if the mode's input is missing."""
        if mode == "reply":
            if not self.message:
                raise ValueError("reply needs a message")
            return {MESSAGE_FIELD: self.message}
        if mode == "reflection":
            if not self.reflection:
                raise ValueError("reflection needs the reflection text")
            return {REFLECTION_FIELD: self.reflection}
        if mode == "nudge":
            if self.time_of_day is None:
                raise ValueError("nudge needs time_of_day")
            return {"time_of_day": self.time_of_day}
        if mode == "weekly_review":
            if self.stats is None:
                raise ValueError("weekly_review needs stats")
            return {"stats": self.stats.model_dump(mode="json")}
        return {}


class CoachAgent:
    def __init__(
        self,
        *,
        engine: RedFlagEngine,
        model: ModelClient,
        prompts: PromptRegistry,
        fallbacks: CoachFallbacks,
        events: SafetyEventSink,
        classifier: SafetyClassifier,
        allow_pending_prompts: bool,
        retriever: PassageSource | None = None,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._engine = engine
        self._prompts = prompts
        self._fallbacks = fallbacks
        self._events = events
        self._classifier = classifier
        self._allow_pending = allow_pending_prompts
        self._retriever = retriever
        self._clock = clock
        self._graph: Any = build_coach_graph(model, engine, fallbacks, classifier)

    def run(
        self,
        mode: CoachMode,
        ctx: UserContext,
        has_ai_consent: bool,
        inputs: ModeInputs | None = None,
    ) -> CoachResponse:
        inputs = inputs or ModeInputs()
        mode_inputs = inputs.for_mode(mode)  # a missing input is a caller bug: raise first
        started = time.monotonic()
        with span(f"coach.{mode}", {"lw.uid": ctx.uid, "lw.flow": mode}) as s:
            response = self._generate(mode, ctx, has_ai_consent, inputs, mode_inputs)
            duration = int((time.monotonic() - started) * 1000)
            set_attrs(
                s,
                {
                    "lw.route": response.route,
                    "lw.message_id": response.message.message_id,
                    "lw.duration_ms": duration,
                },
            )
        log.info(
            "coach.run mode=%s route=%s message_id=%s duration_ms=%d",
            mode,
            response.route,
            response.message.message_id,
            duration,
        )
        return response

    def _generate(
        self,
        mode: CoachMode,
        ctx: UserContext,
        has_ai_consent: bool,
        inputs: ModeInputs,
        mode_inputs: dict[str, object],
    ) -> CoachResponse:
        spec = MODES[mode]
        extra = inputs.free_text()
        with span("safety.pre", {"lw.node": "safety_pre"}) as pre_span:
            pre = safety_pre(ctx, self._engine, self._clock(), extra)
            set_attrs(pre_span, _pre_attrs(pre))
        # Emergency and crisis never wait for anything: fixed template now.
        if pre.decision == "safety_template" and pre.category in INTERRUPTING:
            return self._template(mode, ctx, pre)
        # The classifier is an LLM, so it only sees text from people who agreed
        # to AI processing. It runs whenever it may, even on a run that will end
        # in a fixed text, because it may find a red flag.
        if has_ai_consent:
            verdict = self._classifier.classify_input({**ctx.free_text(), **extra})
            pre = escalate_pre(pre, verdict, self._engine)
            with span("safety.pre.combined", {"lw.node": "safety_pre_combined"}) as s:
                set_attrs(s, _pre_attrs(pre))
        if pre.decision == "safety_template":
            return self._template(mode, ctx, pre)
        pre_checks = ("safety_pre", CLASSIFIER_INPUT_CHECK) if has_ai_consent else ("safety_pre",)
        if pre.decision == "fallback":
            return self._fixed(mode, [*pre_checks, f"fallback:{pre.reason}"])
        if not has_ai_consent:
            raise ConsentRequired("ai_disclosure")
        if spec.primary_field is not None and spec.primary_field in pre.withheld_fields:
            return self._fixed(mode, [*pre_checks, "fallback:input_withheld"])
        prompt = self._prompts.active(spec.prompt_id, allow_pending=self._allow_pending)
        if prompt is None:
            return self._fixed(mode, [*pre_checks, "fallback:prompt_not_approved"])
        passages = self._passages(ctx, inputs) if spec.grounded else ()
        state: CoachState = {
            "uid": ctx.uid,
            "mode": mode,
            "context": ctx,
            "withheld_fields": pre.withheld_fields,
            "pre_checks": pre_checks,
            "prompt": prompt,
            "inputs": mode_inputs,
            "passages": passages,
        }
        final = self._graph.invoke(state)
        return CoachResponse(
            route=final["route"],
            voice="gateway",
            message=final["message"],
            barrier=final.get("barrier"),
        )

    def _passages(self, ctx: UserContext, inputs: ModeInputs) -> tuple[Passage, ...]:
        """Approved passages for the person's message. Any failure means no
        passages (fail closed: the Coach then states no health facts)."""
        if self._retriever is None or not inputs.message:
            return ()
        driver = FOCUS_TO_DRIVER.get(ctx.focus_driver or "")
        with span("content.retrieve", {"lw.node": "retrieve"}) as s:
            try:
                found = self._retriever.retrieve(
                    inputs.message,
                    driver_tags=(driver,) if driver else (),
                    k=PASSAGES_K,
                    region=ctx.region,
                )
            except Exception as e:
                log.warning("coach.retrieve_failed class=%s", type(e).__name__)
                found = []
            set_attrs(
                s,
                {
                    "lw.passages": len(found),
                    "lw.source_ids": sorted({p.source_id for p in found}),
                },
            )
        return tuple(found)

    def _template(self, mode: CoachMode, ctx: UserContext, pre: PreCheckResult) -> CoachResponse:
        assert pre.category is not None
        self._events.record(
            SafetyEvent(
                uid=ctx.uid,
                category=pre.category,
                rule_ids=pre.rule_ids,
                fields=pre.flagged_fields,
                action=f"{mode}_safety_template",
                source="agents.briefing" if mode == "briefing" else f"agents.coach.{mode}",
            )
        )
        checks = ["safety_pre"]
        if "classifier" in pre.sources:
            checks.append(CLASSIFIER_INPUT_CHECK)
        message = safety_message(
            pre.category,
            self._engine.contacts_for(ctx.region),
            checks=checks,
            message_type=MESSAGE_TYPES[mode],
        )
        return CoachResponse(route="safety_template", voice="neutral_device", message=message)

    def _fixed(self, mode: CoachMode, checks: list[str]) -> CoachResponse:
        return CoachResponse(
            route="fallback", voice="gateway", message=self._fallbacks.message(mode, checks)
        )


def _pre_attrs(pre: PreCheckResult) -> dict[str, str | list[str] | None]:
    return {
        "lw.decision": pre.decision,
        "lw.reason": pre.reason,
        "lw.safety.category": pre.category,
        "lw.rule_ids": list(pre.rule_ids),
        "lw.fields": list(pre.flagged_fields),
        "lw.withheld_fields": list(pre.withheld_fields),
    }
