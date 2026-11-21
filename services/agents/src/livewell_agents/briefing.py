"""Morning briefing, end to end (spec 9.7 briefing generator; ADR-002 spike).

Order:
  1. Safety.pre rules (plain code) over every free-text field. Emergency or
     crisis -> fixed template at once, no model call of any kind, safety
     event recorded.
  2. With AI consent (ai_disclosure) only: the safety classifier over the
     same fields. It can only escalate (escalate_pre): add a red flag the
     rules missed or a more urgent one; if it fails, a clear result becomes
     the fixed briefing (fail safe).
  3. Any red flag -> that category's fixed template, safety event recorded.
     Safety event < 72 h or classifier failure -> fixed briefing.
  4. No AI consent -> ConsentRequired, no model call.
  5. Prompt from the registry (pending prompts only in dev) -> otherwise the
     fixed briefing.
  6. The LangGraph graph: context -> Coach draft -> Safety.post (rules, then
     the output classifier) -> message.
One briefing per user per local day is cached, so repeat calls don't spend
model calls (in memory for the spike; Firestore users/{uid}/messages later).
"""

from __future__ import annotations

import logging
import threading
import time
from collections.abc import Callable
from datetime import UTC, date, datetime
from typing import Any

from livewell_agents.graph import BriefingState, build_briefing_graph
from livewell_agents.model_client import ModelClient
from livewell_agents.models import BriefingResponse, UserContext
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.events import SafetyEvent, SafetyEventSink
from livewell_agents.safety.precheck import PreCheckResult, escalate_pre, safety_pre
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import FallbackBriefing, safety_message
from livewell_agents.tracing import set_attrs, span

log = logging.getLogger("livewell_agents.briefing")

PROMPT_ID = "coach_briefing"
#: Red-flag categories answered at once from fixed templates, before any
#: model call, including the classifier (spec 9.4 step 3).
INTERRUPTING = frozenset({"emergency", "crisis"})
CLASSIFIER_INPUT_CHECK = "safety_classifier_input"


class ConsentRequired(PermissionError):
    pass


class BriefingService:
    def __init__(
        self,
        *,
        engine: RedFlagEngine,
        model: ModelClient,
        prompts: PromptRegistry,
        fallback: FallbackBriefing,
        events: SafetyEventSink,
        classifier: SafetyClassifier,
        allow_pending_prompts: bool,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._engine = engine
        self._model = model
        self._prompts = prompts
        self._fallback = fallback
        self._events = events
        self._classifier = classifier
        self._allow_pending = allow_pending_prompts
        self._clock = clock
        self._graph: Any = build_briefing_graph(model, engine, fallback, classifier)
        self._cache: dict[tuple[str, date], BriefingResponse] = {}
        self._lock = threading.Lock()

    def morning(self, ctx: UserContext, has_ai_consent: bool) -> BriefingResponse:
        started = time.monotonic()
        with span("briefing.morning", {"lw.uid": ctx.uid, "lw.flow": "morning_briefing"}) as s:
            key = (ctx.uid, ctx.local_date)
            with self._lock:
                cached = self._cache.get(key)
            if cached is not None:
                set_attrs(
                    s,
                    {
                        "lw.cached": True,
                        "lw.route": cached.route,
                        "lw.message_id": cached.message.message_id,
                    },
                )
                return cached
            response = self._generate(ctx, has_ai_consent)
            # Safety templates are not cached: the next call screens again.
            # Nor is a fallback caused by an unavailable classifier, so a
            # short outage doesn't fix the whole day to the fixed text.
            unavailable = any("classifier_unavailable" in c for c in response.message.safety.checks)
            if response.route != "safety_template" and not unavailable:
                with self._lock:
                    self._cache[key] = response
            set_attrs(
                s,
                {
                    "lw.cached": False,
                    "lw.route": response.route,
                    "lw.message_id": response.message.message_id,
                    "lw.duration_ms": int((time.monotonic() - started) * 1000),
                },
            )
            log.info(
                "briefing.morning route=%s message_id=%s duration_ms=%d",
                response.route,
                response.message.message_id,
                int((time.monotonic() - started) * 1000),
            )
            return response

    def _generate(self, ctx: UserContext, has_ai_consent: bool) -> BriefingResponse:
        with span("safety.pre", {"lw.node": "safety_pre"}) as pre_span:
            pre = safety_pre(ctx, self._engine, self._clock())
            set_attrs(pre_span, _pre_attrs(pre))
        # Emergency and crisis never wait for anything: fixed template now.
        if pre.decision == "safety_template" and pre.category in INTERRUPTING:
            return self._template(ctx, pre)
        # The classifier is an LLM, so it only sees text from people who agreed
        # to AI processing. It runs on every briefing it may run on, even one
        # that will end in a fixed text, because it may find a red flag.
        if has_ai_consent:
            verdict = self._classifier.classify_input(ctx.free_text())
            pre = escalate_pre(pre, verdict, self._engine)
            with span("safety.pre.combined", {"lw.node": "safety_pre_combined"}) as s:
                set_attrs(s, _pre_attrs(pre))
        if pre.decision == "safety_template":
            return self._template(ctx, pre)
        pre_checks = ("safety_pre", CLASSIFIER_INPUT_CHECK) if has_ai_consent else ("safety_pre",)
        if pre.decision == "fallback":
            return self._fixed([*pre_checks, f"fallback:{pre.reason}"])
        if not has_ai_consent:
            raise ConsentRequired("ai_disclosure")
        prompt = self._prompts.active(PROMPT_ID, allow_pending=self._allow_pending)
        if prompt is None:
            return self._fixed([*pre_checks, "fallback:prompt_not_approved"])
        state: BriefingState = {
            "uid": ctx.uid,
            "context": ctx,
            "withheld_fields": pre.withheld_fields,
            "pre_checks": pre_checks,
            "prompt": prompt,
        }
        final = self._graph.invoke(state)
        return BriefingResponse(route=final["route"], voice="gateway", message=final["message"])

    def _template(self, ctx: UserContext, pre: PreCheckResult) -> BriefingResponse:
        assert pre.category is not None
        self._events.record(
            SafetyEvent(
                uid=ctx.uid,
                category=pre.category,
                rule_ids=pre.rule_ids,
                fields=pre.flagged_fields,
                action="briefing_safety_template",
            )
        )
        checks = ["safety_pre"]
        if "classifier" in pre.sources:
            checks.append(CLASSIFIER_INPUT_CHECK)
        message = safety_message(pre.category, self._engine.contacts_for(ctx.region), checks=checks)
        return BriefingResponse(route="safety_template", voice="neutral_device", message=message)

    def _fixed(self, checks: list[str]) -> BriefingResponse:
        return BriefingResponse(
            route="fallback", voice="gateway", message=self._fallback.message(checks)
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
