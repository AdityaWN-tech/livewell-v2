"""Safety.pre for scheduled/briefing runs (spec 9.4 step 3, 9.1 (1)).

Runs in plain code BEFORE the graph and before any model call. It screens
every free-text field in the user context with the shared red-flag rules.
Any red flag means no model call at all: the fixed template for that
category is returned (emergency/crisis with region-aware numbers).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal

from livewell_agents.models import SafetyCategory, UserContext
from livewell_agents.safety.rules import RedFlagEngine

#: Spec 9.3 / FR-SAF-07 use 72 hours after a safety event for portal content.
#: Conservative choice for this slice (D-91): no model-written briefing in that
#: window either; the fixed gentle briefing is used instead.
RECENT_EVENT_WINDOW = timedelta(hours=72)

#: Instruction-like text in a user field (spec 15.3 "voice misuse"). Such a
#: field is withheld from the model; nothing else changes.
_INJECTION = re.compile(
    r"\b(?:repeat after me|say exactly|ignore (?:all |any |the )?(?:previous|prior|above|earlier)"
    r"|system prompt|you are now|new instructions?|disregard (?:all |the )?(?:previous|rules?)"
    r"|developer mode|jailbreak)\b",
    re.IGNORECASE,
)

Decision = Literal["ok", "safety_template", "fallback"]


@dataclass(frozen=True)
class PreCheckResult:
    decision: Decision
    category: SafetyCategory | None
    rule_ids: tuple[str, ...]
    #: Names of fields that matched a red flag (never their text).
    flagged_fields: tuple[str, ...]
    #: Names of fields withheld from the model as instruction-like.
    withheld_fields: tuple[str, ...]
    reason: str


def safety_pre(ctx: UserContext, engine: RedFlagEngine, now: datetime) -> PreCheckResult:
    best: SafetyCategory | None = None
    rule_ids: list[str] = []
    flagged: list[str] = []
    for name, text in ctx.free_text().items():
        finding = engine.check(text)
        if finding.category is None:
            continue
        flagged.append(name)
        rule_ids.extend(finding.rule_ids)
        if best is None or engine.rank(finding.category) < engine.rank(best):
            best = finding.category
    withheld = tuple(name for name, text in ctx.free_text().items() if _INJECTION.search(text))
    if best is not None:
        return PreCheckResult(
            "safety_template",
            best,
            tuple(dict.fromkeys(rule_ids)),
            tuple(flagged),
            withheld,
            "red_flag",
        )
    if (
        ctx.last_safety_event_at is not None
        and now - ctx.last_safety_event_at < RECENT_EVENT_WINDOW
    ):
        return PreCheckResult("fallback", None, (), (), withheld, "recent_safety_event")
    return PreCheckResult("ok", None, (), (), withheld, "clear")
