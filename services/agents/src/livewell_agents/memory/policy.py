"""Which candidate facts may become proposals (plain code, spec 9.1 rule 1).

Every candidate the model returns passes `check_fact`; any doubt drops it.
Dropping only costs a fact that is not remembered; keeping a wrong one costs
privacy. Reason codes go to logs and traces, never the fact text.

  - length, confidence;
  - the shared red-flag rules (a crisis or emergency is never remembered);
  - weight/calorie/fasting and disordered-eating words (label rules): never
    remembered, whatever the category (FR-SAF-04; the coach may not talk
    about them anyway);
  - dose numbers, links, e-mail addresses, phone or other long numbers,
    money, markup and instruction-like text;
  - sensitivity: code reads the text for medicine, diagnosis and mental
    health words and moves the fact into that sensitive category, whatever
    the model said (escalate only: a model's sensitive label always stands).
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass

from livewell_agents.memory.models import (
    MAX_FACT_CHARS,
    MIN_FACT_CHARS,
    SENSITIVE_CATEGORIES,
    FactDraft,
    MemoryCategory,
)
from livewell_agents.safety.precheck import instruction_like
from livewell_agents.safety.rules import RedFlagEngine

#: Below this the model is guessing; the fact is not proposed.
MIN_CONFIDENCE = 0.7

_MEDICATION = re.compile(
    r"\b(?:medicines?|medications?|meds|pills?|tablets?|capsules?|insulin|metformin|statins?|"
    r"inhalers?|injections?|prescri\w*|doses?|dosage|supplements?|vitamins?|antibiotics?|"
    r"painkillers?|blood thinners?|ozempic|mounjaro|wegovy|semaglutide|tirzepatide|"
    r"paracetamol|ibuprofen|aspirin|dawai|dawa|goli)\b"
)
_DIAGNOSIS = re.compile(
    r"\b(?:diagnos\w*|diabet\w*|prediabet\w*|pre-diabet\w*|hypertension|high blood pressure|"
    r"blood pressure|cholesterol|thyroid|pcos|pcod|arthritis|asthma|copd|cancer|tumou?r|"
    r"heart (?:disease|condition|attack|failure)|stroke|kidney disease|fatty liver|"
    r"neuropathy|a1c|hba1c|sleep apnea|apnoea|condition|disorder|syndrome|disease|"
    r"pregnan\w*|surgery|chemo\w*)\b"
)
_MENTAL_HEALTH = re.compile(
    r"\b(?:depress\w*|anxiety|anxious|panic attacks?|therap(?:y|ist)|counsell?(?:ing|or)|"
    r"psychiatr\w*|psycholog\w*|bipolar|ptsd|ocd|adhd|trauma\w*|grief|grieving|bereave\w*|"
    r"mental health|antidepressants?|lonel\w*|eating disorder)\b"
)

_BANNED: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "dose_number",
        re.compile(
            r"\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|µg|g|grams?|ml|units?|iu|tablets?|pills?|doses?|"
            r"kcal|calories|kg|kgs|lbs?|pounds)\b"
        ),
    ),
    ("email", re.compile(r"[^\s@]+@[^\s@]+\.[a-z]{2,}")),
    ("link", re.compile(r"https?://|\bwww\.|\b[a-z0-9-]+\.(?:com|org|net|in|io|co)\b")),
    ("long_number", re.compile(r"(?:\d[\s-]?){5,}")),
    (
        "money",
        re.compile(r"[$₹€£]|\b(?:usd|inr|rupees?|dollars?|bank|password|otp|card number)\b"),
    ),
    ("markup", re.compile(r"[{}<>\[\]`#*\\]")),
)

#: Label-rule kinds never remembered (weight/diet words, disordered eating).
_NEVER_KINDS = {"not_allowed": "weight_or_diet", "disordered_eating": "disordered_eating"}


#: The shared red-flag rules are written for first-person input, but facts
#: are third person ("thinks about killing themself"). Never remembered.
_CRISIS_THIRD_PERSON = re.compile(
    r"\b(?:suicid\w*|self[- ]?harm\w*|overdos\w*|"
    r"kill(?:s|ing)? (?:themself|themselves|himself|herself|myself|yourself|oneself)|"
    r"hurt(?:s|ing)? (?:themself|themselves|himself|herself|myself|yourself|oneself)|"
    r"cut(?:s|ting)? (?:themself|themselves|himself|herself|myself)|"
    r"end(?:s|ing)? (?:their|his|her|my|your) (?:own )?life|end(?:s|ing)? it all|"
    r"(?:wants?|wanting|wish(?:es)?) to die|(?:does not|doesn'?t|don'?t|not) (?:want|wanting)"
    r" to (?:live|be alive|wake up)|better off dead|no reason to live)\b"
)

#: Eating patterns the label rules miss (FR-SAF-04): never remembered.
_EATING = re.compile(
    r"\b(?:skip(?:s|ped|ping)?|miss(?:es|ed|ing)?) (?:meals|breakfast|lunch|dinner|eating)\b"
    r"|\b(?:stay|staying|be|get|getting) (?:thin|skinny)\b|\bstarv\w*|\bpurg\w*|\bbing\w*"
    r"|\b(?:throw(?:s|ing)? up|vomit\w*|laxatives?|diet pills?)\b"
)


def normalise_fact(text: str) -> str:
    """Trimmed, single-spaced, no trailing full stop. What is stored."""
    t = re.sub(r"\s+", " ", text).strip()
    return t.rstrip(".").strip()


def fact_key(uid: str, text: str) -> str:
    """Same fact for the same person = same key, whatever the case or spacing.
    Kept after a delete so the fact is never proposed again."""
    canon = re.sub(r"[^a-z0-9 ]", "", normalise_fact(text).lower())
    canon = re.sub(r"\s+", " ", canon).strip()
    return hashlib.sha256(f"{uid}\n{canon}".encode()).hexdigest()


def sensitive_category(text: str) -> MemoryCategory | None:
    """The sensitive category the words show (medication first), or None."""
    lower = text.lower()
    if _MEDICATION.search(lower):
        return "medication"
    if _DIAGNOSIS.search(lower):
        return "diagnosis"
    if _MENTAL_HEALTH.search(lower):
        return "mental_health"
    return None


@dataclass(frozen=True)
class FactDecision:
    keep: bool
    #: Why it was dropped ("" when kept).
    reason: str
    fact: str
    category: MemoryCategory

    @property
    def sensitive(self) -> bool:
        return self.category in SENSITIVE_CATEGORIES


def check_fact(draft: FactDraft, engine: RedFlagEngine) -> FactDecision:
    text = normalise_fact(draft.fact)
    category: MemoryCategory = draft.category
    if draft.category not in SENSITIVE_CATEGORIES:
        category = sensitive_category(text) or draft.category

    def drop(reason: str) -> FactDecision:
        return FactDecision(False, reason, text, category)

    if len(text) < MIN_FACT_CHARS:
        return drop("too_short")
    if len(text) > MAX_FACT_CHARS:
        return drop("too_long")
    if draft.confidence < MIN_CONFIDENCE:
        return drop("low_confidence")
    if engine.check(text).category is not None or _CRISIS_THIRD_PERSON.search(text.lower()):
        return drop("red_flag")
    for _, kind in engine.label_hits(text):
        if kind in _NEVER_KINDS:
            return drop(_NEVER_KINDS[kind])
    lower = text.lower()
    if _EATING.search(lower):
        return drop("disordered_eating")
    for code, pattern in _BANNED:
        if pattern.search(lower):
            return drop(code)
    if instruction_like(text):
        return drop("instruction_like")
    return FactDecision(True, "", text, category)
