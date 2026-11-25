"""Content items, chunks and passages (T-AGT-03, D-94).

A `ContentItem` mirrors a `content_items/{id}` document (docs/data-model.md):
the fields the Learn reader already uses (D-57) plus the retrieval metadata
(driver/pillar tags, locale, region, review expiry). Only items whose
`review_status` is `approved` (and not past `review_expires_at`) are ever
chunked, indexed or returned (spec 9.1 rule 4, 9.3 Content Agent, 11).
"""

from __future__ import annotations

import hashlib
import re
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

ReviewStatus = Literal["draft", "pending", "approved", "retired", "rejected"]
ContentType = Literal["lesson", "book", "audio"]
#: Region an item is written for. "all" = safe for every market. An item for
#: one market is returned only when the person's region is known (D-03:
#: never guess a region).
Region = Literal["all", "IN", "US"]

APPROVED: ReviewStatus = "approved"
#: Types that carry text worth retrieving. Audio sessions (breathing) have no
#: text body and are never indexed.
INDEXED_TYPES: frozenset[str] = frozenset({"lesson", "book"})

_SLUG = r"^[a-z0-9][a-z0-9_-]{0,79}$"


class Microhabit(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str = Field(min_length=1, max_length=120)
    minutes: int = Field(ge=1, le=30)


class ContentItem(BaseModel):
    """One `content_items` document as the ingestion pipeline reads it."""

    model_config = ConfigDict(extra="forbid")

    id: str = Field(pattern=_SLUG)
    type: ContentType
    title: str = Field(min_length=1, max_length=120)
    review_status: ReviewStatus
    version: int = Field(ge=1)
    driver_tags: list[str] = Field(min_length=1)
    pillar_tags: list[str] = Field(default_factory=list)
    locale: str = Field(default="en", pattern=r"^[a-z]{2}(-[A-Z]{2})?$")
    region: Region = "all"
    category: str | None = None
    summary: str | None = None
    read_minutes: int | None = Field(default=None, ge=1, le=30)
    art_id: str | None = None
    #: Lesson body: short paragraphs read one at a time (D-57).
    cards: list[str] = Field(default_factory=list)
    microhabit: Microhabit | None = None
    #: Book body: paragraphs of a licensed excerpt (A-10). Never in the repo.
    sections: list[str] = Field(default_factory=list)
    #: Where a book excerpt comes from (e.g. "book:ch03"); ids only.
    source_ref: str | None = None
    breathing: str | None = None
    reviewed_by: str | None = None
    reviewed_at: date | None = None
    #: After this day the item counts as expired and is never returned.
    review_expires_at: date | None = None

    @model_validator(mode="after")
    def _check(self) -> ContentItem:
        for tag in (*self.driver_tags, *self.pillar_tags):
            if not _is_slug(tag):
                raise ValueError(f"tag {tag!r} must be a lowercase slug")
        if self.type == "lesson" and not self.cards:
            raise ValueError("a lesson needs cards")
        if self.type == "book" and not self.sections:
            raise ValueError("a book item needs sections")
        if self.review_status == APPROVED and not (self.reviewed_by and self.reviewed_at):
            raise ValueError("an approved item records reviewed_by and reviewed_at")
        return self

    def is_retrievable(self, today: date) -> bool:
        """Approved, of an indexed type, and not past its review expiry."""
        if self.review_status != APPROVED or self.type not in INDEXED_TYPES:
            return False
        return self.review_expires_at is None or today <= self.review_expires_at


def _is_slug(value: str) -> bool:
    return re.fullmatch(_SLUG, value) is not None


def text_sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class Chunk(BaseModel):
    """One retrievable passage with the metadata the index filters on."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    chunk_id: str
    source_id: str
    type: ContentType
    title: str
    ordinal: int = Field(ge=0)
    text: str = Field(min_length=1)
    text_sha256: str
    driver_tags: tuple[str, ...]
    pillar_tags: tuple[str, ...] = ()
    version: int = Field(ge=1)
    review_status: ReviewStatus
    locale: str
    region: Region
    source_ref: str | None = None
    review_expires_at: date | None = None


class Passage(BaseModel):
    """What `ContentRetriever.retrieve` returns to the Coach (spec 9.4 step 5)."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    source_id: str
    chunk_id: str
    version: int
    type: ContentType
    title: str
    text: str
    driver_tags: tuple[str, ...]
    score: float
