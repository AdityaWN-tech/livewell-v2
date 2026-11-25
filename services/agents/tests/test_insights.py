"""Insights Agent units and endpoints (T-AGT-06, D-104)."""

from datetime import date

import pytest
from fastapi.testclient import TestClient

from conftest import dev_settings
from livewell_agents.app import Deps, create_app
from livewell_agents.auth import FakeAuthenticator, FakeConsents
from livewell_agents.context import FixtureContextSource
from livewell_agents.insights import (
    CheckInRecord,
    GoalRecord,
    HabitLogRecord,
    InMemoryActivitySource,
    InsightsAgent,
    InsightsUnavailable,
    NotConfiguredActivitySource,
    WeekActivity,
    trend,
    week_window,
)
from livewell_agents.insights.store import checkin_from, goal_from, habit_log_from, streak_from
from livewell_agents.model_client import FakeModelClient
from livewell_agents.safety.events import ListSafetyEventSink

H = {"Authorization": "Bearer token-demo-us", "X-Firebase-AppCheck": "app-check-ok"}

# ---------------------------------------------------------------- statistics


def test_week_window_is_the_seven_days_before():
    assert week_window(date(2026, 11, 22)) == (date(2026, 11, 15), date(2026, 11, 21))
    assert week_window(date(2027, 1, 3)) == (date(2026, 12, 27), date(2027, 1, 2))


@pytest.mark.parametrize(
    ("values", "expected"),
    [
        ([], "unknown"),
        ([1, 5, 1], "unknown"),
        ([3, 3, 3, 3], "steady"),
        ([1, 1, 2, 2], "up"),
        ([2, 2, 1, 1], "down"),
        ([3, 3, 3, 4], "up"),  # +0.5 exactly
        ([4, 4, 4, 3], "down"),  # -0.5 exactly
        ([3, 3, 3, 3, 3, 4], "steady"),  # +1/3
        ([1, 1, 5, 2, 2], "up"),  # the middle reading is left out
        ([1, 2, 3, 4, 5, 1, 2], "up"),  # 1,2,3 = 2 vs 5,1,2 = 8/3: +2/3
    ],
)
def test_trend(values, expected):
    assert trend(values) == expected


# ---------------------------------------------------------------- stored documents


def test_checkin_parser_keeps_scores_only_and_skips_bad_documents():
    raw = {"mood": 4, "energy": 3, "stress": 2, "barrier_text": "private words", "source": "app"}
    assert checkin_from("2026-11-20", raw) == CheckInRecord(
        day=date(2026, 11, 20), mood=4, energy=3, stress=2
    )
    assert checkin_from("2026-11-20", {"mood": 4}) == CheckInRecord(day=date(2026, 11, 20), mood=4)
    assert checkin_from("not-a-date", {"mood": 3}) is None
    assert checkin_from("2026-11-20", {}) is None
    assert checkin_from("2026-11-20", {"mood": 9}) is None
    assert checkin_from("2026-11-20", {"mood": "3"}) is None
    assert checkin_from("2026-11-20", {"mood": True}) is None
    assert checkin_from("2026-11-20", {"mood": 3, "energy": 2.5}) is None


def test_habit_log_goal_and_streak_parsers():
    assert habit_log_from(
        {"date": "2026-11-20", "habit_id": "daily_step", "status": "done", "done_at": None}
    ) == HabitLogRecord(day=date(2026, 11, 20), habit_id="daily_step", status="done")
    assert habit_log_from({"date": "2026-13-01", "habit_id": "x", "status": "done"}) is None
    assert habit_log_from({"date": "2026-11-20", "status": "done"}) is None
    assert goal_from({"days_per_week": 4, "status": "active", "action": "walk"}) == GoalRecord(
        days_per_week=4, status="active"
    )
    assert goal_from(None) is None
    assert goal_from({"days_per_week": 0, "status": "active"}) is None
    assert goal_from({"days_per_week": 3, "status": "done"}) is None
    assert streak_from({"length": 9, "best": 20}) == 9
    assert streak_from(None) == 0
    assert streak_from({"length": True}) == 0
    assert streak_from({"length": "9"}) == 0
    assert streak_from({"length": -2}) == 0


def test_not_configured_source_refuses():
    with pytest.raises(InsightsUnavailable):
        InsightsAgent(NotConfiguredActivitySource()).weekly("u1", date(2026, 11, 22))


