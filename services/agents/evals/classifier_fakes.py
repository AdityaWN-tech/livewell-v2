"""Scripted safety-classifier answers for FakeModelClient (tests and evals).

Every failure mode the classifier must fail safe on is listed in FAILURES.
Synthetic only; no network.
"""

from __future__ import annotations

import json

from livewell_agents.model_client import FakeModelClient, ModelRequest, ModelResult


def says(category: str | None, fields: tuple[str, ...] = ()) -> FakeModelClient:
    """Input classifier that always answers `category` (None = "none")."""
    return FakeModelClient(
        script=(json.dumps({"category": category or "none", "fields": list(fields)}),)
    )


def output_says(*reasons: str) -> FakeModelClient:
    """Output classifier: unsafe with these reasons, or ok when none."""
    verdict = "unsafe" if reasons else "ok"
    return FakeModelClient(script=(json.dumps({"verdict": verdict, "reasons": list(reasons)}),))


def _raise(request: ModelRequest) -> str:
    raise TimeoutError("synthetic")


#: Ways the classifier can fail. Each must give a FAILED verdict.
FAILURES: dict[str, object] = {
    "error": ModelResult("error", "", "fake-model@0", error="APITimeoutError"),
    "refusal": ModelResult("refusal", "", "fake-model@0", error="refusal:cyber"),
    "truncated": ModelResult("truncated", '{"category": "no', "fake-model@0"),
    "not_json": "I can't help with that.",
    "json_list": "[]",
    "unknown_label": json.dumps({"category": "fine", "fields": []}),
    "unknown_reason": json.dumps({"verdict": "unsafe", "reasons": ["vibes"]}),
    "missing_key": json.dumps({"fields": []}),
    "exception": _raise,
}


def fails(mode: str) -> FakeModelClient:
    return FakeModelClient(script=(FAILURES[mode],))  # type: ignore[arg-type]
