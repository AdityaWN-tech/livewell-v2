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
