"""Portal Agent (T-AGT-07, D-105): every spec 13.3 rule, the step 2 score,
the card, the bridge line and the endpoint. Synthetic data only."""

import json
from datetime import UTC, date, datetime, timedelta
from fractions import Fraction
from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi.testclient import TestClient

from conftest import dev_settings
from livewell_agents.app import Deps, create_app
from livewell_agents.auth import FakeAuthenticator, FakeConsents
from livewell_agents.config import ConfigError, load_settings
from livewell_agents.context import FixtureContextSource
from livewell_agents.model_client import FakeModelClient, ModelResult
from livewell_agents.portal import (
    BridgeWriter,
    InMemoryPortalSource,
    NotConfiguredPortalSource,
    PortalAgent,
    PortalConsents,
    PortalEvent,
    PortalOffer,
    PortalRecommendRequest,
    PortalState,
    PortalUnavailable,
)
from livewell_agents.portal.agent import attribution_url, price_label
from livewell_agents.portal.bridge import portal_reasons
from livewell_agents.portal.models import ALLOWED_SURFACES
from livewell_agents.portal.policy import Gate, offer_block, person_block, pick, score, showings
from livewell_agents.portal.store import event_from, offer_from
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.events import ListSafetyEventSink

NOW = datetime(2026, 11, 23, 18, 0, tzinfo=UTC)
TODAY = date(2026, 11, 23)
GATE = Gate(flag_on=True, portal_consent=True)


def offer(offer_id="o_sleep", **kw):
    base = {
        "offer_id": offer_id,
        "title": "Sleep Well Basics",
        "description": "A short guide to a calmer evening routine.",
        "url": "https://livewell.conciergeconnectedcare.net/web/courses/sleep",
        "offer_type": "course",
        "driver_tags": ("sleep",),
        "topic_tags": ("sleep_routine",),
        "price_display": "$29",
    }
    return PortalOffer.model_validate({**base, **kw})


def state(**kw):
    base = {
        "age_confirmed": True,
        "account_created_at": NOW - timedelta(days=10),
        "safety_known": True,
        "focus_driver": "sleep",
        "streak_days": 7,
        "checkin_days_7": 5,
        "lessons_completed": 3,
    }
    return PortalState.model_validate({**base, **kw})


def ev(event, offer_id="o_sleep", ago=timedelta(days=1)):
    return PortalEvent(event=event, offer_id=offer_id, at=NOW - ago)


# ---------------------------------------------------------------- step 1, person level


def test_a_ready_person_has_no_block():
    assert person_block(state(), "evening_reflection", GATE, NOW) is None


@pytest.mark.parametrize("surface", sorted(ALLOWED_SURFACES))
def test_allowed_surfaces(surface):
    assert person_block(state(), surface, GATE, NOW) is None


@pytest.mark.parametrize("surface", ["morning_briefing", "nudge", "safety_message"])
def test_never_in_briefing_nudges_or_safety_messages(surface):
    assert person_block(state(), surface, GATE, NOW) == "surface_not_allowed"


@pytest.mark.parametrize(
    ("st", "gate", "reason"),
    [
        (state(), Gate(flag_on=False, portal_consent=True), "flag_off"),
        (state(), Gate(flag_on=True, portal_consent=False), "no_portal_consent"),
        (state(age_confirmed=False), GATE, "not_adult"),
        (state(safety_known=False), GATE, "safety_unknown"),
        (
            state(last_safety_event_at=NOW - timedelta(hours=71, minutes=59)),
            GATE,
            "recent_safety_event",
        ),
        (state(ed_safe_mode=True), GATE, "ed_safe_mode"),
        (state(gentle_day=True), GATE, "gentle_day"),
        (state(account_created_at=NOW - timedelta(hours=47, minutes=59)), GATE, "first_48h"),
        (state(account_created_at=None), GATE, "first_48h"),
    ],
)
def test_person_rules(st, gate, reason):
    assert person_block(st, "weekly_review", gate, NOW) == reason


def test_safety_and_first_days_boundaries_pass_exactly_at_the_limit():
    assert (
        person_block(state(last_safety_event_at=NOW - timedelta(hours=72)), "milestone", GATE, NOW)
        is None
    )
    assert (
        person_block(state(account_created_at=NOW - timedelta(hours=48)), "milestone", GATE, NOW)
        is None
    )


