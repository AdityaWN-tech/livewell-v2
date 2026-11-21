"""Pydantic I/O for the agent service (spec 9.1 (2): fixed JSON contracts).

`CoachMessage` mirrors spec 9.5 and packages/schemas/coach_message.schema.json
(a test checks every message we build validates against that schema).
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Region = Literal["US", "IN"]
Emotion = Literal["encouraging", "happy", "calm", "neutral", "celebrating"]
MessageType = Literal["briefing", "reply", "nudge", "reflection_prompt", "weekly_review"]
SafetyStatus = Literal["approved", "fallback", "safety_template"]
SafetyCategory = Literal[
    "emergency", "crisis", "disordered_eating", "medication", "pregnancy_complex"
]
Route = Literal["coach", "fallback", "safety_template"]


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


# ---------------------------------------------------------------- user context


class PlanStep(_Strict):
    title: str = Field(min_length=1, max_length=60)
    minutes: int = Field(ge=1, le=180)
    smaller_minutes: int | None = Field(default=None, ge=1, le=180)


class CheckIn(_Strict):
    day: date
    mood: int = Field(ge=1, le=5)
    energy: int = Field(ge=1, le=5)
    sleep: int | None = Field(default=None, ge=1, le=5)
    stress: int | None = Field(default=None, ge=1, le=5)
    note: str | None = Field(default=None, max_length=280)


class UserContext(_Strict):
    """What the briefing may know about the user (spec 9.4 step 2, trimmed to
    the spike: Why, plan step, last check-in, streak). Synthetic only here."""

    uid: str = Field(min_length=1, max_length=128)
    first_name: str = Field(min_length=1, max_length=40)
    coach_name: str = Field(default="Coach", min_length=1, max_length=20)
    #: None = not confirmed. Never guessed (D-03): safety texts then show both regions.
    region: Region | None = None
    local_date: date
    why: str | None = Field(default=None, max_length=280)
    focus_driver: str | None = Field(default=None, max_length=40)
    plan_step: PlanStep | None = None
    last_checkin: CheckIn | None = None
    streak_days: int = Field(default=0, ge=0, le=10_000)
    ed_safe_mode: bool = False
    last_safety_event_at: datetime | None = None

    def free_text(self) -> dict[str, str]:
        """Every field a person typed, by name. All of it is screened by
        Safety.pre before any of it reaches a model."""
        out: dict[str, str] = {"first_name": self.first_name, "coach_name": self.coach_name}
        if self.why:
            out["why"] = self.why
        if self.focus_driver:
            out["focus_driver"] = self.focus_driver
        if self.plan_step:
            out["plan_step.title"] = self.plan_step.title
        if self.last_checkin and self.last_checkin.note:
            out["last_checkin.note"] = self.last_checkin.note
        return out


# ---------------------------------------------------------------- model output


class CoachDraft(_Strict):
    """The only thing the model writes. Everything else in a CoachMessage
    (ids, actions, safety, versions) is filled in by code."""

    text: str = Field(min_length=1, max_length=2000)
    emotion: Emotion


#: JSON Schema sent to the model as the structured-output format. Kept to the
#: subset structured outputs supports; lengths are enforced by CoachDraft and
#: the post-check.
COACH_DRAFT_JSON_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {
        "text": {"type": "string"},
        "emotion": {
            "type": "string",
            "enum": ["encouraging", "happy", "calm", "neutral", "celebrating"],
        },
    },
    "required": ["text", "emotion"],
    "additionalProperties": False,
}


# ---------------------------------------------------------------- CoachMessage


class Action(_Strict):
    label: str = Field(min_length=1, max_length=40)
    action_id: str = Field(min_length=1, max_length=64)


class Source(_Strict):
    source_id: str
    title: str


class SsmlHints(_Strict):
    pauses: list[int] = Field(default_factory=list)
    emphasis: list[str] = Field(default_factory=list)


class SafetyInfo(_Strict):
    status: SafetyStatus
    checks: list[str]
    #: Set only on a safety template; the voice gateway (D-88) then routes the
    #: neutral device voice.
    category: SafetyCategory | None = None


class CoachMessage(_Strict):
    message_id: str
    type: MessageType
    text: str = Field(min_length=1, max_length=2000)
    ssml_hints: SsmlHints | None = None
    emotion: Emotion
    primary_action: Action | None
    secondary_actions: list[Action] = Field(default_factory=list)
    sources: list[Source] = Field(default_factory=list)
    mgdi_letter: str | None = None
    driver_tags: list[str] = Field(default_factory=list)
    portal_card: None = None
    safety: SafetyInfo
    #: D-88: model text may echo what the user wrote, so it is never spoken in
    #: a cloned voice. Only fixed texts are false.
    contains_user_text: bool
    model: str
    prompt_version: str


# ---------------------------------------------------------------- HTTP


class BriefingRequest(_Strict):
    #: The user's local date; defaults to the date in the stored context.
    local_date: date | None = None


class BriefingResponse(_Strict):
    route: Route
    #: "neutral_device" for safety templates (FR-VOC-07); otherwise the app
    #: asks the voice gateway with message_id (closed-script rule).
    voice: Literal["neutral_device", "gateway"]
    message: CoachMessage
