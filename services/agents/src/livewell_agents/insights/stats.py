"""The weekly statistics, deterministic (spec 9.3: "mostly deterministic
statistics"). Fixtures with expected results: evals/cases/insights_weekly.json.

Definitions (D-104):
- The week is the 7 days before the local date: [local_date - 7, local_date - 1].
  The Sunday 08:00 review (spec 9.7) covers the full Sunday-to-Saturday week.
- days_checked_in: days in the week with a check-in.
- habit_days_done: days in the week with at least one habit log "done"
  (the daily step or an own habit; skipped logs never count).
- habit_days_planned: the active primary goal's days_per_week; 7 without an
  active goal (the daily step is offered every day).
- streak_days: the streak engine's current length, unchanged.
- restarts: 0. Only a running total is stored (streaks/current.restart_count),
  so a per-week count would be a guess; the review never claims a restart.
- Trends (mood, energy, stress): the week's readings in date order, split in
  halves (the middle one of an odd count is left out); the later half's mean
  minus the earlier half's. At least 4 readings, else "unknown". A difference
  of at least 0.5 is "up" or "down", anything smaller "steady". Exact
  fractions, so a boundary never depends on float rounding.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, timedelta
from fractions import Fraction

from livewell_agents.insights.models import WeekActivity
from livewell_agents.models import Trend, WeeklyStats

WEEK_DAYS = 7
TREND_MIN_READINGS = 4
TREND_BAND = Fraction(1, 2)


def week_window(local_date: date) -> tuple[date, date]:
    """First and last day (both included) of the week before `local_date`."""
    return local_date - timedelta(days=WEEK_DAYS), local_date - timedelta(days=1)


def trend(values: Sequence[int]) -> Trend:
    """Readings in date order -> up / steady / down, or unknown when too few."""
    n = len(values)
    if n < TREND_MIN_READINGS:
        return "unknown"
    half = n // 2
    earlier = Fraction(sum(values[:half]), half)
    later = Fraction(sum(values[n - half :]), half)
    diff = later - earlier
    if diff >= TREND_BAND:
        return "up"
    if diff <= -TREND_BAND:
        return "down"
    return "steady"


def weekly_stats(activity: WeekActivity, local_date: date) -> WeeklyStats:
    start, end = week_window(local_date)

    def in_week(d: date) -> bool:
        return start <= d <= end

    # One check-in per day (the document id is the date); the last one wins.
    by_day = {c.day: c for c in activity.checkins if in_week(c.day)}
    days = sorted(by_day)
    moods = [by_day[d].mood for d in days]
    energies = [e for d in days if (e := by_day[d].energy) is not None]
    stresses = [s for d in days if (s := by_day[d].stress) is not None]

    done_days = {h.day for h in activity.habit_logs if h.status == "done" and in_week(h.day)}
    goal = activity.goal
    planned = goal.days_per_week if goal is not None and goal.status == "active" else WEEK_DAYS

    return WeeklyStats(
        week_start=start,
        days_checked_in=len(days),
        habit_days_done=len(done_days),
        habit_days_planned=planned,
        streak_days=activity.streak_days,
        restarts=0,
        mood_trend=trend(moods),
        energy_trend=trend(energies),
        stress_trend=trend(stresses),
    )
