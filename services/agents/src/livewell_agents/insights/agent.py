"""The Insights Agent: read the week, compute the numbers (T-AGT-06, D-104).

No model, no free text, no safety screening needed: nothing a person typed
is read, and the output is counts and trend codes. The Coach's weekly_review
mode turns these into words, under its own safety order (rules first,
72-hour rule, Safety.post), and is told never to read numbers as a condition.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from livewell_agents.insights.stats import week_window, weekly_stats
from livewell_agents.insights.store import ActivitySource
from livewell_agents.models import WeeklyStats


@dataclass
class InsightsAgent:
    source: ActivitySource

    def weekly(self, uid: str, local_date: date) -> WeeklyStats:
        """Raises InsightsUnavailable when no source is configured."""
        start, end = week_window(local_date)
        return weekly_stats(self.source.week(uid, start, end), local_date)
