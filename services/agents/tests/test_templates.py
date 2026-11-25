import json

import pytest

from livewell_agents.config import REPO_ROOT
from livewell_agents.safety.templates import APP_STRINGS, safety_message

ARB = json.loads(
    (REPO_ROOT / "apps" / "mobile" / "lib" / "l10n" / "app_en.arb").read_text(encoding="utf-8")
)


def test_templates_match_app_strings():
    for key, text in APP_STRINGS.items():
        assert ARB[key] == text, key


def _numbers(msg):
    return msg.text, [a.action_id for a in [msg.primary_action, *msg.secondary_actions] if a]


@pytest.mark.critical
def test_emergency_us_only_us_numbers(engine):
    msg = safety_message("emergency", engine.contacts_for("US"))
    text, actions = _numbers(msg)
    assert "Call 911." in text and "112" not in text
    assert actions == ["call:911"]
    assert msg.safety.status == "safety_template" and msg.safety.category == "emergency"
    assert msg.contains_user_text is False and msg.model == "none"


@pytest.mark.critical
def test_crisis_india(engine):
    msg = safety_message("crisis", engine.contacts_for("IN"))
    text, actions = _numbers(msg)
    assert "Call Tele-MANAS: 14416." in text and "Call 112." in text
    assert "988" not in text and "911" not in text
    assert actions == ["call:14416", "call:112"]


@pytest.mark.critical
def test_crisis_us_has_call_and_text(engine):
    _, actions = _numbers(safety_message("crisis", engine.contacts_for("US")))
    assert actions == ["call:988", "sms:988", "call:911"]


@pytest.mark.critical
@pytest.mark.parametrize("category", ["emergency", "crisis"])
def test_unknown_region_shows_both(engine, category):
    msg = safety_message(category, engine.contacts_for(None))
    assert "911 in the US" in msg.text and "112 in India" in msg.text
    if category == "crisis":
        assert "988" in msg.text and "14416" in msg.text


@pytest.mark.parametrize("category", ["disordered_eating", "medication", "pregnancy_complex"])
def test_other_cards_have_no_actions(engine, category):
    msg = safety_message(category, engine.contacts_for("US"))
    assert msg.primary_action is None and msg.secondary_actions == []


def test_fallback_is_fixed_and_passes_post_check(engine, fallback):
    from livewell_agents.models import CoachDraft
    from livewell_agents.safety.postcheck import post_check

    msg = fallback.message(["x"])
    assert "{" not in msg.text and msg.contains_user_text is False
    assert post_check(CoachDraft(text=msg.text, emotion="calm"), engine).verdict == "approve"