def test_safety_comes_before_everything_about_the_person():
    st = state(safety_known=False, ed_safe_mode=True, gentle_day=True, account_created_at=None)
    assert person_block(st, "weekly_review", GATE, NOW) == "safety_unknown"


# ---------------------------------------------------------------- step 1, offer level


def _block(o, st, others=()):
    catalog = {x.offer_id: x for x in (o, *others)}
    return offer_block(o, st, catalog, NOW)


@pytest.mark.parametrize("owned", ["order", "progress", "completed"])
def test_already_bought_or_enrolled(owned):
    assert _block(offer(), state(events=(ev(owned, ago=timedelta(days=200)),))) == "already_owned"


def test_clicking_is_not_owning():
    assert _block(offer(), state(events=(ev("clicked", ago=timedelta(days=3)),))) is None


def test_cooldown_after_not_now_same_offer_and_same_topic():
    o = offer()
    other = offer("o_other", title="Evening Wind Down", topic_tags=("sleep_routine",))
    unrelated = offer("o_food", title="Cook Simple", topic_tags=("cooking",))
    assert (
        _block(o, state(events=(ev("dismissed", ago=timedelta(days=13, hours=23)),))) == "cooldown"
    )
    assert _block(o, state(events=(ev("dismissed", ago=timedelta(days=14)),))) is None
    dismissed_other = state(events=(ev("dismissed", "o_other", timedelta(days=2)),))
    assert _block(o, dismissed_other, (other,)) == "cooldown"
    dismissed_unrelated = state(events=(ev("dismissed", "o_food", timedelta(days=2)),))
    assert _block(o, dismissed_unrelated, (unrelated,)) is None


def test_one_card_a_day():
    o = offer()
    assert _block(o, state(events=(ev("card_shown", "o_x", timedelta(hours=23)),))) == "daily_cap"
    # The same card again today is not a second card.
    assert _block(o, state(events=(ev("card_shown", ago=timedelta(hours=2)),))) is None
    assert _block(o, state(events=(ev("card_shown", "o_x", timedelta(hours=24)),))) is None


def test_three_a_week():
    three = tuple(ev("card_shown", f"o_{i}", timedelta(days=d)) for i, d in enumerate((2, 4, 6)))
    assert _block(offer(), state(events=three)) == "weekly_cap"
    assert _block(offer(), state(events=three[:2])) is None
    old = (*three[:2], ev("card_shown", "o_9", timedelta(days=7)))
    assert _block(offer(), state(events=old)) is None


def test_the_same_card_seen_twice_in_a_day_counts_once():
    shown = (
        ev("card_shown", "o_a", timedelta(days=3)),
        ev("card_shown", "o_a", timedelta(days=3) - timedelta(hours=5)),
        ev("card_shown", "o_b", timedelta(days=5)),
    )
    assert len(showings(shown)) == 2
    assert _block(offer(), state(events=shown)) is None


# ---------------------------------------------------------------- step 2


def test_score_components():
    s = score(offer(), state(), (), NOW)
    assert (s.driver_match, s.readiness, s.intent, s.novelty) == (1, 1, 0, 1)
    assert s.total == Fraction(4, 5)
    s = score(offer(driver_tags=()), state(recent_topics=("sleep_routine",)), (), NOW)
    assert s.driver_match == Fraction(1, 2)
    s = score(offer(driver_tags=()), state(), ("sleep_routine",), NOW)
    assert (s.driver_match, s.intent) == (0, 1)
    s = score(offer(), state(streak_days=0, checkin_days_7=0, lessons_completed=0), (), NOW)
    assert s.readiness == 0
    s = score(offer(), state(streak_days=14, checkin_days_7=7, lessons_completed=9), (), NOW)
    assert s.readiness == 1


def test_novelty():
    assert score(
        offer(), state(events=(ev("card_shown", ago=timedelta(days=14)),)), (), NOW
    ).novelty == Fraction(1, 2)
    assert (
        score(offer(), state(events=(ev("card_shown", ago=timedelta(days=13)),)), (), NOW).novelty
        == 0
    )