def test_agent_asks_the_source_for_the_week_only():
    seen = []

    class Recording:
        def week(self, uid, start, end):
            seen.append((uid, start, end))
            return WeekActivity()

    InsightsAgent(Recording()).weekly("u1", date(2026, 11, 22))
    assert seen == [("u1", date(2026, 11, 15), date(2026, 11, 21))]


# ---------------------------------------------------------------- endpoints

WEEK = WeekActivity(
    checkins=tuple(
        CheckInRecord(day=date(2026, 11, d), mood=m, energy=3)
        for d, m in zip(range(15, 19), (2, 2, 4, 4), strict=True)
    ),
    habit_logs=(HabitLogRecord(day=date(2026, 11, 16), habit_id="daily_step", status="done"),),
    goal=GoalRecord(days_per_week=5, status="active"),
    streak_days=1,
)


class CountingSource(InMemoryActivitySource):
    def __init__(self, weeks):
        super().__init__(weeks)
        self.reads = 0

    def week(self, uid, start, end):
        self.reads += 1
        return super().week(uid, start, end)


def _client(activity=None, consented=("demo-us",)):
    s = dev_settings()
    model = FakeModelClient()
    deps = Deps(
        settings=s,
        auth=FakeAuthenticator(),
        consents=FakeConsents({u: {"ai_disclosure"} for u in consented}),
        contexts=FixtureContextSource(s.fixtures_path),
        model=model,
        classifier_model=FakeModelClient(),
        events=ListSafetyEventSink(),
        activity=activity if activity is not None else NotConfiguredActivitySource(),
    )
    return TestClient(create_app(deps)), model


def test_insights_endpoint_returns_the_numbers():
    client, model = _client(InMemoryActivitySource({"demo-us": WEEK}))
    r = client.post("/v1/insights/weekly", json={"local_date": "2026-11-22"}, headers=H)
    assert r.status_code == 200, r.text
    assert r.json() == {
        "week_start": "2026-11-15",
        "days_checked_in": 4,
        "habit_days_done": 1,
        "habit_days_planned": 5,
        "streak_days": 1,
        "restarts": 0,
        "mood_trend": "up",
        "energy_trend": "steady",
        "stress_trend": "unknown",
    }
    assert model.calls == 0  # deterministic: no model


def test_insights_endpoint_auth_body_and_unconfigured():
    client, _ = _client(InMemoryActivitySource())
    assert client.post("/v1/insights/weekly", json={"local_date": "2026-11-22"}).status_code == 401
    assert client.post("/v1/insights/weekly", json={}, headers=H).status_code == 422
    body = {"local_date": "2026-11-22", "extra": 1}
    assert client.post("/v1/insights/weekly", json=body, headers=H).status_code == 422
    client, _ = _client()
    r = client.post("/v1/insights/weekly", json={"local_date": "2026-11-22"}, headers=H)
    assert r.status_code == 503 and r.json()["detail"] == "insights_unavailable"


def test_weekly_review_without_stats_uses_the_insights_agent():
    source = CountingSource({"demo-us": WEEK})
    client, model = _client(source)
    r = client.post("/v1/reviews/weekly", json={"local_date": "2026-11-22"}, headers=H)
    assert r.status_code == 200, r.text
    assert r.json()["message"]["type"] == "weekly_review"
    assert source.reads == 1 and model.calls == 1
    prompt = model.requests[0].user
    assert '"week_start":"2026-11-15"' in prompt.replace(" ", "")
    assert '"mood_trend":"up"' in prompt.replace(" ", "")


def test_weekly_review_without_stats_reads_nothing_without_consent_or_context():
    source = CountingSource({"demo-us": WEEK})
    client, model = _client(source, consented=())
    body = {"local_date": "2026-11-22"}
    assert client.post("/v1/reviews/weekly", json=body, headers=H).status_code == 403
    h = {**H, "Authorization": "Bearer token-nobody"}
    assert client.post("/v1/reviews/weekly", json=body, headers=h).status_code == 404
    assert source.reads == 0 and model.calls == 0


def test_weekly_review_needs_stats_or_a_local_date():
    client, model = _client(InMemoryActivitySource())
    assert client.post("/v1/reviews/weekly", json={}, headers=H).status_code == 422
    client, model = _client()
    r = client.post("/v1/reviews/weekly", json={"local_date": "2026-11-22"}, headers=H)
    assert r.status_code == 503
    assert model.calls == 0
