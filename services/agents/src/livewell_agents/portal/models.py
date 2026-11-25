"""Portal Agent data (spec 13.2-13.4; T-AGT-07, D-105). Offers follow the
`portal_offers` schema of T-PRT-02 (D-92). Ids, tags, counts and times only:
nothing a person typed is read."""

from __future__ import annotations

from datetime import date, datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

#: Driver and topic tags as T-PRT-02 stores them (`a-z0-9_`).
Tag = Annotated[str, StringConstraints(pattern=r"^[a-z0-9_]{1,40}$")]

#: Where a card could be asked for. Only ALLOWED_SURFACES may show one (13.3);
#: the others exist so a caller asking for them gets a clear "no".
Surface = Literal[
    "evening_reflection",
    "weekly_review",
    "lesson_end",
    "milestone",
    "user_question",
    "morning_briefing",
    "nudge",
    "safety_message",
]
ALLOWED_SURFACES: frozenset[str] = frozenset(
    {"evening_reflection", "weekly_review", "lesson_end", "milestone", "user_question"}
)

OfferType = Literal["course", "program", "free_lesson", "coaching"]
PortalEventType = Literal["card_shown", "clicked", "dismissed", "order", "progress", "completed"]
#: Webhook events that mean the person already bought or enrolled.
OWNED_EVENTS: frozenset[str] = frozenset({"order", "progress", "completed"})


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class PortalOffer(_Strict):
    """portal_offers/{id}: only `active && review_status == approved` ever
    reach here. Title, description, URL and price are shown exactly as the
    admin entered them; no model ever writes them."""

    offer_id: str = Field(min_length=1, max_length=128)
    title: str = Field(min_length=3, max_length=80)
    description: str | None = Field(default=None, max_length=240)
    url: str = Field(min_length=8, max_length=500, pattern=r"^https://")
    offer_type: OfferType
    driver_tags: tuple[Tag, ...] = Field(default=(), max_length=8)
    topic_tags: tuple[Tag, ...] = Field(default=(), max_length=8)
    price_display: str | None = Field(default=None, max_length=24)

    @property
    def tags(self) -> frozenset[str]:
        return frozenset(self.driver_tags) | frozenset(self.topic_tags)


class PortalEvent(_Strict):
    """users/{uid}/portal_events/{id}: what happened with a card or an offer."""

    event: PortalEventType
    offer_id: str = Field(min_length=1, max_length=128)
    at: datetime


class PortalState(_Strict):
    """What step 1 and step 2 need to know about the person now."""

    #: users/{uid}.age_confirmed (18+, FR-ONB-01). False or unknown: no card.
    age_confirmed: bool = False
    #: Unknown counts as a new account (no card in the first 48 hours).
    account_created_at: datetime | None = None
    ed_safe_mode: bool = False
    #: Today's check-in asked for a gentle day (T-DLY-02): no offers today.
    gentle_day: bool = False
    #: Whether safety events are recorded where this state was read. While
    #: they aren't (D-22), "no event in 72 hours" can't be known: no card.
    safety_known: bool = False
    last_safety_event_at: datetime | None = None
    events: tuple[PortalEvent, ...] = Field(default=(), max_length=1000)
    focus_driver: str | None = Field(default=None, max_length=40)
    #: Topic tags of lessons finished lately (step 2 "recent topics").
    recent_topics: tuple[Tag, ...] = Field(default=(), max_length=20)
    streak_days: int = Field(default=0, ge=0, le=10_000)
    checkin_days_7: int = Field(default=0, ge=0, le=7)
    lessons_completed: int = Field(default=0, ge=0, le=10_000)


class PortalRecommendRequest(_Strict):
    """POST /v1/portal/recommend."""

    surface: Surface
    local_date: date
    #: Covered topics the person asked about just now (step 2 "intent"), as
    #: tags from the caller's classifier; never the question's text.
    asked_topics: tuple[Tag, ...] = Field(default=(), max_length=8)


class PortalCard(_Strict):
    """What the app shows (13.4). Everything except `bridge_line` is copied
    from the approved offer; the label and the Not now button are fixed."""

    offer_id: str
    title: str
    description: str | None
    offer_type: OfferType
    label: Literal["From the Live Well Portal"] = "From the Live Well Portal"
    #: "Free", the CMS price exactly as entered, or "Paid course".
    price_label: str
    #: Offer URL plus attribution ids only (13.2); never health data.
    url: str
    click_id: str
    surface: Surface
    #: The coach's 1-2 sentence lead-in, or None (then the app shows the card
    #: without one). Grounded only in the title and description.
    bridge_line: str | None = None
    score: float = Field(ge=0, le=1)


class PortalRecommendResponse(_Strict):
    card: PortalCard | None = None
    #: "ok", or the first reason there is no card (a fixed code).
    reason: str
