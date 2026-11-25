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


def _block(tag: str, user: str) -> object:
    m = re.search(rf"<{tag}>\s*(.*?)\s*</{tag}>", user, re.DOTALL)
    return json.loads(m.group(1)) if m else None


def _step(ctx: dict[str, object]) -> dict[str, object] | None:
    step = ctx.get("plan_step")
    return step if isinstance(step, dict) else None


def default_fake_reply(request: ModelRequest) -> str:
    """A policy-clean conversation turn; cites the first passage, if any,
    without stating a health fact."""
    ctx = _block("user_context", request.user)
    ctx = ctx if isinstance(ctx, dict) else {}
    passages = _block("passages", request.user)
    passages = passages if isinstance(passages, list) else []
    parts = [f"Thanks for asking, {ctx.get('first_name') or 'friend'}."]
    cited: list[str] = []
    if passages and isinstance(passages[0], dict):
        parts.append(f"The lesson {passages[0].get('title')} has a few ideas you might like.")
        cited.append(str(passages[0].get("source_id")))
    step = _step(ctx)
    if step:
        parts.append(f"For today, your step is {step.get('title')}.")
        if step.get("smaller_minutes"):
            parts.append(f"Even {step.get('smaller_minutes')} minutes counts.")
    else:
        parts.append("Let's pick one small step that fits your day.")
    return json.dumps({"text": " ".join(parts), "emotion": "encouraging", "source_ids": cited})


def default_fake_nudge(request: ModelRequest) -> str:
    ctx = _block("user_context", request.user)
    step = _step(ctx) if isinstance(ctx, dict) else None
    text = (
        f"It's a good time for your step: {step.get('title')}. Want to start now?"
        if step
        else "It's a good moment for one small step. Want to start now?"
    )
    return json.dumps({"text": text, "emotion": "encouraging"})


def default_fake_reflection(request: ModelRequest) -> str:
    ctx = _block("user_context", request.user)
    name = (ctx.get("first_name") if isinstance(ctx, dict) else None) or "friend"
    text = (
        f"Thank you for sharing, {name}. It sounds like today had some good moments. "
        "Rest well tonight, and tomorrow is a fresh start."
    )
    return json.dumps({"text": text, "emotion": "calm", "barrier": "none"})


def default_fake_weekly_review(request: ModelRequest) -> str:
    ctx = _block("user_context", request.user)
    ctx = ctx if isinstance(ctx, dict) else {}
    week = _block("week", request.user)
    week = week if isinstance(week, dict) else {}
    parts = [
        f"What a week, {ctx.get('first_name') or 'friend'}!",
        f"You checked in on {week.get('days_checked_in', 0)} days and did your step on "
        f"{week.get('habit_days_done', 0)} days.",
        "Every step counts.",
    ]
    step = _step(ctx)
    if step:
        parts.append(f"Next week, let's keep {step.get('title')} easy and steady.")
    return json.dumps({"text": " ".join(parts), "emotion": "celebrating"})


_FAKE_MEMORY = (
    (
        re.compile(r"\bi (?:really )?(?:prefer|like|love|enjoy) ([a-z ]{3,40}?)(?:[.!,]|$)"),
        "likes {}",
        "preference",
    ),
    (re.compile(r"\bi (?:work|do) (night shifts?|early shifts?)\b"), "works {}", "routine"),
    (
        re.compile(r"\bmy (knee|back|hip|shoulder|ankle) (?:gets sore|hurts|is sore)\b"),
        "{} gets sore",
        "physical",
    ),
)


def default_fake_memory(request: ModelRequest) -> str:
    """Deterministic memory candidates from simple first-person phrases."""
    src = _block("source", request.user)
    text = str(src.get("text", "")).lower() if isinstance(src, dict) else ""
    facts = []
    for pattern, template, category in _FAKE_MEMORY:
        m = pattern.search(text)
        if m:
            facts.append(
                {
                    "fact": template.format(m.group(1).strip()),
                    "category": category,
                    "confidence": 0.9,
                }
            )
    return json.dumps({"facts": facts})


def default_fake_portal_bridge(request: ModelRequest) -> str:
    """A policy-clean bridge line (T-AGT-07): no title, numbers or claims."""
    line = "Here is something from the Live Well Portal, if you'd like a look."
    return json.dumps({"text": line})


#: Coach mode prompt ids (graph.MODES) -> the fake's unscripted answer.
_FAKE_COACH: dict[str, Callable[[ModelRequest], str]] = {
    "coach_briefing": default_fake_briefing,
    "coach_reply": default_fake_reply,
    "coach_nudge": default_fake_nudge,
    "coach_reflection": default_fake_reflection,
    "coach_weekly_review": default_fake_weekly_review,
    "memory_extract": default_fake_memory,
    "portal_bridge": default_fake_portal_bridge,
}


def default_fake_answer(request: ModelRequest) -> str:
    """The fake's unscripted answer: a clean classifier verdict for the safety
    classifier, else a policy-clean draft for the Coach mode. (A clean verdict
    can't clear anything: the classifier only escalates, and the rules run first.)"""
    if request.purpose == CLASSIFIER_INPUT_PURPOSE:
        return json.dumps({"category": "none", "fields": []})
    if request.purpose == CLASSIFIER_OUTPUT_PURPOSE:
        return json.dumps({"verdict": "ok", "reasons": []})
    return _FAKE_COACH.get(request.purpose, default_fake_briefing)(request)


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