def test_threshold_is_inclusive_and_exact():
    o = offer(driver_tags=())
    # 0.40 * 1/2 + 0.25 * 1 + 0 + 0.15 * 1 = 0.6 exactly: shown.
    at = state(focus_driver=None, recent_topics=("sleep_routine",))
    got, total, reason = pick([o], at, (), NOW)
    assert got == o and total == Fraction(3, 5) and reason == "ok"
    # A little less readiness: 0.588...: not shown.
    below = state(focus_driver=None, recent_topics=("sleep_routine",), streak_days=6)
    assert pick([o], below, (), NOW) == (None, 0, "below_threshold")


def test_readiness_and_novelty_alone_never_show_a_card():
    o = offer(driver_tags=(), topic_tags=("cooking",))
    assert pick([o], state(), (), NOW)[2] == "below_threshold"


def test_highest_score_wins_and_ties_go_to_the_smaller_id():
    low = offer("o_a", driver_tags=(), topic_tags=("sleep_routine",))
    high = offer("o_z")
    assert pick([low, high], state(), ("sleep_routine",), NOW)[0] == high
    twin_b, twin_a = offer("o_b"), offer("o_a")
    assert pick([twin_b, twin_a], state(), (), NOW)[0] == twin_a
    assert pick([twin_a, twin_b], state(), (), NOW)[0] == twin_a


def test_no_offers_and_blocked_offers():
    assert pick([], state(), (), NOW)[2] == "no_offers"
    st = state(events=(ev("order", ago=timedelta(days=1)),))
    assert pick([offer()], st, (), NOW)[2] == "already_owned"


# ---------------------------------------------------------------- the card


def test_attribution_url_has_ids_only_and_replaces_spoofed_keys():
    o = offer(url="https://livewell.conciergeconnectedcare.net/web/courses/x?ref=a&utm_source=evil")
    url = attribution_url(o, "weekly_review", "cid123")
    q = parse_qs(urlsplit(url).query)
    assert q == {
        "ref": ["a"],
        "utm_source": ["livewell_app"],
        "utm_medium": ["avatar"],
        "utm_campaign": ["weekly_review"],
        "utm_content": [o.offer_id],
        "lw_cid": ["cid123"],
    }
    assert url.startswith("https://livewell.conciergeconnectedcare.net/web/courses/x?")


def test_price_label():
    assert price_label(offer()) == "$29"
    assert price_label(offer(price_display=None)) == "Paid course"
    assert price_label(offer(offer_type="free_lesson", price_display=None)) == "Free"


def _agent(source, model=None, *, enabled=True, allow_pending=True, classifier=None, engine=None):
    s = dev_settings()
    prompts = PromptRegistry(s.prompts_dir)
    from livewell_agents.safety.rules import RedFlagEngine

    bridge = BridgeWriter(
        engine=engine or RedFlagEngine(s.safety_rules_dir),
        model=model or FakeModelClient(),
        prompts=prompts,
        classifier=SafetyClassifier(classifier or FakeModelClient(), prompts, allow_pending),
        allow_pending_prompts=allow_pending,
    )
    return PortalAgent(
        source=source, bridge=bridge, enabled=enabled, clock=lambda: NOW, new_id=lambda: "cid1"
    )


REQ = PortalRecommendRequest(surface="evening_reflection", local_date=TODAY)
BOTH = PortalConsents(portal=True, ai=True)


def test_card_is_copied_from_the_catalog():
    o = offer()
    out = _agent(InMemoryPortalSource([o], {"u1": state()})).recommend("u1", REQ, BOTH)
    card = out.card
    assert out.reason == "ok" and card is not None
    assert (card.offer_id, card.title, card.description, card.offer_type) == (
        o.offer_id,
        o.title,
        o.description,
        o.offer_type,
    )
    assert card.label == "From the Live Well Portal" and card.price_label == "$29"
    assert card.click_id == "cid1" and card.surface == "evening_reflection" and card.score == 0.8
    assert card.bridge_line == "Here is something from the Live Well Portal, if you'd like a look."


def test_no_ai_consent_means_no_bridge_line_and_no_model_call():
    model = FakeModelClient()
    agent = _agent(InMemoryPortalSource([offer()], {"u1": state()}), model)
    out = agent.recommend("u1", REQ, PortalConsents(portal=True, ai=False))
    assert out.card is not None and out.card.bridge_line is None and model.calls == 0


