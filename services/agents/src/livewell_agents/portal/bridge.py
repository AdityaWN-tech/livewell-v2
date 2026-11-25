"""The bridge line: 1-2 sentences in the coach's voice before a portal card
(spec 13.3 step 2, 13.4). The model sees ONLY the offer's title and
description and the surface: no name, no Why, no check-ins, nothing personal.

A line is used only if every check passes; otherwise the card is shown
without one (never a retry: a plain card is always acceptable).
  1. Safety.post rules (red flags, medicine, cure or reversal claims, money,
     links, phone numbers, made-up offers, markup, length).
  2. Grounding: no health claim at all (no passages are given).
  3. Portal rules below (no numbers, no offer titles, no pressure, not
     framed as medical advice, at most 2 sentences).
  4. The output safety classifier (escalate only; a failure = no line).
"""

from __future__ import annotations

import json
import re
from collections.abc import Sequence

from pydantic import BaseModel, ConfigDict, Field, ValidationError

from livewell_agents.model_client import ModelClient, ModelRequest
from livewell_agents.models import CoachDraft
from livewell_agents.portal.models import PortalOffer
from livewell_agents.prompts import PromptRegistry, tag_safe_json
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.postcheck import escalate_post, grounding_check, post_check
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.tracing import set_attrs, span

PROMPT_ID = "portal_bridge"
MAX_CHARS = 200
MAX_SENTENCES = 2

BRIDGE_JSON_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {"text": {"type": "string"}},
    "required": ["text"],
    "additionalProperties": False,
}

_PORTAL_RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    # Prices, durations, percentages, dates: the card shows what the admin entered.
    ("number", re.compile(r"\d")),
    (
        "pressure",
        re.compile(
            r"\b(?:hurry|act now|don'?t miss|do not miss|last chance|only today|today only|"
            r"before it'?s gone|while it lasts|right now|must|need this|you need to|"
            r"you have to|you should (?:join|take|start|get))\b"
        ),
    ),
    (
        "medical_advice",
        re.compile(
            r"\b(?:doctor|dr\.?|physician|clinician|gokula)\b[^.!?]{0,30}"
            r"\b(?:recommends?|prescribes?|advises?|suggests?|wants you)\b"
            r"|\b(?:treatment|treats?|therapy|prescri\w*|medical advice|diagnos\w*|"
            r"recommended for (?:your|people with)|for your (?:condition|diabetes|disease|"
            r"blood sugar|blood pressure|weight))\b"
        ),
    ),
    (
        "guarantee",
        re.compile(r"\b(?:guarantee\w*|proven|results?|transform\w*|life[- ]changing)\b"),
    ),
)
_SENTENCE_END = re.compile(r"[.!?]+(?:\s|$)")


class _Draft(BaseModel):
    model_config = ConfigDict(extra="forbid")
    text: str = Field(min_length=1, max_length=1000)


def portal_reasons(text: str, catalog_titles: Sequence[str]) -> list[str]:
    """Portal-specific reasons to drop a line (empty = fine)."""
    lower = text.lower()
    reasons = [code for code, rx in _PORTAL_RULES if rx.search(lower)]
    if any(t.strip().lower() in lower for t in catalog_titles if t.strip()):
        reasons.append("offer_title")
    if len(_SENTENCE_END.findall(text.strip())) > MAX_SENTENCES:
        reasons.append("too_many_sentences")
    return reasons


class BridgeWriter:
    def __init__(
        self,
        *,
        engine: RedFlagEngine,
        model: ModelClient,
        prompts: PromptRegistry,
        classifier: SafetyClassifier,
        allow_pending_prompts: bool,
    ) -> None:
        self._engine = engine
        self._model = model
        self._prompts = prompts
        self._classifier = classifier
        self._allow_pending = allow_pending_prompts

    def write(
        self, offer: PortalOffer, surface: str, catalog_titles: Sequence[str]
    ) -> tuple[str | None, str]:
        """(line or None, reason code). Logs and spans carry codes only."""
        with span("portal.bridge", {"lw.offer_id": offer.offer_id}) as s:
            line, reason = self._write(offer, surface, catalog_titles)
            set_attrs(s, {"lw.decision": "line" if line else "none", "lw.reason": reason})
        return line, reason

    def _write(
        self, offer: PortalOffer, surface: str, catalog_titles: Sequence[str]
    ) -> tuple[str | None, str]:
        prompt = self._prompts.active(PROMPT_ID, allow_pending=self._allow_pending)
        if prompt is None:
            return None, "prompt_not_approved"
        user = (
            "Write the lead-in for this card.\n<offer>\n"
            + tag_safe_json(
                {"surface": surface, "title": offer.title, "description": offer.description or ""}
            )
            + "\n</offer>"
        )
        result = self._model.generate(
            ModelRequest(PROMPT_ID, prompt.text, user, BRIDGE_JSON_SCHEMA)
        )
        if result.status != "ok":
            return None, "model_failed"
        try:
            text = _Draft.model_validate(json.loads(result.text)).text.strip()
        except (ValueError, ValidationError):
            return None, "model_failed"
        draft = CoachDraft(text=text, emotion="encouraging")
        post = post_check(draft, self._engine, max_chars=MAX_CHARS)
        if post.verdict != "approve":
            return None, "post_" + post.reasons[0]
        grounding = grounding_check(draft, set())
        if grounding.verdict != "approve":
            return None, "post_" + grounding.reasons[0]
        portal = portal_reasons(text, catalog_titles)
        if portal:
            return None, "portal_" + portal[0]
        final = escalate_post(post, self._classifier.classify_output(text))
        if final.verdict != "approve":
            return None, "classifier"
        return text, "ok"
