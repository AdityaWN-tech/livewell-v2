"""Where content items and their current review status come from (T-AGT-03).

`ContentCatalog` reads items from JSON files (one item per file, or a file
with an `items` list): `content/lessons/`, `content/book/` (licensed book
excerpts are never committed, A-10) or the synthetic fixtures. In production
the source of truth is Firestore `content_items` (written by Admin); a
Firestore-backed `StatusLookup` is the adapter point for that (D-94).
"""

from __future__ import annotations

import json
from collections.abc import Iterable, Iterator
from datetime import date
from pathlib import Path
from typing import Protocol

from livewell_agents.content.models import ContentItem


class StatusLookup(Protocol):
    def approved_version(self, source_id: str, today: date) -> int | None:
        """The version of `source_id` that may be shown today, or None if the
        item is not (or no longer) approved, has expired, or is unknown."""
        ...


class ContentCatalog:
    """Items by id; also the live `StatusLookup` for the retriever."""

    def __init__(self, items: Iterable[ContentItem]) -> None:
        self._items: dict[str, ContentItem] = {}
        for item in items:
            if item.id in self._items:
                raise ValueError(f"duplicate content id {item.id}")
            self._items[item.id] = item

    def __iter__(self) -> Iterator[ContentItem]:
        return iter(self._items.values())

    def __len__(self) -> int:
        return len(self._items)

    def get(self, source_id: str) -> ContentItem | None:
        return self._items.get(source_id)

    def put(self, item: ContentItem) -> None:
        """Replaces an item (a status or version change from review)."""
        self._items[item.id] = item

    def approved_version(self, source_id: str, today: date) -> int | None:
        item = self._items.get(source_id)
        if item is None or not item.is_retrievable(today):
            return None
        return item.version

    @classmethod
    def from_paths(cls, paths: Iterable[Path]) -> ContentCatalog:
        items: list[ContentItem] = []
        for path in paths:
            files = sorted(path.glob("*.json")) if path.is_dir() else [path]
            for file in files:
                data = json.loads(file.read_text(encoding="utf-8"))
                raw = data["items"] if isinstance(data, dict) and "items" in data else [data]
                items.extend(ContentItem.model_validate(r) for r in raw)
        return cls(items)
