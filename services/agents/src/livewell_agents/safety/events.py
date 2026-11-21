"""Safety events (FR-SAF-06, D-22): category, rule ids and the action taken.
Never the text that triggered them."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Protocol

from livewell_agents.models import SafetyCategory

log = logging.getLogger("livewell_agents.safety")


@dataclass(frozen=True)
class SafetyEvent:
    uid: str
    category: SafetyCategory
    rule_ids: tuple[str, ...]
    #: Field names only (e.g. "why", "last_checkin.note"), never their text.
    fields: tuple[str, ...]
    action: str
    source: str = "agents.briefing"


class SafetyEventSink(Protocol):
    def record(self, event: SafetyEvent) -> None: ...


class LoggingSafetyEventSink:
    """Until the server-side safety_events writer exists (D-22: planned
    `reportSafetyEvent`), events go to the structured log, ids only."""

    def record(self, event: SafetyEvent) -> None:
        log.warning(
            "safety_event uid=%s category=%s rules=%s fields=%s action=%s source=%s",
            event.uid,
            event.category,
            ",".join(event.rule_ids),
            ",".join(event.fields),
            event.action,
            event.source,
        )


@dataclass
class ListSafetyEventSink:
    """For tests."""

    events: list[SafetyEvent] = field(default_factory=list)

    def record(self, event: SafetyEvent) -> None:
        self.events.append(event)
