"""Morning briefing, end to end (spec 9.7 briefing generator; ADR-002 spike).

Order, all plain code until the graph:
  1. Safety.pre over every free-text field (red flag -> fixed template, no
     model call, safety event recorded; recent safety event -> fixed briefing).
  2. AI consent (ai_disclosure) -> otherwise ConsentRequired, no model call.
  3. Prompt from the registry (pending prompts only in dev) -> otherwise the
     fixed briefing.
  4. The LangGraph graph: context -> Coach draft -> Safety.post -> message.
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
from livewell_agents.safety.events import SafetyEvent, SafetyEventSink
from livewell_agents.safety.precheck import safety_pre
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import FallbackBriefing, safety_message
from livewell_agents.tracing import set_attrs, span

log = logging.getLogger("livewell_agents.briefing")

PROMPT_ID = "coach_briefing"


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
        allow_pending_prompts: bool,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._engine = engine
        self._model = model
        self._prompts = prompts
        self._fallback = fallback
        self._events = events
        self._allow_pending = allow_pending_prompts
        self._clock = clock
        self._graph: Any = build_briefing_graph(model, engine, fallback)
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
            if response.route != "safety_template":
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
            set_attrs(
                pre_span,
                {
                    "lw.decision": pre.decision,
                    "lw.reason": pre.reason,
                    "lw.safety.category": pre.category,
                    "lw.rule_ids": list(pre.rule_ids),
                    "lw.fields": list(pre.flagged_fields),
                    "lw.withheld_fields": list(pre.withheld_fields),
                },
            )
        if pre.decision == "safety_template":
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
            message = safety_message(pre.category, self._engine.contacts_for(ctx.region))
            return BriefingResponse(
                route="safety_template", voice="neutral_device", message=message
            )
        if pre.decision == "fallback":
            return self._fixed(["safety_pre", f"fallback:{pre.reason}"])
        if not has_ai_consent:
            raise ConsentRequired("ai_disclosure")
        prompt = self._prompts.active(PROMPT_ID, allow_pending=self._allow_pending)
        if prompt is None:
            return self._fixed(["safety_pre", "fallback:prompt_not_approved"])
        state: BriefingState = {
            "uid": ctx.uid,
            "context": ctx,
            "withheld_fields": pre.withheld_fields,
            "prompt": prompt,
        }
        final = self._graph.invoke(state)
        return BriefingResponse(route=final["route"], voice="gateway", message=final["message"])

    def _fixed(self, checks: list[str]) -> BriefingResponse:
        return BriefingResponse(
            route="fallback", voice="gateway", message=self._fallback.message(checks)
        )