def test_unapproved_prompt_means_no_bridge_line():
    model = FakeModelClient()
    agent = _agent(InMemoryPortalSource([offer()], {"u1": state()}), model, allow_pending=False)
    out = agent.recommend("u1", REQ, BOTH)
    assert out.card is not None and out.card.bridge_line is None and model.calls == 0


class Counting(InMemoryPortalSource):
    reads = 0

    def state(self, uid, local_date):
        self.reads += 1
        return super().state(uid, local_date)

    def offers(self):
        self.reads += 1
        return super().offers()


@pytest.mark.parametrize(
    ("enabled", "surface", "consents", "reason"),
    [
        (False, "weekly_review", BOTH, "flag_off"),
        (True, "nudge", BOTH, "surface_not_allowed"),
        (True, "weekly_review", PortalConsents(portal=False, ai=True), "no_portal_consent"),
    ],
)
def test_nothing_is_read_when_the_gate_says_no(enabled, surface, consents, reason):
    src = Counting([offer()], {"u1": state()})
    req = PortalRecommendRequest(surface=surface, local_date=TODAY)
    out = _agent(src, enabled=enabled).recommend("u1", req, consents)
    assert out.card is None and out.reason == reason and src.reads == 0


def test_not_configured_source_refuses():
    with pytest.raises(PortalUnavailable):
        _agent(NotConfiguredPortalSource()).recommend("u1", REQ, BOTH)


# ---------------------------------------------------------------- the bridge line


@pytest.mark.parametrize(
    ("raw", "has_line"),
    [
        (
            json.dumps({"text": "Here is a gentle guide to calmer evenings, if you'd like it."}),
            True,
        ),
        ("not json", False),
        (json.dumps({"text": "Fine words here for you.", "extra": 1}), False),
        (ModelResult("error", "", "fake", 0, 0), False),
        (ModelResult("refused", "", "fake", 0, 0), False),
    ],
)
def test_bridge_line_model_failures_mean_no_line(raw, has_line):
    model = FakeModelClient(script=(raw,))
    out = _agent(InMemoryPortalSource([offer()], {"u1": state()}), model).recommend("u1", REQ, BOTH)
    assert out.card is not None and (out.card.bridge_line is not None) == has_line


def test_bridge_line_classifier_unsafe_or_failed_means_no_line():
    from evals.classifier_fakes import output_says

    agent = _agent(
        InMemoryPortalSource([offer()], {"u1": state()}), classifier=output_says("medical_advice")
    )
    assert agent.recommend("u1", REQ, BOTH).card.bridge_line is None
    broken = FakeModelClient(script=(ModelResult("error", "", "fake", 0, 0),))
    agent = _agent(InMemoryPortalSource([offer()], {"u1": state()}), classifier=broken)
    assert agent.recommend("u1", REQ, BOTH).card.bridge_line is None


def test_bridge_model_sees_only_the_offer():
    model = FakeModelClient()
    st = state(focus_driver="sleep")
    _agent(InMemoryPortalSource([offer()], {"u1": st}), model).recommend("u1", REQ, BOTH)
    user = model.requests[0].user
    assert "Sleep Well Basics" in user and "calmer evening routine" in user
    for private in ("u1", "focus", "streak", 'sleep"'):
        assert private not in user


@pytest.mark.parametrize(
    ("text", "reason"),
    [
        ("It takes just 10 minutes a day.", "number"),
        ("Hurry, places go fast.", "pressure"),
        ("You need this for better nights.", "pressure"),
        ("Your doctor recommends it.", "medical_advice"),
        ("A gentle treatment for restless nights.", "medical_advice"),
        ("Guaranteed calmer nights.", "guarantee"),
        ("Sleep Well Basics is here for you.", "offer_title"),
        ("One. Two. Three.", "too_many_sentences"),
    ],
)
def test_portal_reasons(text, reason):
    assert reason in portal_reasons(text, ["Sleep Well Basics"])


def test_portal_reasons_accepts_a_plain_invitation():
    assert (
        portal_reasons(
            "A calm guide to evening routines is here if you'd like a look.", ["Sleep Well Basics"]
        )
        == []
    )


