"""Where the Portal Agent reads the catalog and the person's state (spec 9.3
tools get_portal_catalog, get_portal_history). `PortalSource` is the port;
`FirestorePortalSource` (firebase_store.py) is the real one. Until it is
wired the service refuses (`NotConfiguredPortalSource`).

Parsers return None for a malformed document: it is skipped, never guessed.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any, Protocol

from pydantic import ValidationError

from livewell_agents.portal.models import PortalEvent, PortalOffer, PortalState


class PortalUnavailable(RuntimeError):
    pass


class PortalSource(Protocol):
    def offers(self) -> list[PortalOffer]:
        """Active and approved offers only."""
        ...

    def state(self, uid: str, local_date: date) -> PortalState: ...


class NotConfiguredPortalSource:
    def offers(self) -> list[PortalOffer]:
        raise PortalUnavailable("portal source is not configured")

    def state(self, uid: str, local_date: date) -> PortalState:
        raise PortalUnavailable("portal source is not configured")


@dataclass
class InMemoryPortalSource:
    catalog: list[PortalOffer] = field(default_factory=list)
    states: dict[str, PortalState] = field(default_factory=dict)

    def offers(self) -> list[PortalOffer]:
        return list(self.catalog)

    def state(self, uid: str, local_date: date) -> PortalState:
        return self.states.get(uid, PortalState())


def offer_from(doc_id: str, raw: dict[str, Any]) -> PortalOffer | None:
    """Only a live offer (`active` true and `review_status` approved)."""
    if raw.get("active") is not True or raw.get("review_status") != "approved":
        return None
    price = raw.get("price_display") or None
    driver_tags, topic_tags = raw.get("driver_tags", []), raw.get("topic_tags", [])
    if not isinstance(driver_tags, list) or not isinstance(topic_tags, list):
        return None
    try:
        return PortalOffer.model_validate(
            {
                "offer_id": doc_id,
                "title": raw.get("title"),
                "description": raw.get("description") or None,
                "url": raw.get("url"),
                "offer_type": raw.get("offer_type"),
                "driver_tags": tuple(driver_tags),
                "topic_tags": tuple(topic_tags),
                "price_display": price,
            },
            strict=True,
        )
    except ValidationError:
        return None


def event_from(raw: dict[str, Any]) -> PortalEvent | None:
    at = raw.get("created_at")
    if not isinstance(at, datetime):
        return None
    try:
        return PortalEvent.model_validate(
            {"event": raw.get("event"), "offer_id": raw.get("offer_id"), "at": at}, strict=True
        )
    except ValidationError:
        return None
