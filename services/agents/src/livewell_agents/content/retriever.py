"""Content.retrieve(query, driver_tags) -> passages with source ids (spec 9.4).

Layer 3 of the approved-only rule: after the index (which already filters on
approved), every candidate is checked against the live review status
(`StatusLookup`). A chunk is dropped if its item is no longer approved, has
expired, or the approved version is not the chunk's version. So an item
retired or sent back to review is never returned, even before the index is
re-synced. If the status lookup fails, nothing is returned (fail closed).

Never logs the query or passage text: ids, counts and scores only.
"""

from __future__ import annotations

import logging
from collections.abc import Callable, Sequence
from datetime import date

from livewell_agents.content.catalog import StatusLookup
from livewell_agents.content.embedding import Embedder
from livewell_agents.content.index import EmbedderMismatchError, Hit, QueryFilter, VectorIndex
from livewell_agents.content.models import Passage

log = logging.getLogger(__name__)

#: Below this cosine a passage is not about the question; returning nothing
#: is better than returning noise (the Coach then states no health facts).
MIN_SCORE = 0.08
#: Added when a passage shares a driver tag with the request.
DRIVER_BOOST = 0.1
#: Share of a chunk's score taken from the best chunk of the same item.
SOURCE_WEIGHT = 0.5
#: Candidates fetched per requested passage (room for the live-status filter).
OVERFETCH = 8


class ContentRetriever:
    def __init__(
        self,
        index: VectorIndex,
        embedder: Embedder,
        status: StatusLookup,
        clock: Callable[[], date] = date.today,
        min_score: float = MIN_SCORE,
    ) -> None:
        if index.model_id != embedder.model_id:
            raise EmbedderMismatchError("index and embedder disagree; rebuild the index")
        self._index = index
        self._embedder = embedder
        self._status = status
        self._clock = clock
        self._min_score = min_score

    def retrieve(
        self,
        query: str,
        driver_tags: Sequence[str] = (),
        k: int = 5,
        region: str | None = None,
        locale: str = "en",
    ) -> list[Passage]:
        if k < 1 or not query.strip():
            return []
        today = self._clock()
        flt = QueryFilter(today=today, region=region, locale=locale)
        [vector] = self._embedder.embed([query])
        hits = self._index.query(vector, k * OVERFETCH, flt)
        try:
            live = [h for h in hits if self._still_approved(h, today)]
        except Exception:
            log.warning("content.retrieve status_lookup_failed candidates=%d", len(hits))
            return []
        wanted = set(driver_tags)
        best: dict[str, float] = {}
        for h in live:
            best[h.chunk.source_id] = max(best.get(h.chunk.source_id, 0.0), h.score)

        def final(h: Hit) -> float:
            # A card of a lesson that clearly answers the question counts for
            # more than a stray card that shares a word with it.
            score = (1 - SOURCE_WEIGHT) * h.score + SOURCE_WEIGHT * best[h.chunk.source_id]
            return score + (DRIVER_BOOST if wanted.intersection(h.chunk.driver_tags) else 0.0)

        scored = sorted(
            ((final(h), h) for h in live if h.score >= self._min_score),
            key=lambda pair: (-pair[0], pair[1].chunk.chunk_id),
        )[:k]
        passages = [
            Passage(
                source_id=h.chunk.source_id,
                chunk_id=h.chunk.chunk_id,
                version=h.chunk.version,
                type=h.chunk.type,
                title=h.chunk.title,
                text=h.chunk.text,
                driver_tags=h.chunk.driver_tags,
                score=round(score, 4),
            )
            for score, h in scored
        ]
        log.info(
            "content.retrieve candidates=%d dropped_by_status=%d returned=%d sources=%s",
            len(hits),
            len(hits) - len(live),
            len(passages),
            sorted({p.source_id for p in passages}),
        )
        return passages

    def _still_approved(self, hit: Hit, today: date) -> bool:
        return self._status.approved_version(hit.chunk.source_id, today) == hit.chunk.version