# ---------------------------------------------------------------- stored documents


def test_offer_parser_only_live_offers():
    raw = {
        "title": "Sleep Well Basics",
        "url": "https://livewell.conciergeconnectedcare.net/web/courses/sleep",
        "offer_type": "course",
        "driver_tags": ["sleep"],
        "topic_tags": [],
        "price_display": "",
        "active": True,
        "review_status": "approved",
        "version": 3,
    }
    got = offer_from("o1", raw)
    assert got is not None and got.price_display is None and got.driver_tags == ("sleep",)
    assert offer_from("o1", {**raw, "active": False}) is None
    assert offer_from("o1", {**raw, "review_status": "in_review"}) is None
    assert offer_from("o1", {**raw, "url": "http://x.example/a"}) is None
    assert offer_from("o1", {**raw, "offer_type": "workshop"}) is None
    assert offer_from("o1", {**raw, "driver_tags": "sleep"}) is None
    assert offer_from("o1", {**raw, "driver_tags": ["Sleep Well"]}) is None
    assert offer_from("o1", {**raw, "topic_tags": None}) is None


def test_event_parser():
    at = NOW - timedelta(days=1)
    assert event_from({"event": "dismissed", "offer_id": "o1", "created_at": at}) == PortalEvent(
        event="dismissed", offer_id="o1", at=at
    )
    assert event_from({"event": "dismissed", "offer_id": "o1"}) is None
    assert event_from({"event": "liked", "offer_id": "o1", "created_at": at}) is None


# ---------------------------------------------------------------- settings and endpoint


def test_portal_settings(monkeypatch):
    monkeypatch.setenv("AGENTS_ENV", "dev")
    monkeypatch.delenv("LW_PORTAL_CARDS", raising=False)
    s = load_settings()
    assert s.portal_cards_enabled is False and s.portal_min_score == "0.6"
    for bad in ("0.4", "1.5", "abc"):
        monkeypatch.setenv("LW_PORTAL_MIN_SCORE", bad)
        with pytest.raises(ConfigError):
            load_settings()


H = {"Authorization": "Bearer token-demo-us", "X-Firebase-AppCheck": "app-check-ok"}


def _client(source, consents=("ai_disclosure", "portal_linking"), enabled=True):
    s = dev_settings(portal_cards_enabled=enabled)
    deps = Deps(
        settings=s,
        auth=FakeAuthenticator(),
        consents=FakeConsents({"demo-us": set(consents)}),
        contexts=FixtureContextSource(s.fixtures_path),
        model=FakeModelClient(),
        classifier_model=FakeModelClient(),
        events=ListSafetyEventSink(),
        portal=source,
    )
    return TestClient(create_app(deps))


BODY = {"surface": "weekly_review", "local_date": "2026-11-23"}


def test_endpoint_card_and_reasons():
    src = InMemoryPortalSource(
        [offer()], {"demo-us": state(account_created_at=datetime(2026, 1, 1, tzinfo=UTC))}
    )
    r = _client(src).post("/v1/portal/recommend", json=BODY, headers=H)
    assert r.status_code == 200, r.text
    assert r.json()["reason"] == "ok" and r.json()["card"]["offer_id"] == "o_sleep"
    r = _client(src, consents=("ai_disclosure",)).post("/v1/portal/recommend", json=BODY, headers=H)
    assert r.json() == {"card": None, "reason": "no_portal_consent"}
    r = _client(src, enabled=False).post("/v1/portal/recommend", json=BODY, headers=H)
    assert r.json() == {"card": None, "reason": "flag_off"}


def test_endpoint_auth_body_and_unconfigured():
    c = _client(InMemoryPortalSource())
    assert c.post("/v1/portal/recommend", json=BODY).status_code == 401
    assert (
        c.post(
            "/v1/portal/recommend", json={"surface": "home", "local_date": "2026-11-23"}, headers=H
        ).status_code
        == 422
    )
    assert (
        c.post("/v1/portal/recommend", json={**BODY, "question": "x"}, headers=H).status_code == 422
    )
    r = _client(NotConfiguredPortalSource()).post("/v1/portal/recommend", json=BODY, headers=H)
    assert r.status_code == 503 and r.json()["detail"] == "portal_unavailable"
