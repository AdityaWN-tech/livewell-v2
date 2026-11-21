"""Safety.post (spec 9.4 step 8): APPROVE | REWRITE(reason) | BLOCK.

Every model draft passes through here before anyone sees it; the graph has
no edge around it. Checks, all plain code:
  - the shared red-flag rules on the output (packages/safety-rules/rules.json);
  - the short-label rules (label_rules.json): medicine and supplement words,
    weight/calorie/fasting words, disordered-eating phrases, shaming words;
  - output rules below: cure or reversal promises, dose numbers, diagnosis,
    links, phone numbers (a model must never write an emergency number),
    money and payment words, markup or leftover placeholders, length.
Reasons are short codes; they go to traces and to the one retry, never text.

`escalate_post` then folds in the safety classifier (T-AGT-02) for a draft
the rules approved: it can turn APPROVE into REWRITE or BLOCK, never the
other way; a classifier that failed means BLOCK (the fixed fallback).
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import Literal

from livewell_agents.models import CoachDraft
from livewell_agents.safety.classifier import BLOCKING_REASONS, OutputVerdict
from livewell_agents.safety.rules import RedFlagEngine

Verdict = Literal["approve", "rewrite", "block"]

#: A spoken morning briefing: about 20-45 seconds.
MIN_CHARS = 20
MAX_CHARS = 600

CHECKS = ("red_flags", "label_rules", "med_rule", "cure_claims", "banned_content", "length")

#: (code, pattern, verdict). Patterns run on the lowercased raw text.
_OUTPUT_RULES: tuple[tuple[str, re.Pattern[str], Verdict], ...] = (
    # The shared rules are written for first-person input; a draft talks to
    # "you". A briefing never mentions self-harm: blocked, never retried.
    (
        "red_flag_crisis",
        re.compile(
            r"\b(?:suicid\w*|self[- ]?harm\w*|kill(?:ing)? (?:yourself|myself)|"
            r"end(?:ing)? (?:your|my) (?:own )?life|hurt(?:ing)? (?:yourself|myself)|"
            r"(?:want|wanting|wish) to die|not (?:want|wanting) to (?:live|be alive))\b"
        ),
        "block",
    ),
    (
        "cure_claim",
        re.compile(
            r"\b(?:cure[sd]?|curing|reverse[sd]?|reversing|reversal|remission|heal(?:s|ed|ing)? "
            r"(?:your|the|my) (?:body|diabetes|disease|condition|heart|blood)|get rid of "
            r"(?:your|the) (?:diabetes|disease|condition)|guarantee[sd]?|promise[sd]?)\b"
        ),
        "rewrite",
    ),
    (
        "dose_number",
        re.compile(
            r"\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|µg|g|grams?|ml|units?|iu|tablets?|pills?|doses?|"
            r"kcal|calories|kg|lbs?|pounds)\b"
        ),
        "rewrite",
    ),
    (
        "diagnosis",
        re.compile(
            r"\bdiagnos\w*|\byou (?:have|may have|might have) (?:a |an )?"
            r"(?:disease|disorder|condition|diabetes|depression)\b"
        ),
        "rewrite",
    ),
    ("link", re.compile(r"https?://|\bwww\.|\b[a-z0-9-]+\.(?:com|org|net|in|io)\b"), "block"),
    (
        "phone_number",
        re.compile(r"\b(?:911|988|112|14416|108|102)\b|(?:\+?\d[\s-]?){6,}"),
        "block",
    ),
    (
        "money",
        re.compile(
            r"[$₹€£]|\b(?:usd|inr|rupees?|dollars?|transfer|payment|pay|bank|password|"
            r"otp|card number|price|discount|buy)\b"
        ),
        "block",
    ),
    ("markup", re.compile(r"[{}<>\[\]`#*]|\\n"), "rewrite"),
)

_LABEL_CODES = {
    "medication": "med_rule",
    "not_allowed": "weight_or_diet",
    "disordered_eating": "disordered_eating",
    "unkind": "shaming",
}


@dataclass(frozen=True)
class PostCheckResult:
    verdict: Verdict
    reasons: tuple[str, ...]
    rule_ids: tuple[str, ...]
    checks: tuple[str, ...] = CHECKS


def post_check(draft: CoachDraft, engine: RedFlagEngine) -> PostCheckResult:
    text = draft.text
    lower = text.lower()
    reasons: list[str] = []
    rule_ids: list[str] = []
    verdict: Verdict = "approve"

    def fail(code: str, v: Verdict) -> None:
        nonlocal verdict
        if code not in reasons:
            reasons.append(code)
        verdict = "block" if v == "block" or verdict == "block" else "rewrite"

    finding = engine.check(text)
    if finding.category is not None:
        rule_ids.extend(finding.rule_ids)
        # A draft that itself talks about an emergency or self-harm is never retried.
        fail(f"red_flag_{finding.category}", "block" if finding.interrupts else "rewrite")
    for rule_id, kind in engine.label_hits(text):
        rule_ids.append(rule_id)
        fail(_LABEL_CODES.get(kind, kind), "rewrite")
    for code, pattern, v in _OUTPUT_RULES:
        if pattern.search(lower):
            fail(code, v)
    stripped = text.strip()
    if len(stripped) < MIN_CHARS:
        fail("too_short", "rewrite")
    if len(stripped) > MAX_CHARS:
        fail("too_long", "rewrite")
    return PostCheckResult(verdict, tuple(reasons), tuple(dict.fromkeys(rule_ids)))


#: Reason-code prefix for a classifier finding (e.g. cls_medication_advice).
CLASSIFIER_REASON_PREFIX = "cls_"
CLASSIFIER_CHECK = "safety_classifier_output"


def escalate_post(result: PostCheckResult, verdict: OutputVerdict) -> PostCheckResult:
    """Combine the rules' verdict with the classifier's. Escalate only."""
    checks = tuple(dict.fromkeys((*result.checks, CLASSIFIER_CHECK)))
    if verdict.failed:
        return replace(
            result,
            verdict="block",
            reasons=tuple(dict.fromkeys((*result.reasons, "classifier_unavailable"))),
            checks=checks,
        )
    if not verdict.unsafe:
        return replace(result, checks=checks)
    new: Verdict = (
        "block"
        if result.verdict == "block" or BLOCKING_REASONS.intersection(verdict.reasons)
        else "rewrite"
    )
    codes = (CLASSIFIER_REASON_PREFIX + r for r in verdict.reasons)
    return replace(
        result,
        verdict=new,
        reasons=tuple(dict.fromkeys((*result.reasons, *codes))),
        checks=checks,
    )
