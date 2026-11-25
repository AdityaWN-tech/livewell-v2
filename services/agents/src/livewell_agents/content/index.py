"""The vector index of approved content (T-AGT-03, D-94).

`VectorIndex` is the interface; `LocalVectorIndex` is the dev/test/CI store
(in memory, saved as a JSON file, brute-force cosine; fine for a few thousand
chunks). PRODUCTION ADAPTER POINT: the production store is an open question
(D-94; spec 8.3 lists Firestore vector search, Vertex AI Vector Search,
pgvector, Pinecone). Any store must keep the two guarantees below.

Guarantees (defence in depth, layer 2 of 3; ingestion is layer 1 and the
retriever's live status check is layer 3):
1. `upsert` refuses any chunk that is not approved or is already expired.
2. `query` only ever returns approved, unexpired chunks for an allowed
   region and locale, whatever the caller passes.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Protocol

from livewell_agents.content.embedding import Vector, cosine
from livewell_agents.content.models import APPROVED, Chunk


class UnapprovedContentError(ValueError):
    """Something tried to put unapproved or expired content in the index."""


class EmbedderMismatchError(RuntimeError):
    """Vectors from a different embedding model than the index holds."""


@dataclass(frozen=True)
class QueryFilter:
    today: date
    #: The person's region; None = unknown, so only region "all" items.
    region: str | None = None
    locale: str = "en"


@dataclass(frozen=True)
class Hit:
    chunk: Chunk
    score: float


def allowed(chunk: Chunk, flt: QueryFilter) -> bool:
    """The index-level rule every store applies on every query."""
    if chunk.review_status != APPROVED:
        return False
    if chunk.review_expires_at is not None and flt.today > chunk.review_expires_at:
        return False
    if chunk.region != "all" and chunk.region != flt.region:
        return False
    # "en" content serves "en-US" and "en-IN"; "en-IN" content only "en-IN".
    return flt.locale == chunk.locale or flt.locale.split("-")[0] == chunk.locale


class VectorIndex(Protocol):
    @property
    def model_id(self) -> str: ...

    def upsert(self, chunks: Sequence[Chunk], vectors: Sequence[Vector], today: date) -> None: ...

    def delete_source(self, source_id: str) -> int: ...

    def indexed_versions(self) -> dict[str, int]: ...

    def query(self, vector: Vector, k: int, flt: QueryFilter) -> list[Hit]: ...


class LocalVectorIndex:
    """In-memory store with optional JSON persistence (dev, tests, CI)."""

    def __init__(self, model_id: str) -> None:
        self._model_id = model_id
        self._rows: dict[str, tuple[Chunk, Vector]] = {}

    @property
    def model_id(self) -> str:
        return self._model_id

    def __len__(self) -> int:
        return len(self._rows)

    def upsert(self, chunks: Sequence[Chunk], vectors: Sequence[Vector], today: date) -> None:
        if len(chunks) != len(vectors):
            raise ValueError("one vector per chunk")
        for chunk in chunks:
            expired = chunk.review_expires_at is not None and today > chunk.review_expires_at
            if chunk.review_status != APPROVED or expired:
                raise UnapprovedContentError(f"{chunk.chunk_id} is not approved")
        for chunk, vector in zip(chunks, vectors, strict=True):
            self._rows[chunk.chunk_id] = (chunk, list(vector))

    def delete_source(self, source_id: str) -> int:
        gone = [cid for cid, (c, _) in self._rows.items() if c.source_id == source_id]
        for cid in gone:
            del self._rows[cid]
        return len(gone)

    def indexed_versions(self) -> dict[str, int]:
        return {c.source_id: c.version for c, _ in self._rows.values()}

    def query(self, vector: Vector, k: int, flt: QueryFilter) -> list[Hit]:
        hits = [
            Hit(chunk, cosine(vector, vec))
            for chunk, vec in self._rows.values()
            if allowed(chunk, flt)
        ]
        hits.sort(key=lambda h: (-h.score, h.chunk.chunk_id))
        return hits[:k]

    def save(self, path: Path) -> None:
        rows = [
            {"chunk": c.model_dump(mode="json"), "vector": [round(x, 6) for x in v]}
            for c, v in sorted(self._rows.values(), key=lambda r: r[0].chunk_id)
        ]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"model_id": self._model_id, "rows": rows}), encoding="utf-8")

    @classmethod
    def load(cls, path: Path, model_id: str, today: date) -> LocalVectorIndex:
        """Loads a saved index. A file built by another model, or holding an
        unapproved row (edited by hand), is refused; rows that expired since
        the build are dropped."""
        data = json.loads(path.read_text(encoding="utf-8"))
        if data["model_id"] != model_id:
            raise EmbedderMismatchError("index was built with another embedder; rebuild it")
        index = cls(model_id)
        rows = [(Chunk.model_validate(r["chunk"]), r["vector"]) for r in data["rows"]]
        live = [
            (c, v) for c, v in rows if c.review_expires_at is None or today <= c.review_expires_at
        ]
        index.upsert([c for c, _ in live], [v for _, v in live], today)
        return index
