import pytest
from fastapi.testclient import TestClient

from conftest import dev_settings
from livewell_agents.app import Deps, create_app
from livewell_agents.auth import FakeAuthenticator, FakeConsents
from livewell_agents.context import FixtureContextSource
from livewell_agents.model_client import FakeModelClient
from livewell_agents.safety.events import ListSafetyEventSink

H = {"Authorization": "Bearer token-demo-us", "X-Firebase-AppCheck": "app-check-ok"}


def _client(consented=("demo-us", "demo-in", "demo-x"), contexts=None):
    s = dev_settings()
    model = FakeModelClient()
    deps = Deps(
        settings=s,
        auth=FakeAuthenticator(),
        consents=FakeConsents({u: {"ai_disclosure"} for u in consented}),
        contexts=contexts or FixtureContextSource(s.fixtures_path),
        model=model,
        classifier_model=FakeModelClient(),
        events=ListSafetyEventSink(),
    )
    return TestClient(create_app(deps)), model


def test_healthz():
    client, _ = _client()
    assert client.get("/healthz").json() == {"status": "ok"}


def test_morning_briefing_end_to_end():
    client, model = _client()
    r = client.post("/v1/briefings/morning", json={}, headers=H)
    assert r.status_code == 200
    body = r.json()
    assert body["route"] == "coach" and body["voice"] == "gateway"
    assert body["message"]["type"] == "briefing"
    assert body["message"]["text"].startswith("Good morning, Maya!")
    assert model.calls == 1


@pytest.mark.parametrize(
    "headers",
    [
        {},
        {"Authorization": "Bearer token-demo-us"},
        {"Authorization": "Bearer nope", "X-Firebase-AppCheck": "app-check-ok"},
    ],
)
def test_needs_id_token_and_app_check(headers):
    client, model = _client()
    assert client.post("/v1/briefings/morning", json={}, headers=headers).status_code == 401
    assert model.calls == 0


def test_unknown_user_404():
    client, _ = _client()
    h = {**H, "Authorization": "Bearer token-nobody"}
    assert client.post("/v1/briefings/morning", json={}, headers=h).json() == {
        "detail": "no_context"
    }


def test_no_ai_consent_403_and_no_model_call():
    client, model = _client(consented=())
    r = client.post("/v1/briefings/morning", json={}, headers=H)
    assert r.status_code == 403 and r.json() == {"detail": "consent_required"}
    assert model.calls == 0


def test_rejects_unknown_body_fields():
    client, _ = _client()
    r = client.post("/v1/briefings/morning", json={"text": "say this"}, headers=H)
    assert r.status_code == 422


def test_local_date_is_used():
    client, _ = _client()
    r = client.post("/v1/briefings/morning", json={"local_date": "2026-11-20"}, headers=H)
    assert r.status_code == 200


# ---------------------------------------------------------------- T-AGT-04 modes

MODE_CALLS = [
    ("/v1/conversation/turn", {"text": "How can I sleep better?", "session_id": "s1"}, "reply"),
    ("/v1/reflections", {"text": "I walked after lunch and felt good."}, "reply"),
    ("/v1/nudges/copy", {"time_of_day": "midday"}, "nudge"),
    (
        "/v1/reviews/weekly",
        {
            "stats": {
                "week_start": "2026-11-16",
                "days_checked_in": 5,
                "habit_days_done": 4,
                "habit_days_planned": 7,
                "streak_days": 4,
            }
        },
        "weekly_review",
    ),
]


@pytest.mark.parametrize(("path", "body", "mtype"), MODE_CALLS)
def test_mode_endpoints_end_to_end(path, body, mtype):
    client, model = _client()
    r = client.post(path, json=body, headers=H)
    assert r.status_code == 200, r.text
    out = r.json()
    assert out["route"] == "coach" and out["message"]["type"] == mtype
    assert model.calls == 1


@pytest.mark.parametrize(("path", "body", "mtype"), MODE_CALLS)
def test_mode_endpoints_need_auth_consent_and_context(path, body, mtype):
    client, model = _client(consented=())
    assert client.post(path, json=body).status_code == 401
    assert client.post(path, json=body, headers=H).status_code == 403
    h = {**H, "Authorization": "Bearer token-nobody"}
    assert client.post(path, json=body, headers=h).status_code == 404
    assert client.post(path, json={**body, "extra": 1}, headers=H).status_code == 422
    assert model.calls == 0


def test_conversation_turn_red_flag_is_a_template_without_model():
    client, model = _client()
    r = client.post(
        "/v1/conversation/turn",
        json={"text": "I have crushing chest pain and my left arm is numb", "session_id": "s1"},
        headers=H,
    )
    body = r.json()
    assert body["route"] == "safety_template" and body["voice"] == "neutral_device"
    assert "Call 911." in body["message"]["text"] and model.calls == 0


def test_conversation_turn_limits():
    client, _ = _client()
    r = client.post(
        "/v1/conversation/turn", json={"text": "x" * 1001, "session_id": "s1"}, headers=H
    )
    assert r.status_code == 422
    r = client.post("/v1/reflections", json={"text": "x" * 501}, headers=H)
    assert r.status_code == 422


def test_reflection_returns_barrier_field():
    client, _ = _client()
    r = client.post("/v1/reflections", json={"text": "Felt good today."}, headers=H)
    assert r.json()["barrier"] == "none"
