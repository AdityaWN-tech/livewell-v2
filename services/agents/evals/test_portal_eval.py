"""Portal Agent eval (T-AGT-07 Done when: "all 13.3 rules have unit tests;
zero hallucinated offers in eval"; D-105).

1. Bridge lines: every line that invents an offer, a price, a link or an
   outcome, pressures, or reads as medical advice is dropped (critical).
2. Cards: over a grid of people, surfaces and catalogs, every card is an
   exact catalog entry, on an allowed surface, inside every 13.3 rule.
Cases: evals/cases/portal_eval.json (synthetic).
"""

import itertools
import json
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import pytest

from livewell_agents.config import REPO_ROOT, SERVICE_DIR
from livewell_agents.model_client import FakeModelClient
from livewell_agents.portal import (
    BridgeWriter,
    InMemoryPortalSource,
    PortalAgent,
    PortalConsents,
    PortalEvent,
    PortalOffer,
    PortalRecommendRequest,
    PortalState,
)
from livewell_agents.portal.models import ALLOWED_SURFACES
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.rules import RedFlagEngine

CASES = json.loads((Path(__file__).parent / "cases" / "portal_eval.json").read_text("utf-8"))
NOW = datetime(2026, 11, 23, 18, 0, tzinfo=UTC)
ENGINE = RedFlagEngine(REPO_ROOT / "packages" / "safety-rules")
PROMPTS = PromptRegistry(SERVICE_DIR / "prompts")

SLEEP = PortalOffer(
    offer_id="o_sleep",
    title=CASES["offer_title"],
    description=CASES["offer_description"],
    url="https://livewell.conciergeconnectedcare.net/web/courses/sleep",
    offer_type="course",
    driver_tags=("sleep",),
    topic_tags=("sleep_routine",),
    price_display="$29",
)
GUT = PortalOffer(
    offer_id="o_gut",
    title="Gut Health Starter",
    url="https://livewell.conciergeconnectedcare.net/web/courses/gut",
    offer_type="free_lesson",
    driver_tags=("nutrition",),
    topic_tags=("gut",),
)


def _agent(source, model):
    bridge = BridgeWriter(
        engine=ENGINE,
        model=model,
        prompts=PROMPTS,
        classifier=SafetyClassifier(FakeModelClient(), PROMPTS, True),
        allow_pending_prompts=True,
    )
    return PortalAgent(source=source, bridge=bridge, enabled=True, clock=lambda: NOW)


READY = PortalState(
    age_confirmed=True,
    account_created_at=NOW - timedelta(days=30),
    safety_known=True,
    focus_driver="sleep",
    streak_days=7,
    checkin_days_7=5,
    lessons_completed=3,
)
REQ = PortalRecommendRequest(surface="evening_reflection", local_date=date(2026, 11, 23))
BOTH = PortalConsents(portal=True, ai=True)


@pytest.mark.parametrize(
    "case",
    [pytest.param(c, id=c["id"], marks=[pytest.mark.critical]) for c in CASES["bridge_cases"]],
)
def test_bridge_line(case):
    model = FakeModelClient(script=(json.dumps({"text": case["text"]}),))
    out = _agent(InMemoryPortalSource([SLEEP, GUT], {"u": READY}), model).recommend("u", REQ, BOTH)
    assert out.card is not None and out.card.offer_id == "o_sleep"
    assert (out.card.bridge_line == case["text"]) is case["keep"]
    if not case["keep"]:
        assert out.card.bridge_line is None


def test_enough_hallucination_cases():
    drops = [c for c in CASES["bridge_cases"] if not c["keep"]]
    assert len(drops) >= 30 and len({c["id"] for c in CASES["bridge_cases"]}) == len(
        CASES["bridge_cases"]
    )


def _states():
    events_options = [
        (),
        (PortalEvent(event="card_shown", offer_id="o_gut", at=NOW - timedelta(hours=3)),),
        (PortalEvent(event="dismissed", offer_id="o_sleep", at=NOW - timedelta(days=2)),),
        (PortalEvent(event="order", offer_id="o_sleep", at=NOW - timedelta(days=90)),),
        tuple(
            PortalEvent(event="card_shown", offer_id=f"o_{i}", at=NOW - timedelta(days=d))
            for i, d in enumerate((2, 3, 5))
        ),
    ]
    for age, safe, last_event, ed, gentle, created, focus, events in itertools.product(
        (True, False),
        (True, False),
        (None, NOW - timedelta(hours=10), NOW - timedelta(days=4)),
        (False, True),
        (False, True),
        (NOW - timedelta(hours=20), NOW - timedelta(days=30)),
        ("sleep", "nutrition", None),
        events_options,
    ):
        yield PortalState(
            age_confirmed=age,
            safety_known=safe,
            last_safety_event_at=last_event,
            ed_safe_mode=ed,
            gentle_day=gentle,
            account_created_at=created,
            focus_driver=focus,
            events=events,
            streak_days=7,
            checkin_days_7=5,
            lessons_completed=3,
        )


@pytest.mark.critical
def test_every_card_is_a_catalog_entry_inside_every_rule():
    catalog = {o.offer_id: o for o in (SLEEP, GUT)}
    surfaces = (
        "evening_reflection",
        "weekly_review",
        "lesson_end",
        "milestone",
        "user_question",
        "morning_briefing",
        "nudge",
        "safety_message",
    )
    cards = 0
    for i, st in enumerate(_states()):
        surface = surfaces[i % len(surfaces)]
        req = PortalRecommendRequest(surface=surface, local_date=date(2026, 11, 23))
        out = _agent(InMemoryPortalSource([SLEEP, GUT], {"u": st}), FakeModelClient()).recommend(
            "u", req, BOTH
        )
        if out.card is None:
            continue
        cards += 1
        card, src = out.card, catalog[out.card.offer_id]
        assert (card.title, card.description, card.offer_type) == (
            src.title,
            src.description,
            src.offer_type,
        )
        assert card.label == "From the Live Well Portal"
        assert card.price_label in ("Free", src.price_display or "Paid course")
        assert card.url.split("?")[0] == src.url
        assert set(parse_qs(urlsplit(card.url).query)) == {
            "utm_source",
            "utm_medium",
            "utm_campaign",
            "utm_content",
            "lw_cid",
        }
        # Every 13.3 step 1 rule held.
        assert surface in ALLOWED_SURFACES
        assert st.age_confirmed and st.safety_known and not st.ed_safe_mode and not st.gentle_day
        assert st.last_safety_event_at is None or NOW - st.last_safety_event_at >= timedelta(
            hours=72
        )
        assert st.account_created_at is not None and NOW - st.account_created_at >= timedelta(
            hours=48
        )
        assert not any(e.offer_id == card.offer_id and e.event == "order" for e in st.events)
        assert card.score >= 0.6
    assert cards > 0  # the grid does reach cards, so the checks above ran
