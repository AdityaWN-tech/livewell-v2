"""ModelClient (spec 9.2): the only way the service talks to an LLM.

Two implementations: AnthropicModelClient (anthropic_client.py, real) and
FakeModelClient (here; deterministic, used by every test and by CI).
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from typing import Literal, Protocol

ModelStatus = Literal["ok", "refusal", "truncated", "error"]

#: ModelRequest.purpose of the safety classifier calls (safety/classifier.py);
#: also their prompt ids in the registry.
CLASSIFIER_INPUT_PURPOSE = "safety_classifier_input"
CLASSIFIER_OUTPUT_PURPOSE = "safety_classifier_output"


@dataclass(frozen=True)
class ModelRequest:
    purpose: str
    system: str
    user: str
    json_schema: dict[str, object]


@dataclass(frozen=True)
class ModelResult:
    status: ModelStatus
    text: str
    #: The model that actually answered (a server-side fallback may differ).
    model: str
    input_tokens: int = 0
    output_tokens: int = 0
    #: Exception class name or refusal category; never a message body.
    error: str | None = None
    request_id: str | None = None


class ModelClient(Protocol):
    @property
    def provider(self) -> str: ...

    def generate(self, request: ModelRequest) -> ModelResult: ...


# ------------------------------------------------------------------- fake

_CONTEXT = re.compile(r"<user_context>\s*(\{.*\})\s*</user_context>", re.DOTALL)

FAKE_MODEL = "fake-model@0"


def default_fake_briefing(request: ModelRequest) -> str:
    """A deterministic, policy-clean briefing built from the context JSON."""
    m = _CONTEXT.search(request.user)
    ctx: dict[str, object] = json.loads(m.group(1)) if m else {}
    name = ctx.get("first_name") or "there"
    parts = [f"Good morning, {name}!"]
    step = ctx.get("plan_step")
    if isinstance(step, dict):
        parts.append(f"Today's step is {step.get('title')}, about {step.get('minutes')} minutes.")
        if step.get("smaller_minutes"):
            parts.append(f"Short on time? {step.get('smaller_minutes')} minutes still counts.")
    else:
        parts.append("Let's find one small step that fits your day.")
    if ctx.get("why"):
        parts.append("It is one more small step toward what matters to you.")
    parts.append("How are you feeling today?")
    return json.dumps({"text": " ".join(parts), "emotion": "encouraging"})


def default_fake_answer(request: ModelRequest) -> str:
    """The fake's unscripted answer: a clean classifier verdict for the safety
    classifier, else a briefing. (A clean verdict can't clear anything: the
    classifier only escalates, and the rules run first.)"""
    if request.purpose == CLASSIFIER_INPUT_PURPOSE:
        return json.dumps({"category": "none", "fields": []})
    if request.purpose == CLASSIFIER_OUTPUT_PURPOSE:
        return json.dumps({"verdict": "ok", "reasons": []})
    return default_fake_briefing(request)


Scripted = str | ModelResult | Callable[[ModelRequest], str]


@dataclass
class FakeModelClient:
    """Deterministic stand-in. With no script it answers `default_fake_answer`;
    with a script it returns each entry in turn (a raw string is an "ok"
    answer, so tests can feed invalid JSON or unsafe drafts), then repeats the
    last one. Records every request so tests can assert "no model call"."""

    script: Sequence[Scripted] = ()
    requests: list[ModelRequest] = field(default_factory=list)

    @property
    def provider(self) -> str:
        return "fake"

    @property
    def calls(self) -> int:
        return len(self.requests)

    def generate(self, request: ModelRequest) -> ModelResult:
        self.requests.append(request)
        if not self.script:
            return ModelResult("ok", default_fake_answer(request), FAKE_MODEL, 100, 40)
        entry = self.script[min(len(self.requests), len(self.script)) - 1]
        if isinstance(entry, ModelResult):
            return entry
        text = entry(request) if callable(entry) else entry
        return ModelResult("ok", text, FAKE_MODEL, 100, 40)
