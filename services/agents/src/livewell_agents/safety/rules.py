"""The shared red-flag rules (T-ASM-02, D-21) as a typed engine.

Data comes from packages/safety-rules (rules.json and label_rules.json), the
same files the app bundles. The matching is the reference engine in
packages/safety-rules/check_cases.py, ported with types; a test runs the whole
shared case set through both and requires identical answers.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import cast

from livewell_agents.models import Region, SafetyCategory


def normalise(text: str) -> str:
    """Same normalisation as check_cases.py and the Dart engine."""
    t = text.lower().replace("\N{RIGHT SINGLE QUOTATION MARK}", "'")
    t = t.replace("\N{LEFT SINGLE QUOTATION MARK}", "'")
    t = re.sub(r"[^a-z0-9' ]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


@dataclass(frozen=True)
class Contacts:
    region: Region
    emergency: str
    crisis_call: str
    crisis_text: str | None
    crisis_name: str


@dataclass(frozen=True)
class Finding:
    """The winning category (None = clear) and every matching rule id."""

    category: SafetyCategory | None
    rule_ids: tuple[str, ...]

    @property
    def interrupts(self) -> bool:
        return self.category in ("emergency", "crisis")


@dataclass(frozen=True)
class _Rule:
    rule_id: str
    category: str
    patterns: tuple[re.Pattern[str], ...]

    def matches(self, normalised: str) -> bool:
        return any(p.search(normalised) for p in self.patterns)


class RedFlagEngine:
    def __init__(self, rules_dir: Path) -> None:
        data = json.loads((rules_dir / "rules.json").read_text(encoding="utf-8"))
        self.version: str = data["version"]
        self._priority: dict[str, int] = {c["id"]: c["priority"] for c in data["categories"]}
        self._rules = [_compile(r) for r in data["rules"]]
        self.contacts: dict[Region, Contacts] = {
            cast(Region, region): Contacts(
                region=cast(Region, region),
                emergency=c["emergency"],
                crisis_call=c["crisis_call"],
                crisis_text=c["crisis_text"],
                crisis_name=c["crisis_name"],
            )
            for region, c in data["contacts"].items()
        }
        labels = json.loads((rules_dir / "label_rules.json").read_text(encoding="utf-8"))
        #: Short-label rules (T-GOL-03c) by kind; the post-check reuses them on
        #: model output (medication words, weight/fasting, shaming words).
        self._label_rules = [_compile(r, key="kind") for r in labels["rules"]]

    def check(self, text: str) -> Finding:
        t = normalise(text)
        matched = [r for r in self._rules if r.matches(t)]
        if not matched:
            return Finding(None, ())
        best = min(matched, key=lambda r: self._priority[r.category]).category
        return Finding(cast(SafetyCategory, best), tuple(r.rule_id for r in matched))

    def rank(self, category: SafetyCategory) -> int:
        """1 = most urgent (emergency)."""
        return self._priority[category]

    def label_hits(self, text: str) -> tuple[tuple[str, str], ...]:
        """(rule id, kind) for every short-label rule that matches."""
        t = normalise(text)
        return tuple((r.rule_id, r.category) for r in self._label_rules if r.matches(t))

    def contacts_for(self, region: Region | None) -> list[Contacts]:
        """One region, or every region when it is unknown (D-03: never guess)."""
        if region is not None and region in self.contacts:
            return [self.contacts[region]]
        return list(self.contacts.values())


def _compile(raw: dict[str, object], key: str = "category") -> _Rule:
    patterns = cast(list[str], raw["patterns"])
    return _Rule(
        rule_id=str(raw["id"]),
        category=str(raw[key]),
        patterns=tuple(re.compile(p) for p in patterns),
    )
