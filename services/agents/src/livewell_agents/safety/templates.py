"""Fixed texts. No model writes any of these (spec 9.4 step 3, FR-SAF-01/02).

The safety wording is the app's own (apps/mobile/lib/l10n/app_en.arb, the
`safety*` and country strings); a test fails if they drift apart. Numbers come
from packages/safety-rules/rules.json per region (D-03); an unknown region
shows both regions, as the app does. HUMAN REVIEW REQUIRED (AGENTS.md rule 9).
"""

from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

from livewell_agents.models import (
    Action,
    CoachMessage,
    Region,
    SafetyCategory,
    SafetyInfo,
)
from livewell_agents.safety.rules import Contacts

#: Copied from app_en.arb (test: test_templates_match_app_strings).
APP_STRINGS: dict[str, str] = {
    "safetyEmergencyTitle": "This could be an emergency",
    "safetyEmergencyBody": (
        "Please call for emergency help now. If you can, unlock your door and ask "
        "someone to stay with you."
    ),
    "safetyCallNumber": "Call {number}",
    "safetyCallNumberIn": "Call {number} in {country}",
    "safetyCrisisTitle": "You don't have to face this alone",
    "safetyCrisisBody": (
        "If you're thinking about suicide or hurting yourself, please reach out to someone "
        "right now. It's free and confidential, and they're there day and night."
    ),
    "safetyCrisisCall": "Call {name}: {number}",
    "safetyCrisisText": "Text {number}",
    "safetyCrisisDanger": "If you're in danger right now, call emergency services.",
    "safetyEdTitle": "Let's take care of you first",
    "safetyEdBody": (
        "It sounds like food or your body may feel hard right now. Live Well won't help with "
        "very low-calorie or fast weight-loss plans. A doctor or an eating-disorder specialist "
        "can support you, and you deserve that support."
    ),
    "safetyMedTitle": "Medicine changes are for you and your prescriber",
    "safetyMedBody": (
        "Please don't start, stop or change any medicine or supplement without talking to the "
        "doctor who prescribed it. Live Well can help with daily habits alongside your treatment."
    ),
    "safetyComplexTitle": "Check with your clinician first",
    "safetyComplexBody": (
        "Pregnancy and some health conditions change what's safe for you. Please talk to your "
        "doctor or midwife before changing how you eat or move."
    ),
    "countryIndiaName": "India",
    "countryUsName": "the US",
}

TEMPLATE_VERSION = "safety_template_0.1-draft"
NO_MODEL = "none"


def _s(key: str, **values: str) -> str:
    text = APP_STRINGS[key]
    for k, v in values.items():
        text = text.replace("{" + k + "}", v)
    return text


def _country(region: Region) -> str:
    return _s("countryIndiaName") if region == "IN" else _s("countryUsName")


def _emergency_actions(contacts: list[Contacts]) -> list[Action]:
    both = len(contacts) > 1
    return [
        Action(
            label=(
                _s("safetyCallNumberIn", number=c.emergency, country=_country(c.region))
                if both
                else _s("safetyCallNumber", number=c.emergency)
            ),
            action_id=f"call:{c.emergency}",
        )
        for c in contacts
    ]


def _crisis_actions(contacts: list[Contacts]) -> list[Action]:
    out: list[Action] = []
    for c in contacts:
        out.append(
            Action(
                label=_s("safetyCrisisCall", name=c.crisis_name, number=c.crisis_call),
                action_id=f"call:{c.crisis_call}",
            )
        )
        if c.crisis_text:
            out.append(
                Action(
                    label=_s("safetyCrisisText", number=c.crisis_text),
                    action_id=f"sms:{c.crisis_text}",
                )
            )
    return out


def safety_message(category: SafetyCategory, contacts: list[Contacts]) -> CoachMessage:
    """The fixed message for a red flag. Emergency and crisis carry one-tap
    calls for the user's region (both regions when unknown)."""
    actions: list[Action]
    if category == "emergency":
        actions = _emergency_actions(contacts)
        text = f"{_s('safetyEmergencyTitle')}. {_s('safetyEmergencyBody')} " + " ".join(
            f"{a.label}." for a in actions
        )
    elif category == "crisis":
        crisis, emergency = _crisis_actions(contacts), _emergency_actions(contacts)
        actions = crisis + emergency
        text = " ".join(
            [f"{_s('safetyCrisisTitle')}.", _s("safetyCrisisBody")]
            + [f"{a.label}." for a in crisis]
            + [_s("safetyCrisisDanger")]
            + [f"{a.label}." for a in emergency]
        )
    else:
        title, body = {
            "disordered_eating": ("safetyEdTitle", "safetyEdBody"),
            "medication": ("safetyMedTitle", "safetyMedBody"),
            "pregnancy_complex": ("safetyComplexTitle", "safetyComplexBody"),
        }[category]
        actions = []
        text = f"{_s(title)}. {_s(body)}"
    return CoachMessage(
        message_id=str(uuid.uuid4()),
        type="briefing",
        text=text,
        emotion="neutral",
        primary_action=actions[0] if actions else None,
        secondary_actions=actions[1:],
        safety=SafetyInfo(status="safety_template", checks=["safety_pre"], category=category),
        contains_user_text=False,
        model=NO_MODEL,
        prompt_version=TEMPLATE_VERSION,
    )


# ------------------------------------------------------------ fallback briefing

#: Fixed actions for a morning briefing (content/coach/moments/morning.json
#: lists the ids). Labels are fixed app copy, never model output.
BRIEFING_PRIMARY = Action(label="Check in", action_id="check_in")
BRIEFING_SECONDARY = (
    Action(label="Start my step", action_id="start_step"),
    Action(label="Make it smaller", action_id="make_smaller"),
)

_PLACEHOLDER = re.compile(r"\{[a-z_]+\}")


class FallbackBriefing:
    """The safe fixed morning text used when the model is unavailable or its
    draft fails the post-check: the morning moment variant with no personal
    placeholders (content/coach/moments/morning.json, review_status pending)."""

    VARIANT_ID = "m6"

    def __init__(self, moment_path: Path) -> None:
        data = json.loads(moment_path.read_text(encoding="utf-8"))
        variant = next(v for v in data["variants"] if v["id"] == self.VARIANT_ID)
        text = str(variant["text"]).replace("{time_of_day}", "morning")
        if _PLACEHOLDER.search(text):
            raise ValueError("fallback briefing must not need personal placeholders")
        self.text = text
        self.version = f"moment_morning_v{data['version']}_{self.VARIANT_ID}"

    def message(self, checks: list[str]) -> CoachMessage:
        return CoachMessage(
            message_id=str(uuid.uuid4()),
            type="briefing",
            text=self.text,
            emotion="calm",
            primary_action=BRIEFING_PRIMARY,
            secondary_actions=list(BRIEFING_SECONDARY),
            safety=SafetyInfo(status="fallback", checks=checks),
            contains_user_text=False,
            model=NO_MODEL,
            prompt_version=self.version,
        )
