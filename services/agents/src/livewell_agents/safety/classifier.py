"""Safety classifier (spec 9.3 `safety_classifier`; FR-SAF-01 "keyword and
classifier redundancy"). HUMAN REVIEW REQUIRED (AGENTS.md rule 9).

The deterministic rules (rules.py) always run first and are authoritative.
The classifier is a second, independent check behind them:
  - it may only ESCALATE: flag a category the rules missed, or a more urgent
    one. It can never clear, downgrade or replace a rule hit; the combining
    functions (precheck.escalate_pre, postcheck.escalate_post) enforce that;
  - any failure (model error or timeout, refusal, truncation, invalid JSON,
    unknown label, prompt not approved here, an exception) gives a FAILED
    verdict, and callers then take the safe path, never the open one;
  - emergency and crisis rule hits never wait for it: they are answered from
    fixed templates before any model call (briefing.py).
It talks to an LLM only through ModelClient (FakeModelClient in tests and CI).
Only labels, field names and short reason codes leave this module, never text.
"""

from __future__ import annotations

import json
import logging
import time
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Literal, cast, get_args

from livewell_agents.model_client import (
    CLASSIFIER_INPUT_PURPOSE,
    CLASSIFIER_OUTPUT_PURPOSE,
    ModelClient,
    ModelRequest,
)
from livewell_agents.models import SafetyCategory
from livewell_agents.prompts import PromptRegistry, tag_safe_json
from livewell_agents.tracing import set_attrs, span

log = logging.getLogger("livewell_agents.safety.classifier")

INPUT_PROMPT_ID = CLASSIFIER_INPUT_PURPOSE
OUTPUT_PROMPT_ID = CLASSIFIER_OUTPUT_PURPOSE

CATEGORIES: tuple[SafetyCategory, ...] = get_args(SafetyCategory)

OutputReason = Literal[
    "medication_advice",
    "dose_numbers",
    "cure_claim",
    "diagnosis",
    "self_harm",
    "emergency",
    "disordered_eating",
    "weight_or_calories",
    "shaming",
    "other_policy",
]
OUTPUT_REASONS: tuple[str, ...] = get_args(OutputReason)
#: A draft flagged for these is never retried (same as a rule hit on them).
BLOCKING_REASONS = frozenset({"self_harm", "emergency"})

INPUT_JSON_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {
        "category": {"type": "string", "enum": ["none", *CATEGORIES]},
        "fields": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["category", "fields"],
    "additionalProperties": False,
}

OUTPUT_JSON_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {
        "verdict": {"type": "string", "enum": ["ok", "unsafe"]},
        "reasons": {"type": "array", "items": {"type": "string", "enum": list(OUTPUT_REASONS)}},
    },
    "required": ["verdict", "reasons"],
    "additionalProperties": False,
}

Status = Literal["ok", "failed"]


@dataclass(frozen=True)
class InputVerdict:
    status: Status
    #: None = nothing found (only meaningful when status is "ok").
    category: SafetyCategory | None
    #: Names of the fields that led to the category (never their text).
    fields: tuple[str, ...]
    #: Short code: "clear", "flagged", or why it failed.
    reason: str

    @property
    def failed(self) -> bool:
        return self.status == "failed"


@dataclass(frozen=True)
class OutputVerdict:
    status: Status
    #: Reason codes from OUTPUT_REASONS; empty = the draft looked fine.
    reasons: tuple[str, ...]
    reason: str

    @property
    def failed(self) -> bool:
        return self.status == "failed"

    @property
    def unsafe(self) -> bool:
        return bool(self.reasons)


def _input_failed(reason: str) -> InputVerdict:
    return InputVerdict("failed", None, (), reason)


def _output_failed(reason: str) -> OutputVerdict:
    return OutputVerdict("failed", (), reason)


