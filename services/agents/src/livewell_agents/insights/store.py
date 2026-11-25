"""Where the Insights Agent reads a week (spec 9.3 tools get_checkins,
get_habit_logs). `ActivitySource` is the port; `FirestoreActivitySource`
(firebase_store.py) is the real one. Until it is wired the service refuses
(`NotConfiguredActivitySource`): no made-up week in staging or prod.

The `*_from` parsers turn a stored document into a record, or None when it
is malformed: one bad document is skipped, never guessed at. Strict types:
"3" or true is not a score.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any, Protocol

from pydantic import ValidationError

from livewell_agents.insights.models import (
    CheckInRecord,
    GoalRecord,
    HabitLogRecord,
    WeekActivity,
)


class InsightsUnavailable(RuntimeError):
    pass


class ActivitySource(Protocol):
    def week(self, uid: str, start: date, end: date) -> WeekActivity:
        """Check-ins and habit logs from `start` to `end` (both included),
        the primary goal and the current streak."""
        ...


class NotConfiguredActivitySource:
    def week(self, uid: str, start: date, end: date) -> WeekActivity:
        raise InsightsUnavailable("activity source is not configured")


@dataclass
class InMemoryActivitySource:
    """Tests and local dev. Returns everything; `weekly_stats` filters."""

    weeks: dict[str, WeekActivity] = field(default_factory=dict)

    def week(self, uid: str, start: date, end: date) -> WeekActivity:
        return self.weeks.get(uid, WeekActivity())


def _day(value: Any) -> date | None:
    if not isinstance(value, str):
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def checkin_from(doc_id: str, raw: dict[str, Any]) -> CheckInRecord | None:
    day = _day(doc_id)
    if day is None:
        return None
    try:
        return CheckInRecord.model_validate(
            {
                "day": day,
                "mood": raw.get("mood"),
                "energy": raw.get("energy"),
                "stress": raw.get("stress"),
            },
            strict=True,
        )
    except ValidationError:
        return None


def habit_log_from(raw: dict[str, Any]) -> HabitLogRecord | None:
    day = _day(raw.get("date"))
    if day is None:
        return None
    try:
        return HabitLogRecord.model_validate(
            {"day": day, "habit_id": raw.get("habit_id"), "status": raw.get("status")}, strict=True
        )
    except ValidationError:
        return None


def goal_from(raw: dict[str, Any] | None) -> GoalRecord | None:
    if not raw:
        return None
    try:
        return GoalRecord.model_validate(
            {"days_per_week": raw.get("days_per_week"), "status": raw.get("status")}, strict=True
        )
    except ValidationError:
        return None


def streak_from(raw: dict[str, Any] | None) -> int:
    length = (raw or {}).get("length")
    if isinstance(length, bool) or not isinstance(length, int):
        return 0
    return min(max(length, 0), 10_000)
