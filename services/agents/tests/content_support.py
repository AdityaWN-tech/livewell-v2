"""Shared helpers for the content tests and the retrieval eval (synthetic only)."""

from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import Any

from livewell_agents.config import SERVICE_DIR
from livewell_agents.content import (
    ContentCatalog,
    ContentItem,
    ContentRetriever,
    HashingEmbedder,
    LocalVectorIndex,
    ingest,
)

CORPUS = SERVICE_DIR / "fixtures" / "content" / "synthetic_corpus.json"
TODAY = date(2026, 11, 21)
#: Ids in the corpus that must never be retrieved (on-topic distractors).
NEVER = ("pending_sleep_secrets", "retired_walking_plan", "rejected_stress_cure",
         "draft_energy_tips", "expired_vegetables")  # fmt: skip


class Clock:
    def __init__(self, today: date = TODAY) -> None:
        self.today = today

    def __call__(self) -> date:
        return self.today


def build(
    path: Path = CORPUS, today: date = TODAY
) -> tuple[ContentCatalog, LocalVectorIndex, ContentRetriever, Clock]:
    catalog = ContentCatalog.from_paths([path])
    embedder = HashingEmbedder()
    index = LocalVectorIndex(embedder.model_id)
    ingest(catalog, embedder, index, today)
    clock = Clock(today)
    return catalog, index, ContentRetriever(index, embedder, catalog, clock=clock), clock


def with_status(item: ContentItem, **update: Any) -> ContentItem:
    return ContentItem.model_validate({**item.model_dump(), **update})
