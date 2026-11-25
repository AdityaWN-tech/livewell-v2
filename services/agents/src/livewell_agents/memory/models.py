"""Memory facts (spec 9.8, 10.4 users/{uid}/memory_facts; FR-CNV-05; T-AGT-05).

The model only ever writes `MemoryDraft` (a few short candidate facts). Code
decides which become proposals, and only the person turns a proposal into a
saved fact (spec 9.1 rule 3: agents propose; users or code decide).
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal, get_args

from pydantic import BaseModel, ConfigDict, Field

#: What a fact is about. The last three are sensitive (spec 9.3 Memory Agent
#: "never store sensitive categories (medications, diagnoses, mental health)
#: without explicit opt-in"): stored only with the `memory_sensitive` consent.
MemoryCategory = Literal[
    "preference",
    "routine",
    "barrier",
    "win",
    "goal",
    "physical",
    "medication",
    "diagnosis",
    "mental_health",
]
SENSITIVE_CATEGORIES: frozenset[str] = frozenset({"medication", "diagnosis", "mental_health"})
MemoryStatus = Literal["proposed", "saved", "deleted"]
#: Where the fact came from (spec 9.3: after conversations and reflections).
MemorySource = Literal["conversation", "reflection"]

#: Longest fact kept. Facts are short ("prefers walking after dinner").
MAX_FACT_CHARS = 120
MIN_FACT_CHARS = 4
#: Candidates the model may return per run; more are ignored.
MAX_DRAFT_FACTS = 3


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class FactDraft(_Strict):
    fact: str = Field(min_length=1, max_length=400)
    category: MemoryCategory
    confidence: float = Field(ge=0.0, le=1.0)


class MemoryDraft(_Strict):
    """The only thing the model writes."""

    facts: tuple[FactDraft, ...] = Field(default=(), max_length=10)


MEMORY_DRAFT_JSON_SCHEMA: dict[str, object] = {
    "type": "object",
    "properties": {
        "facts": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "fact": {"type": "string"},
                    "category": {"type": "string", "enum": list(get_args(MemoryCategory))},
                    "confidence": {"type": "number"},
                },
                "required": ["fact", "category", "confidence"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["facts"],
    "additionalProperties": False,
}


class MemoryFact(_Strict):
    """One users/{uid}/memory_facts/{fact_id} document (docs/data-model.md)."""

    fact_id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,64}$")
    #: Empty once deleted: the text is scrubbed and only `fact_key` stays, so
    #: the same fact is never proposed again (FR-CNV-05).
    fact: str = Field(max_length=MAX_FACT_CHARS)
    category: MemoryCategory
    sensitive: bool
    confidence: float = Field(ge=0.0, le=1.0)
    source: MemorySource
    source_message_id: str = Field(max_length=128)
    status: MemoryStatus
    #: sha256 of uid + normalised fact text (policy.fact_key).
    fact_key: str = Field(pattern=r"^[0-9a-f]{64}$")
    prompt_version: str
    created_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------- HTTP


class MemoryFactView(_Strict):
    """What the app shows in "What my coach remembers"."""

    fact_id: str
    fact: str
    category: MemoryCategory
    sensitive: bool
    status: Literal["proposed", "saved"]
    source: MemorySource
    created_at: datetime

    @classmethod
    def of(cls, f: MemoryFact) -> MemoryFactView:
        assert f.status != "deleted"
        return cls(
            fact_id=f.fact_id,
            fact=f.fact,
            category=f.category,
            sensitive=f.sensitive,
            status=f.status,
            source=f.source,
            created_at=f.created_at,
        )


class MemoryListResponse(_Strict):
    facts: list[MemoryFactView]
    #: The `memory` consent: off = nothing new is proposed and the coach uses
    #: no fact. The list stays visible so facts can still be deleted.
    memory_on: bool
    #: The `memory_sensitive` consent (medications, diagnoses, mental health).
    sensitive_on: bool


class MemoryProposeRequest(_Strict):
    """POST /v1/memory/propose: run after a conversation turn or a reflection
    (spec 9.3 'after conversations and reflections (asynchronous)')."""

    text: str = Field(min_length=1, max_length=1000)
    source: MemorySource
    source_message_id: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
    local_date: date | None = None


ProposeStatus = Literal["proposed", "nothing", "skipped"]


class MemoryProposeResponse(_Strict):
    status: ProposeStatus
    #: A short code (memory_off, red_flag, model_failed, ...); never text.
    reason: str
    facts: list[MemoryFactView] = Field(default_factory=list)
