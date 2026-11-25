"""Spec 13.3, in plain code. Step 1 (eligibility) and step 2 (relevance).

Step 1, any failure = no card. Person-level checks, in this order:
  flag_off, surface_not_allowed, no_portal_consent, not_adult,
  safety_unknown, recent_safety_event, ed_safe_mode, gentle_day, first_48h.
Offer-level checks: already_owned, cooldown, daily_cap, weekly_cap.

Same rules as the app's Learn card (apps/mobile/lib/features/learn/domain/
portal.dart, D-26), with these conservative choices (D-105):
  - ed_safe_mode blocks every offer: topics that are safe in that mode are
    not defined, so none is assumed safe.
  - The day-1 evening free resource is not offered: which resource it is is
    open question Q2, so the first 48 hours have no card at all.
  - The server has no reliable local day for event times, so the daily cap
    is "another offer shown in the last 24 hours" and the weekly cap is "3
    showings in the last 7 days" (the same offer again within 24 hours
    counts once). Both are at least as strict as calendar days.
  - A gentle day (T-DLY-02) also blocks, as in the app.

Step 2: score = 0.40 driver_match + 0.25 readiness + 0.20 intent + 0.15 novelty,
each in [0, 1]; shown only at or above the threshold (0.6 by default).
Exact fractions, so a boundary never depends on float rounding.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from fractions import Fraction

from livewell_agents.portal.models import (
    ALLOWED_SURFACES,
    OWNED_EVENTS,
    PortalEvent,
    PortalOffer,
    PortalState,
)
from livewell_agents.safety.precheck import RECENT_EVENT_WINDOW

FIRST_HOURS = timedelta(hours=48)
DAY = timedelta(hours=24)
WEEK = timedelta(days=7)
COOLDOWN = timedelta(days=14)
MAX_PER_WEEK = 3
DEFAULT_THRESHOLD = Fraction(3, 5)

W_DRIVER = Fraction(40, 100)
W_READINESS = Fraction(25, 100)
W_INTENT = Fraction(20, 100)
W_NOVELTY = Fraction(15, 100)


@dataclass(frozen=True)
class Gate:
    flag_on: bool
    portal_consent: bool


def gate_block(surface: str, gate: Gate) -> str | None:
    """The person-level checks that need no stored data."""
    if not gate.flag_on:
        return "flag_off"
    if surface not in ALLOWED_SURFACES:
        return "surface_not_allowed"
    if not gate.portal_consent:
        return "no_portal_consent"
    return None


def state_block(state: PortalState, now: datetime) -> str | None:
    """The person-level checks on stored data, in order."""
    if not state.age_confirmed:
        return "not_adult"
    if not state.safety_known:
        return "safety_unknown"
    last = state.last_safety_event_at
    if last is not None and now - last < RECENT_EVENT_WINDOW:
        return "recent_safety_event"
    if state.ed_safe_mode:
        return "ed_safe_mode"
    if state.gentle_day:
        return "gentle_day"
    created = state.account_created_at
    if created is None or now - created < FIRST_HOURS:
        return "first_48h"
    return None


def person_block(state: PortalState, surface: str, gate: Gate, now: datetime) -> str | None:
    """The first person-level reason for no card, or None."""
    return gate_block(surface, gate) or state_block(state, now)


def showings(events: Sequence[PortalEvent]) -> list[PortalEvent]:
    """card_shown events, oldest first; the same offer shown again within 24
    hours of its counted showing is the same showing."""
    out: list[PortalEvent] = []
    last_counted: dict[str, datetime] = {}
    for e in sorted((e for e in events if e.event == "card_shown"), key=lambda e: e.at):
        prev = last_counted.get(e.offer_id)
        if prev is not None and e.at - prev < DAY:
            continue
        last_counted[e.offer_id] = e.at
        out.append(e)
    return out


def offer_block(
    offer: PortalOffer,
    state: PortalState,
    catalog: dict[str, PortalOffer],
    now: datetime,
) -> str | None:
    """The first offer-level reason this offer can't be shown, or None."""
    events = state.events
    if any(e.offer_id == offer.offer_id and e.event in OWNED_EVENTS for e in events):
        return "already_owned"
    for e in events:
        if e.event != "dismissed" or now - e.at >= COOLDOWN:
            continue
        other = catalog.get(e.offer_id)
        if e.offer_id == offer.offer_id or (
            other is not None and set(other.topic_tags) & set(offer.topic_tags)
        ):
            return "cooldown"
    shown = showings(events)
    recent = [e for e in shown if now - e.at < DAY]
    if any(e.offer_id != offer.offer_id for e in recent):
        return "daily_cap"
    if not recent and sum(1 for e in shown if now - e.at < WEEK) >= MAX_PER_WEEK:
        return "weekly_cap"
    return None


# ------------------------------------------------------------ step 2


@dataclass(frozen=True)
class Score:
    driver_match: Fraction
    readiness: Fraction
    intent: Fraction
    novelty: Fraction

    @property
    def total(self) -> Fraction:
        return (
            W_DRIVER * self.driver_match
            + W_READINESS * self.readiness
            + W_INTENT * self.intent
            + W_NOVELTY * self.novelty
        )


def _capped(value: int, full: int) -> Fraction:
    return min(Fraction(value, full), Fraction(1))


def score(
    offer: PortalOffer, state: PortalState, asked_topics: Sequence[str], now: datetime
) -> Score:
    """driver_match: 1 if the focus driver is one of the offer's driver tags,
      1/2 if a recent lesson topic matches any offer tag, else 0.
    readiness: mean of streak/7, check-in days/5 and lessons/3, each capped at 1.
    intent: 1 if the person just asked about a topic the offer covers, else 0.
    novelty: 1 if never shown, 1/2 if last shown 14+ days ago, else 0."""
    tags = offer.tags
    if state.focus_driver is not None and state.focus_driver in offer.driver_tags:
        driver = Fraction(1)
    elif tags & set(state.recent_topics):
        driver = Fraction(1, 2)
    else:
        driver = Fraction(0)
    readiness = (
        _capped(state.streak_days, 7)
        + _capped(state.checkin_days_7, 5)
        + _capped(state.lessons_completed, 3)
    ) / 3
    intent = Fraction(1) if tags & set(asked_topics) else Fraction(0)
    shown = [e.at for e in state.events if e.event == "card_shown" and e.offer_id == offer.offer_id]
    if not shown:
        novelty = Fraction(1)
    elif now - max(shown) >= COOLDOWN:
        novelty = Fraction(1, 2)
    else:
        novelty = Fraction(0)
    return Score(driver, readiness, intent, novelty)


def pick(
    offers: Sequence[PortalOffer],
    state: PortalState,
    asked_topics: Sequence[str],
    now: datetime,
    threshold: Fraction = DEFAULT_THRESHOLD,
) -> tuple[PortalOffer | None, Fraction, str]:
    """The highest-scoring eligible offer at or above the threshold (ties:
    the smaller offer id, so the result never depends on order)."""
    if not offers:
        return None, Fraction(0), "no_offers"
    catalog = {o.offer_id: o for o in offers}
    candidates: list[tuple[Fraction, str]] = []
    first_block: str | None = None
    for o in offers:
        block = offer_block(o, state, catalog, now)
        if block is None:
            total = score(o, state, asked_topics, now).total
            if total >= threshold:
                candidates.append((total, o.offer_id))
                continue
            block = "below_threshold"
        first_block = first_block or block
    if not candidates:
        return None, Fraction(0), first_block or "below_threshold"
    total, offer_id = min(candidates, key=lambda c: (-c[0], c[1]))
    return catalog[offer_id], total, "ok"
