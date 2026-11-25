"""What the Insights Agent reads (docs/data-model.md). Numbers, dates and
fixed codes only: barrier text, notes and reflections are never read."""

from __future__ import annotations

from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class CheckInRecord(_Strict):
    """users/{uid}/checkins/{date}: the 1-5 scores only."""

    day: date
    mood: int = Field(ge=1, le=5)
    energy: int | None = Field(default=None, ge=1, le=5)
    stress: int | None = Field(default=None, ge=1, le=5)


class HabitLogRecord(_Strict):
    """users/{uid}/habit_logs/{date_habitId}. Only status "done" counts."""

    day: date
    habit_id: str = Field(min_length=1, max_length=64)
    status: str = Field(min_length=1, max_length=20)


class GoalRecord(_Strict):
    """users/{uid}/goals/primary: how many days a week the person planned."""

    days_per_week: int = Field(ge=1, le=7)
    status: Literal["active", "paused"]


class WeekActivity(_Strict):
    """Everything one weekly computation needs. A source may return records
    outside the week; `weekly_stats` keeps only the week's."""

    checkins: tuple[CheckInRecord, ...] = ()
    habit_logs: tuple[HabitLogRecord, ...] = ()
    goal: GoalRecord | None = None
    #: users/{uid}/streaks/current.length (streak engine); 0 when absent.
    streak_days: int = Field(default=0, ge=0, le=10_000)


class InsightsRequest(_Strict):
    """POST /v1/insights/weekly. The caller's local date is required: the
    week is the 7 days before it, and the server never guesses a time zone."""

    local_date: date
