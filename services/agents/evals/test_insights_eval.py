"""Insights Agent eval (T-AGT-06 Done when: "matches the deterministic
statistics on fixtures"; D-104). Cases: evals/cases/insights_weekly.json,
expected values worked out by hand."""

import json
from datetime import date
from pathlib import Path

import pytest

from livewell_agents.insights import InMemoryActivitySource, InsightsAgent, WeekActivity
from livewell_agents.insights.stats import weekly_stats
from livewell_agents.models import WeeklyStats

CASES = json.loads((Path(__file__).parent / "cases" / "insights_weekly.json").read_text("utf-8"))


def _param(c):
    return pytest.param(c, id=c["id"], marks=[pytest.mark.critical])


@pytest.mark.parametrize("case", [_param(c) for c in CASES["cases"]])
def test_weekly_stats_match_fixture(case):
    activity = WeekActivity.model_validate(case["activity"])
    local = date.fromisoformat(case["local_date"])
    expected = WeeklyStats.model_validate(case["expected"])
    assert weekly_stats(activity, local) == expected
    # The agent over a source gives the same numbers.
    agent = InsightsAgent(InMemoryActivitySource({"u1": activity}))
    assert agent.weekly("u1", local) == expected


def test_enough_fixtures():
    ids = [c["id"] for c in CASES["cases"]]
    assert len(ids) >= 7 and len(set(ids)) == len(ids)
