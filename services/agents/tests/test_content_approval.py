"""T-AGT-03 Done when, part 1: an unapproved item is never retrievable.

Checked at every layer (ingestion, index, retriever's live status check) and
after status changes, with on-topic distractors whose own text is the query.
"""

from __future__ import annotations

import json
import logging
from datetime import date, timedelta

import pytest

from livewell_agents.content import (
    ContentRetriever,
    HashingEmbedder,
    LocalVectorIndex,
    UnapprovedContentError,
    ingest,
)
from livewell_agents.content.chunking import chunk_item
from livewell_agents.content.index import QueryFilter
from tests.content_support import NEVER, TODAY, build, with_status

pytestmark = pytest.mark.critical


def _ids(passages):
    return {p.source_id for p in passages}


@pytest.mark.parametrize("source_id", NEVER)
def test_unapproved_item_is_not_retrievable_even_with_its_own_text(source_id):
    catalog, index, retriever, _ = build()
    item = catalog.get(source_id)
    assert item is not None
    assert source_id not in index.indexed_versions()
    for text in [item.title, *item.cards, *item.sections]:
        for region in (None, "US", "IN"):
            got = retriever.retrieve(text, item.driver_tags, k=20, region=region)
            assert source_id not in _ids(got)


def test_index_refuses_unapproved_chunks():
    catalog, index, _, _ = build()
    emb = HashingEmbedder()
    for source_id in NEVER:
        chunks = chunk_item(catalog.get(source_id))
        with pytest.raises(UnapprovedContentError):
            index.upsert(chunks, emb.embed([c.text for c in chunks]), TODAY)


def test_index_query_filters_unapproved_rows_that_got_in_anyway():
    """Layer 2 on its own: even a row written behind upsert's back is filtered."""
    catalog, index, _, _ = build()
    emb = HashingEmbedder()
    sneaky = chunk_item(catalog.get("pending_sleep_secrets"))[0]
    index._rows[sneaky.chunk_id] = (sneaky, emb.embed([sneaky.text])[0])
    hits = index.query(emb.embed([sneaky.text])[0], 50, QueryFilter(today=TODAY, region="US"))
    assert sneaky.chunk_id not in {h.chunk.chunk_id for h in hits}


@pytest.mark.parametrize("new_status", ["pending", "retired", "rejected", "draft"])
def test_status_change_hides_item_before_and_after_resync(new_status):
    catalog, index, retriever, _ = build()
    query = "walk for five minutes after lunch at an easy pace"
    assert "move_walk_after_meals" in _ids(retriever.retrieve(query, ["movement"]))

    catalog.put(with_status(catalog.get("move_walk_after_meals"), review_status=new_status))
    # Before the index is re-synced: the retriever's live status check drops it.
    assert "move_walk_after_meals" in index.indexed_versions()
    assert "move_walk_after_meals" not in _ids(retriever.retrieve(query, ["movement"], k=50))

    report = ingest(catalog, HashingEmbedder(), index, TODAY)
    assert "move_walk_after_meals" in report.removed
    assert "move_walk_after_meals" not in index.indexed_versions()
    assert "move_walk_after_meals" not in _ids(retriever.retrieve(query, ["movement"], k=50))


def test_reapproval_brings_item_back():
    catalog, index, retriever, _ = build()
    item = catalog.get("move_walk_after_meals")
    catalog.put(with_status(item, review_status="pending"))
    ingest(catalog, HashingEmbedder(), index, TODAY)
    catalog.put(with_status(item, version=2))
    ingest(catalog, HashingEmbedder(), index, TODAY)
    got = retriever.retrieve("walk after lunch", ["movement"])
    assert {p.version for p in got if p.source_id == item.id} == {2}


def test_new_version_pending_hides_the_old_approved_version():
    catalog, index, retriever, _ = build()
    item = catalog.get("sleep_wind_down")
    catalog.put(with_status(item, version=2, review_status="pending"))
    # Old v1 chunks are still in the index but no longer the approved version.
    assert "sleep_wind_down" not in _ids(retriever.retrieve("wind-down before bed", k=50))
    ingest(catalog, HashingEmbedder(), index, TODAY)
    assert "sleep_wind_down" not in index.indexed_versions()


def test_stale_version_in_index_is_not_returned():
    catalog, index, retriever, _ = build()
    item = catalog.get("sleep_wind_down")
    catalog.put(with_status(item, version=2))  # approved v2, index still has v1
    assert "sleep_wind_down" not in _ids(retriever.retrieve("wind-down before bed", k=50))
    ingest(catalog, HashingEmbedder(), index, TODAY)
    got = [p for p in retriever.retrieve("wind-down before bed", k=50)]
    assert {p.version for p in got if p.source_id == "sleep_wind_down"} == {2}


def test_item_expires_with_time():
    catalog, index, retriever, clock = build()
    item = catalog.get("stress_breathing")
    catalog.put(with_status(item, review_expires_at=TODAY + timedelta(days=1)))
    query = "slow breathing when stressed"
    assert "stress_breathing" in _ids(retriever.retrieve(query, k=20))
    clock.today = TODAY + timedelta(days=2)
    assert "stress_breathing" not in _ids(retriever.retrieve(query, k=50))
    ingest(catalog, HashingEmbedder(), index, clock.today)
    assert "stress_breathing" not in index.indexed_versions()


def test_item_deleted_from_catalog_is_removed():
    catalog, index, retriever, _ = build()
    catalog._items.pop("stress_breathing")
    assert "stress_breathing" not in _ids(retriever.retrieve("slow breathing", k=50))
    report = ingest(catalog, HashingEmbedder(), index, TODAY)
    assert "stress_breathing" in report.removed


def test_status_lookup_failure_returns_nothing(caplog):
    _catalog, index, _, _ = build()

    class Broken:
        def approved_version(self, source_id: str, today: date) -> int | None:
            raise ConnectionError("firestore down")

    retriever = ContentRetriever(index, HashingEmbedder(), Broken(), clock=lambda: TODAY)
    assert retriever.retrieve("slow breathing for stress") == []


def test_saved_index_with_unapproved_row_is_refused(tmp_path):
    _catalog, index, _, _ = build()
    path = tmp_path / "index.json"
    index.save(path)
    data = json.loads(path.read_text())
    data["rows"][0]["chunk"]["review_status"] = "pending"
    path.write_text(json.dumps(data))
    with pytest.raises(UnapprovedContentError):
        LocalVectorIndex.load(path, HashingEmbedder().model_id, TODAY)


def test_region_specific_item_needs_a_known_matching_region():
    """D-03: never guess a region. An India-only item is not shown to a US
    person or to someone whose region is unknown."""
    _, _, retriever, _ = build()
    query = "dal sabzi roti salad with lunch"
    assert "eat_well_indian_kitchen" in _ids(retriever.retrieve(query, region="IN"))
    assert "eat_well_indian_kitchen" not in _ids(retriever.retrieve(query, region="US", k=50))
    assert "eat_well_indian_kitchen" not in _ids(retriever.retrieve(query, region=None, k=50))


def test_logs_hold_ids_and_counts_never_text(caplog):
    catalog, index, retriever, _ = build()
    query = "I feel stressed about my private health worry"
    with caplog.at_level(logging.DEBUG, logger="livewell_agents.content"):
        got = retriever.retrieve(query, ["stress"])
        ingest(catalog, HashingEmbedder(), index, TODAY)
    logged = " ".join(r.getMessage() for r in caplog.records)
    assert got and logged
    assert "private health worry" not in logged
    for p in got:
        assert p.text not in logged
    for item in catalog:
        for text in [*item.cards, *item.sections]:
            assert text not in logged
