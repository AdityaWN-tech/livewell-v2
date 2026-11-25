"""Morning briefing (spec 9.7 briefing generator; ADR-002 spike, T-AGT-01).

Since T-AGT-04 the briefing is the Coach Agent's `briefing` mode (coach.py):
the same Safety.pre -> classifier -> consent -> prompt -> graph -> Safety.post
pipeline as every other mode. This service adds only the day cache: one
briefing per user per local day, so repeat calls don't spend model calls (in
memory for the spike; Firestore users/{uid}/messages later, D-98 follow-up).
"""

from __future__ import annotations

import logging
import threading
from collections.abc import Callable
from datetime import UTC, date, datetime
from pathlib import Path

from livewell_agents.coach import (
    CLASSIFIER_INPUT_CHECK,
    INTERRUPTING,
    CoachAgent,
    ConsentRequired,
    PassageSource,
)
from livewell_agents.model_client import ModelClient
from livewell_agents.models import BriefingResponse, UserContext
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.events import SafetyEventSink
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import CoachFallbacks, FallbackBriefing
from livewell_agents.tracing import set_attrs, span

__all__ = [
    "CLASSIFIER_INPUT_CHECK",
    "INTERRUPTING",
    "PROMPT_ID",
    "BriefingService",
    "ConsentRequired",
]

log = logging.getLogger("livewell_agents.briefing")

PROMPT_ID = "coach_briefing"


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
        fallbacks_path: Path | None = None,
        retriever: PassageSource | None = None,
    ) -> None:
        """`fallbacks_path` (content/coach/agent/fallbacks.json) makes the
        other four modes available on `agent`; without it only the briefing."""
        self.agent = CoachAgent(
            engine=engine,
            model=model,
            prompts=prompts,
            fallbacks=CoachFallbacks(fallback, fallbacks_path),
            events=events,
            classifier=classifier,
            allow_pending_prompts=allow_pending_prompts,
            retriever=retriever,
            clock=clock,
        )
        self._cache: dict[tuple[str, date], BriefingResponse] = {}
        self._lock = threading.Lock()

    def morning(self, ctx: UserContext, has_ai_consent: bool) -> BriefingResponse:
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
            response = self.agent.run("briefing", ctx, has_ai_consent)
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
                },
            )
            return response