class SafetyClassifier:
    """LLM-backed classifier for user input (pre) and model drafts (post)."""

    def __init__(self, model: ModelClient, prompts: PromptRegistry, allow_pending: bool) -> None:
        self._model = model
        self._prompts = prompts
        self._allow_pending = allow_pending

    # ------------------------------------------------------------ pre

    def classify_input(self, fields: Mapping[str, str]) -> InputVerdict:
        with span("safety.classifier", {"lw.node": INPUT_PROMPT_ID}) as s:
            verdict = self._classify_input(fields)
            set_attrs(
                s,
                {
                    "lw.decision": verdict.status,
                    "lw.reason": verdict.reason,
                    "lw.safety.category": verdict.category,
                    "lw.fields": list(verdict.fields),
                },
            )
        log.info(
            "safety_classifier purpose=input status=%s reason=%s category=%s fields=%d",
            verdict.status,
            verdict.reason,
            verdict.category,
            len(verdict.fields),
        )
        return verdict

    def _classify_input(self, fields: Mapping[str, str]) -> InputVerdict:
        if not fields:
            return InputVerdict("ok", None, (), "clear")
        raw = self._call(
            INPUT_PROMPT_ID,
            f"Label these fields.\n<fields>\n{tag_safe_json(dict(fields))}\n</fields>",
            INPUT_JSON_SCHEMA,
        )
        if isinstance(raw, str):
            return _input_failed(raw)
        category = raw.get("category")
        names = raw.get("fields")
        if category not in ("none", *CATEGORIES) or not isinstance(names, list):
            return _input_failed("invalid_json")
        if category == "none":
            return InputVerdict("ok", None, (), "clear")
        # Unknown names are dropped; none left means every field is flagged.
        known = tuple(dict.fromkeys(n for n in names if isinstance(n, str) and n in fields))
        return InputVerdict("ok", cast(SafetyCategory, category), known or tuple(fields), "flagged")

    # ------------------------------------------------------------ post

    def classify_output(self, text: str) -> OutputVerdict:
        with span("safety.classifier", {"lw.node": OUTPUT_PROMPT_ID}) as s:
            verdict = self._classify_output(text)
            set_attrs(
                s,
                {
                    "lw.decision": verdict.status,
                    "lw.reason": verdict.reason,
                    "lw.reasons": list(verdict.reasons),
                },
            )
        log.info(
            "safety_classifier purpose=output status=%s reason=%s reasons=%s",
            verdict.status,
            verdict.reason,
            ",".join(verdict.reasons),
        )
        return verdict

    def _classify_output(self, text: str) -> OutputVerdict:
        raw = self._call(
            OUTPUT_PROMPT_ID,
            f"Review this draft.\n<draft>\n{tag_safe_json(text)}\n</draft>",
            OUTPUT_JSON_SCHEMA,
        )
        if isinstance(raw, str):
            return _output_failed(raw)
        verdict = raw.get("verdict")
        reasons = raw.get("reasons")
        if verdict not in ("ok", "unsafe") or not isinstance(reasons, list):
            return _output_failed("invalid_json")
        if any(r not in OUTPUT_REASONS for r in reasons):
            return _output_failed("invalid_json")
        codes = tuple(dict.fromkeys(cast(list[str], reasons)))
        # Conservative: "unsafe" without a reason, or "ok" that lists reasons,
        # both count as unsafe.
        if verdict == "unsafe" and not codes:
            codes = ("other_policy",)
        return OutputVerdict("ok", codes, "flagged" if codes else "clear")

    # ------------------------------------------------------------ shared

    def _call(
        self, prompt_id: str, user: str, schema: dict[str, object]
    ) -> dict[str, object] | str:
        """The parsed JSON object, or a failure reason code."""
        try:
            prompt = self._prompts.active(prompt_id, allow_pending=self._allow_pending)
            if prompt is None:
                return "prompt_not_approved"
            started = time.monotonic()
            result = self._model.generate(
                ModelRequest(purpose=prompt_id, system=prompt.text, user=user, json_schema=schema)
            )
            log.info(
                "safety_classifier_call purpose=%s model=%s status=%s duration_ms=%d",
                prompt_id,
                result.model,
                result.status,
                int((time.monotonic() - started) * 1000),
            )
        except Exception as e:  # fail safe on anything, including a bad prompt file
            log.warning(
                "safety_classifier_exception purpose=%s class=%s", prompt_id, type(e).__name__
            )
            return "exception"
        if result.status != "ok":
            return result.status
        try:
            parsed = json.loads(result.text)
        except ValueError:
            return "invalid_json"
        if not isinstance(parsed, dict):
            return "invalid_json"
        return cast(dict[str, object], parsed)
