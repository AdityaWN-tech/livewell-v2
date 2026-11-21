"""Golden-set case format and loader (T-AGT-08, spec 15.1-15.3, D-95).

A golden set is a folder with `manifest.json`, one or more `*.jsonl` files
(one case per line) and `known_gaps.json`. Every case says what it tests
(`category`), how bad a miss is (`severity`), the user's region and what the
system must do (`expect`). `target` names the runner (targets.py) that turns
`input` into an observed result; new runners (the T-AGT-02 classifier, T-AGT-03
retrieval) register under a new name and their cases go in new files.

Synthetic text only. No real user data, no PHI.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Severity = Literal["critical", "high", "normal"]
CaseRegion = Literal["US", "IN", "unknown"]
Tier = Literal["offline", "live"]

#: What a case is about. A new category needs a line here and in docs (D-95).
CATEGORIES: tuple[str, ...] = (
    "emergency",
    "crisis",
    "medication_input",
    "medication_output",
    "cure_claim",
    "disordered_eating",
    "pregnancy_complex",
    "ai_consent",
    "recent_safety_event",
    "closed_script_voice",
    "prompt_injection",
    "no_phi_in_logs",
    "schema_validity",
    "portal_policy",
    "no_false_alarm",
    "tone",
    "grounding",
    # T-AGT-04: reading numbers or trends as a condition (spec 9.3 "never
    # diagnose"; Insights "never interpret metrics diagnostically").
    "diagnosis",
)

#: Spec 15.2 gates a case can feed (runner.py computes them).
METRICS: tuple[str, ...] = (
    "critical_safety_routing",
    "med_instructions_in_outputs",
    "schema_validity",
    "portal_policy",
    "hallucinated_offers",
    "health_claims_sourced",
    "tone_rubric",
)


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class GoldenCase(_Strict):
    id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{1,63}$")
    category: str
    severity: Severity
    region: CaseRegion
    tier: Tier = "offline"
    target: str
    #: Where the requirement comes from (spec section, FR, decision).
    spec: str = Field(min_length=2)
    input: dict[str, Any]
    expect: dict[str, Any]
    #: Extra 15.2 metrics this case feeds (critical cases always feed
    #: critical_safety_routing).
    metrics: tuple[str, ...] = ()
    note: str | None = None
    #: Set by the loader: the file the case came from.
    source_file: str = ""

    @model_validator(mode="after")
    def _known_values(self) -> GoldenCase:
        if self.category not in CATEGORIES:
            raise ValueError(f"{self.id}: unknown category {self.category!r}")
        for m in self.metrics:
            if m not in METRICS:
                raise ValueError(f"{self.id}: unknown metric {m!r}")
        return self

    def feeds(self, metric: str) -> bool:
        if metric == "critical_safety_routing":
            return self.severity == "critical"
        return metric in self.metrics


class KnownGap(_Strict):
    """A case that fails today because of a real gap, kept on purpose.

    A known gap never counts as a pass. A critical known gap blocks the
    release gate (spec 15.2); it does not block merge, because it is not a
    regression. Adding one needs safety review (D-95)."""

    id: str
    #: Must equal the case's severity (so a gap can't quietly downgrade it).
    severity: Severity
    reason: str = Field(min_length=10)
    #: Task that should close it (e.g. T-AGT-02 classifier redundancy).
    owner_task: str = Field(min_length=3)
    added: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")


class Manifest(_Strict):
    version: str
    status: str
    about: str
    files: tuple[str, ...]
    min_offline_cases: int = 300


class GoldenSet(_Strict):
    manifest: Manifest
    cases: tuple[GoldenCase, ...]
    known_gaps: dict[str, KnownGap]

    def by_id(self) -> dict[str, GoldenCase]:
        return {c.id: c for c in self.cases}


class GoldenSetError(ValueError):
    pass


def load_golden_set(folder: Path) -> GoldenSet:
    manifest = Manifest.model_validate_json((folder / "manifest.json").read_text("utf-8"))
    cases: list[GoldenCase] = []
    seen: set[str] = set()
    for name in manifest.files:
        path = folder / name
        for lineno, line in enumerate(path.read_text("utf-8").splitlines(), start=1):
            if not line.strip():
                continue
            try:
                raw = json.loads(line)
                case = GoldenCase.model_validate({**raw, "source_file": name})
            except ValueError as exc:
                raise GoldenSetError(f"{name}:{lineno}: {exc}") from exc
            if case.id in seen:
                raise GoldenSetError(f"{name}:{lineno}: duplicate id {case.id!r}")
            seen.add(case.id)
            cases.append(case)
    unlisted = sorted(p.name for p in folder.glob("*.jsonl") if p.name not in manifest.files)
    if unlisted:
        raise GoldenSetError(f"jsonl files not listed in manifest.json: {unlisted}")
    gaps_raw = json.loads((folder / "known_gaps.json").read_text("utf-8"))
    gaps: dict[str, KnownGap] = {}
    for item in gaps_raw["gaps"]:
        gap = KnownGap.model_validate(item)
        case_by_id = {c.id: c for c in cases}
        if gap.id not in case_by_id:
            raise GoldenSetError(f"known_gaps.json names an unknown case {gap.id!r}")
        if gap.severity != case_by_id[gap.id].severity:
            raise GoldenSetError(f"known gap {gap.id!r}: severity differs from the case")
        if gap.id in gaps:
            raise GoldenSetError(f"known_gaps.json lists {gap.id!r} twice")
        gaps[gap.id] = gap
    return GoldenSet(manifest=manifest, cases=tuple(cases), known_gaps=gaps)
