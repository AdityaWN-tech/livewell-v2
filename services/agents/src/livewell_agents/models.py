"""Pydantic I/O for the agent service (spec 9.1 (2): fixed JSON contracts).

`CoachMessage` mirrors spec 9.5 and packages/schemas/coach_message.schema.json
(a test checks every message we build validates against that schema).
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal, get_args

from pydantic import BaseModel, ConfigDict, Field, model_validator

Region = Literal["US", "IN"]
Emotion = Literal["encouraging", "happy", "calm", "neutral", "celebrating"]
MessageType = Literal["briefing", "reply", "nudge", "reflection_prompt", "weekly_review"]
SafetyStatus = Literal["approved", "fallback", "safety_template"]
SafetyCategory = Literal[
    "emergency", "crisis", "disordered_eating", "medication", "pregnancy_complex"
]
Route = Literal["coach", "fallback", "safety_template"]
#: The Coach Agent's five modes (spec 9.3, T-AGT-04). Each has its own prompt
#: in the registry (`coach_<mode>`), its own fixed fallback and actions.
CoachMode = Literal["briefing", "reply", "nudge", "reflection", "weekly_review"]
#: What stood in the way, as the reflection mode reads it (FR-DLY-05). A
#: proposal only: code (the nightly plan builder) decides what to change.
Barrier = Literal[
    "none", "time", "energy", "motivation", "schedule", "weather", "social", "unwell", "other"
]
TimeOfDay = Literal["morning", "midday", "evening"]
Trend = Literal["up", "steady", "down", "unknown"]


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
    #: Saved memory facts (T-AGT-05): only facts the person saved, only with
    #: the memory consent; filled per request, used by reply and reflection.
    memory: tuple[str, ...] = Field(default=(), max_length=20)

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
        for i, fact in enumerate(self.memory):
            out[f"memory.{i}"] = fact
        return out


# ---------------------------------------------------------------- model output


class CoachDraft(_Strict):
    """The only thing the model writes. Everything else in a CoachMessage
    (ids, actions, safety, versions) is filled in by code."""

    text: str = Field(min_length=1, max_length=2000)
    emotion: Emotion
    #: Passages the text relies on (reply mode). Code checks every id was
    #: actually provided, and that a health claim cites at least one.
    source_ids: tuple[str, ...] = ()
    #: Reflection mode only: what got in the way, as a fixed code.
    barrier: Barrier | None = None


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

_BARRIERS = list(get_args(Barrier))


def draft_json_schema(*, sources: bool = False, barrier: bool = False) -> dict[str, object]:
    """The structured-output schema for a mode: text + emotion, plus
    `source_ids` for a grounded mode and `barrier` for the reflection mode."""
    props: dict[str, object] = {
        "text": {"type": "string"},
        "emotion": {"type": "string", "enum": list(get_args(Emotion))},
    }
    required = ["text", "emotion"]
    if sources:
        props["source_ids"] = {"type": "array", "items": {"type": "string"}}
        required.append("source_ids")
    if barrier:
        props["barrier"] = {"type": "string", "enum": list(_BARRIERS)}
        required.append("barrier")
    return {
        "type": "object",
        "properties": props,
        "required": required,
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


class CoachResponse(_Strict):
    """What every Coach Agent endpoint returns."""

    route: Route
    #: "neutral_device" for safety templates (FR-VOC-07); otherwise the app
    #: asks the voice gateway with message_id (closed-script rule).
    voice: Literal["neutral_device", "gateway"]
    message: CoachMessage
    #: Reflection mode, coach route only: a proposal for the plan builder.
    barrier: Barrier | None = None


#: The morning briefing's response (T-AGT-01 name, kept for callers).
BriefingResponse = CoachResponse


class ConversationTurnRequest(_Strict):
    """POST /v1/conversation/turn (spec 9.4, 12.1). Text only in this slice;
    `audio_ref` (speech-to-text) comes with T-CNV-01."""

    text: str = Field(min_length=1, max_length=1000)
    session_id: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
    local_date: date | None = None


class ReflectionRequest(_Strict):
    """POST /v1/reflections (spec 12.1, FR-DLY-05): the evening answer. The
    app keeps saving it at users/{uid}/reflections/{date}; this returns the
    Coach's reply and stores nothing."""

    text: str = Field(min_length=1, max_length=500)
    prompt: Literal["went_well"] = "went_well"
    local_date: date | None = None


class NudgeRequest(_Strict):
    """POST /v1/nudges/copy: the words of one anchored nudge (FR-DLY-04,
    FR-TCH-02). The scheduler (T-DLY-04) decides IF and WHEN, within the caps
    and quiet hours; this only writes the copy."""

    time_of_day: TimeOfDay
    local_date: date | None = None


class WeeklyStats(_Strict):
    """Computed by code: the Insights Agent (T-AGT-06, D-104;
    livewell_agents/insights/stats.py has the definitions). Counts and trend
    codes only."""

    week_start: date
    days_checked_in: int = Field(ge=0, le=7)
    habit_days_done: int = Field(ge=0, le=7)
    habit_days_planned: int = Field(ge=0, le=7)
    streak_days: int = Field(ge=0, le=10_000)
    restarts: int = Field(default=0, ge=0, le=7)
    mood_trend: Trend = "unknown"
    energy_trend: Trend = "unknown"
    stress_trend: Trend = "unknown"


class WeeklyReviewRequest(_Strict):
    """POST /v1/reviews/weekly (FR-DLY-06; spec 9.7 Sunday job). Without
    `stats` the Insights Agent computes them for the week before
    `local_date`, which is then required (the time zone is never guessed)."""

    stats: WeeklyStats | None = None
    local_date: date | None = None

    @model_validator(mode="after")
    def _stats_or_date(self) -> WeeklyReviewRequest:
        if self.stats is None and self.local_date is None:
            raise ValueError("send stats, or local_date for the Insights Agent")
        return self
