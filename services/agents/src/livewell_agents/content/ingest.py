"""Ingestion: catalog -> approved chunks -> vectors -> index (T-AGT-03, D-94).

Layer 1 of the approved-only rule: an item is chunked and embedded only if it
is approved and not expired today. Every run is a full sync, so an item that
was approved and is now pending, retired, rejected, expired or deleted is
removed from the index, and a new approved version replaces the old one.

Logs ids and counts only, never content text.

CLI (dev): build a local index file from content folders, e.g.
    python -m livewell_agents.content.ingest ../../content/lessons --out .index/content.json
"""

from __future__ import annotations

import argparse
import logging
from collections import Counter
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

from livewell_agents.content.catalog import ContentCatalog
from livewell_agents.content.chunking import chunk_item, embedding_text
from livewell_agents.content.embedding import Embedder, make_embedder
from livewell_agents.content.index import EmbedderMismatchError, LocalVectorIndex, VectorIndex
from livewell_agents.content.models import INDEXED_TYPES

log = logging.getLogger(__name__)


@dataclass
class IngestReport:
    indexed: list[str] = field(default_factory=list)
    unchanged: list[str] = field(default_factory=list)
    removed: list[str] = field(default_factory=list)
    #: reason -> count (not_approved, expired, not_text)
    skipped: Counter[str] = field(default_factory=Counter)
    chunks: int = 0


def _skip_reason(item_status: str, item_type: str, retrievable: bool) -> str | None:
    if retrievable:
        return None
    if item_type not in INDEXED_TYPES:
        return "not_text"
    if item_status != "approved":
        return "not_approved"
    return "expired"


def ingest(
    catalog: ContentCatalog, embedder: Embedder, index: VectorIndex, today: date
) -> IngestReport:
    if index.model_id != embedder.model_id:
        raise EmbedderMismatchError("index and embedder disagree; rebuild the index")
    report = IngestReport()
    indexed = index.indexed_versions()
    wanted: set[str] = set()
    for item in catalog:
        reason = _skip_reason(item.review_status, item.type, item.is_retrievable(today))
        if reason is not None:
            report.skipped[reason] += 1
            if index.delete_source(item.id):
                report.removed.append(item.id)
            continue
        wanted.add(item.id)
        if indexed.get(item.id) == item.version:
            report.unchanged.append(item.id)
            continue
        index.delete_source(item.id)  # an older version, if any
        chunks = chunk_item(item)
        vectors = embedder.embed([embedding_text(c) for c in chunks])
        index.upsert(chunks, vectors, today)
        report.indexed.append(item.id)
        report.chunks += len(chunks)
    for source_id in sorted(set(indexed) - wanted - set(report.removed)):
        index.delete_source(source_id)  # no longer in the catalog at all
        report.removed.append(source_id)
    log.info(
        "content.ingest indexed=%d unchanged=%d removed=%d chunks=%d skipped=%s",
        len(report.indexed),
        len(report.unchanged),
        len(report.removed),
        report.chunks,
        dict(report.skipped),
    )
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build the local approved-content index.")
    parser.add_argument("sources", nargs="+", type=Path, help="folders or files of items")
    parser.add_argument("--out", type=Path, required=True, help="index file to write")
    args = parser.parse_args(argv)
    today = date.today()
    embedder = make_embedder()
    catalog = ContentCatalog.from_paths(args.sources)
    index = (
        LocalVectorIndex.load(args.out, embedder.model_id, today)
        if args.out.exists()
        else LocalVectorIndex(embedder.model_id)
    )
    report = ingest(catalog, embedder, index, today)
    index.save(args.out)
    print(  # ids and counts only
        f"indexed {len(report.indexed)}, unchanged {len(report.unchanged)}, "
        f"removed {len(report.removed)}, chunks {len(index)}, skipped {dict(report.skipped)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
