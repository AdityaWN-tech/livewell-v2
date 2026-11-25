"""Insights Agent (spec 9.3, 9.7 weekly review; FR-DLY-06; T-AGT-06, D-104).

Deterministic statistics in plain code: no model call, no free text in or
out. The short narrative is the Coach Agent's `weekly_review` mode, which
reads only these numbers.
"""

from livewell_agents.insights.agent import InsightsAgent
from livewell_agents.insights.models import (
    CheckInRecord,
    GoalRecord,
    HabitLogRecord,
    InsightsRequest,
    WeekActivity,
)
from livewell_agents.insights.stats import trend, week_window, weekly_stats
from livewell_agents.insights.store import (
    ActivitySource,
    InMemoryActivitySource,
    InsightsUnavailable,
    NotConfiguredActivitySource,
)

__all__ = [
    "ActivitySource",
    "CheckInRecord",
    "GoalRecord",
    "HabitLogRecord",
    "InMemoryActivitySource",
    "InsightsAgent",
    "InsightsRequest",
    "InsightsUnavailable",
    "NotConfiguredActivitySource",
    "WeekActivity",
    "trend",
    "week_window",
    "weekly_stats",
]
