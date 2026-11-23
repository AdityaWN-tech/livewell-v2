"""The Portal Agent (spec 9.3, 13.3, 13.4; T-AGT-07, D-105).

    recommend  one card or none for a surface; deterministic eligibility
               (step 1) and relevance (step 2) in plain code; a model only
               writes the optional bridge line, from the offer's own words

It never: exceeds the caps, recommends in or within 72 hours of a safety
event (or while that can't be known), presents an offer as medical advice,
or shows an offer that is not in the approved catalog: the card's title,
description, URL and price are copied from the catalog, never generated.
Read only: the app records card_shown, clicked and dismissed itself.
Logs and spans: ids, codes and the score only.
"""

from __future__ import annotations

import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from fractions import Fraction
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from livewell_agents.portal.bridge import BridgeWriter
from livewell_agents.portal.models import (
    PortalCard,
    PortalOffer,
    PortalRecommendRequest,
    PortalRecommendResponse,
)
from livewell_agents.portal.policy import DEFAULT_THRESHOLD, Gate, gate_block, pick, state_block
from livewell_agents.portal.store import PortalSource
from livewell_agents.tracing import set_attrs, span

log = logging.getLogger("livewell_agents.portal")

#: Consent types (the app's ConsentType keys). D-26 uses portal_linking.
PORTAL_CONSENT = "portal_linking"
#: Attribution keys the app or the agent add; an offer URL never carries them.
_ATTRIBUTION_KEYS = frozenset({"utm_source", "utm_medium", "utm_campaign", "utm_content", "lw_cid"})


@dataclass(frozen=True)
class PortalConsents:
    portal: bool
    ai: bool


def attribution_url(offer: PortalOffer, surface: str, click_id: str) -> str:
    """Spec 13.2: ids only, never health data."""
    parts = urlsplit(offer.url)
    query = [(k, v) for k, v in parse_qsl(parts.query) if k not in _ATTRIBUTION_KEYS]
    query += [
        ("utm_source", "livewell_app"),
        ("utm_medium", "avatar"),
        ("utm_campaign", surface),
        ("utm_content", offer.offer_id),
        ("lw_cid", click_id),
    ]
    return urlunsplit(parts._replace(query=urlencode(query)))


def price_label(offer: PortalOffer) -> str:
    if offer.offer_type == "free_lesson":
        return "Free"
    return offer.price_display or "Paid course"


class PortalAgent:
    def __init__(
        self,
        *,
        source: PortalSource,
        bridge: BridgeWriter,
        enabled: bool,
        threshold: Fraction = DEFAULT_THRESHOLD,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
        new_id: Callable[[], str] = lambda: uuid.uuid4().hex,
    ) -> None:
        self._source = source
        self._bridge = bridge
        self._enabled = enabled
        self._threshold = threshold
        self._clock = clock
        self._new_id = new_id

    def recommend(
        self, uid: str, request: PortalRecommendRequest, consents: PortalConsents
    ) -> PortalRecommendResponse:
        """Raises PortalUnavailable when no source is configured."""
        with span("portal.recommend", {"lw.uid": uid, "lw.surface": request.surface}) as s:
            out = self._recommend(uid, request, consents)
            set_attrs(
                s,
                {
                    "lw.decision": "card" if out.card else "none",
                    "lw.reason": out.reason,
                    "lw.offer_id": out.card.offer_id if out.card else "",
                },
            )
        log.info(
            "portal.recommend surface=%s reason=%s offer=%s",
            request.surface,
            out.reason,
            out.card.offer_id if out.card else "-",
        )
        return out

    def _recommend(
        self, uid: str, request: PortalRecommendRequest, consents: PortalConsents
    ) -> PortalRecommendResponse:
        now = self._clock()
        gate = Gate(flag_on=self._enabled, portal_consent=consents.portal)
        # Cheap checks first: nothing is read for a surface or flag that says no.
        early = gate_block(request.surface, gate)
        if early is not None:
            return PortalRecommendResponse(reason=early)
        state = self._source.state(uid, request.local_date)
        block = state_block(state, now)
        if block is not None:
            return PortalRecommendResponse(reason=block)
        offers = self._source.offers()
        offer, total, reason = pick(offers, state, request.asked_topics, now, self._threshold)
        if offer is None:
            return PortalRecommendResponse(reason=reason)
        line: str | None = None
        if consents.ai:
            line, _ = self._bridge.write(offer, request.surface, [o.title for o in offers])
        click_id = self._new_id()
        card = PortalCard(
            offer_id=offer.offer_id,
            title=offer.title,
            description=offer.description,
            offer_type=offer.offer_type,
            price_label=price_label(offer),
            url=attribution_url(offer, request.surface, click_id),
            click_id=click_id,
            surface=request.surface,
            bridge_line=line,
            score=round(float(total), 4),
        )
        return PortalRecommendResponse(card=card, reason="ok")
