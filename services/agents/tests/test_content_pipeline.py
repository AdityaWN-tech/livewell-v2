"""T-AGT-03: content item validation, chunking, ingestion and the local index."""

from __future__ import annotations

import json
from datetime import date

import pytest
from pydantic import ValidationError

from livewell_agents.config import REPO_ROOT
from livewell_agents.content import (
    ContentCatalog,
    ContentItem,
    ContentRetriever,
    HashingEmbedder,
    LocalVectorIndex,
    ingest,
    make_embedder,
)
from livewell_agents.content.chunking import MAX_WORDS, chunk_item
from livewell_agents.content.embedding import cosine, stem
from livewell_agents.content.index import EmbedderMismatchError
from livewell_agents.content.ingest import main
from tests.content_support import CORPUS, TODAY, build

APPROVED = {"review_status": "approved", "reviewed_by": "r", "reviewed_at": "2026-11-01"}


def _lesson(**kw):
    base = {
        "id": "x_lesson",
        "type": "lesson",
        "title": "T",
        "version": 1,
        "driver_tags": ["sleep"],
        "cards": ["One.", "Two."],
        **APPROVED,
    }
    base.update(kw)
    return ContentItem.model_validate(base)


def test_corpus_loads_and_has_every_status_and_type():
    catalog = ContentCatalog.from_paths([CORPUS])
    assert {i.review_status for i in catalog} >= {
        "approved",
        "pending",
        "retired",
        "rejected",
        "draft",
    }
    assert {i.type for i in catalog} == {"lesson", "book"}
    assert len({tag for i in catalog for tag in i.driver_tags}) == 8


@pytest.mark.parametrize(
    "bad",
    [
        {"driver_tags": []},
        {"driver_tags": ["Sleep Well"]},
        {"cards": []},
        {"id": "Bad Id"},
        {"version": 0},
        {"review_status": "ok"},
        {"region": "UK"},
        {"reviewed_by": None},
        {"unknown_field": 1},
    ],
)
def test_invalid_items_are_rejected(bad):
    with pytest.raises(ValidationError):
        _lesson(**bad)


def test_book_needs_sections():
    with pytest.raises(ValidationError):
        _lesson(type="book", cards=[])


def test_metadata_is_on_every_chunk():
    item = _lesson(
        cards=["Card one.", "Card two."],
        microhabit={"title": "Do it", "minutes": 2},
        pillar_tags=["rest_well"],
        region="US",
    )
    chunks = chunk_item(item)
    assert [c.text for c in chunks] == [
        "Card one.",
        "Card two.",
        "MY GOAL DO IT: Do it (2 minutes).",
    ]
    for n, c in enumerate(chunks):
        assert c.chunk_id == f"x_lesson@v1#{n}"
        assert (c.source_id, c.type, c.version, c.review_status) == (
            "x_lesson",
            "lesson",
            1,
            "approved",
        )
        assert c.driver_tags == ("sleep",) and c.pillar_tags == ("rest_well",)
        assert (c.locale, c.region) == ("en", "US")
        assert len(c.text_sha256) == 64


def test_book_chunks_keep_text_unchanged_and_bounded():
    long = " ".join(f"Sentence number {i} is here." for i in range(80))
    item = _lesson(type="book", cards=[], sections=["Short one.", "Short two.", long])
    chunks = chunk_item(item)
    assert all(len(c.text.split()) <= MAX_WORDS for c in chunks)
    assert chunks[0].text == "Short one. Short two."  # tiny neighbours merged
    assert " ".join(c.text for c in chunks[1:]) == long


def test_ingest_counts_and_is_idempotent():
    catalog = ContentCatalog.from_paths([CORPUS])
    emb = HashingEmbedder()
    index = LocalVectorIndex(emb.model_id)
    first = ingest(catalog, emb, index, TODAY)
    approved = [i.id for i in catalog if i.is_retrievable(TODAY)]
    assert sorted(first.indexed) == sorted(approved)
    assert first.skipped == {"not_approved": 4, "expired": 1}
    assert first.chunks == len(index)
    again = ingest(catalog, emb, index, TODAY)
    assert again.indexed == [] and sorted(again.unchanged) == sorted(approved)


def test_audio_items_are_not_indexed():
    item = ContentItem.model_validate(
        {
            "id": "breath_box",
            "type": "audio",
            "title": "Box",
            "version": 1,
            "driver_tags": ["stress"],
            "breathing": "box",
            **APPROVED,
        }
    )
    emb = HashingEmbedder()
    index = LocalVectorIndex(emb.model_id)
    report = ingest(ContentCatalog([item]), emb, index, TODAY)
    assert report.skipped == {"not_text": 1} and len(index) == 0


def test_embedder_is_deterministic_and_similar_for_similar_text():
    emb = HashingEmbedder()
    a, b, c = emb.embed(["walking after meals", "a walk after a meal", "dim the bedroom lights"])
    assert emb.embed(["walking after meals"])[0] == a
    assert cosine(a, b) > 0.5 > cosine(a, c)
    assert stem("walking") == stem("walked") == stem("walks") == "walk"


def test_unknown_embedding_provider_is_not_guessed():
    with pytest.raises(NotImplementedError):
        make_embedder("vertex")


def test_index_and_embedder_must_match(tmp_path):
    _, index, _, _ = build()
    other = HashingEmbedder(dim=512)
    with pytest.raises(EmbedderMismatchError):
        ingest(ContentCatalog([]), other, index, TODAY)
    with pytest.raises(EmbedderMismatchError):
        ContentRetriever(index, other, ContentCatalog([]))
    index.save(tmp_path / "i.json")
    with pytest.raises(EmbedderMismatchError):
        LocalVectorIndex.load(tmp_path / "i.json", other.model_id, TODAY)


def test_saved_index_round_trips_and_drops_rows_expired_since(tmp_path):
    _catalog, index, _, _ = build()
    path = tmp_path / "i.json"
    index.save(path)
    loaded = LocalVectorIndex.load(path, HashingEmbedder().model_id, TODAY)
    assert loaded.indexed_versions() == index.indexed_versions()
    data = json.loads(path.read_text())
    data["rows"][0]["chunk"]["review_expires_at"] = "2026-01-01"
    path.write_text(json.dumps(data))
    assert len(LocalVectorIndex.load(path, HashingEmbedder().model_id, TODAY)) == len(index) - 1


def test_empty_query_and_bad_k_return_nothing():
    _, _, retriever, _ = build()
    assert retriever.retrieve("   ") == []
    assert retriever.retrieve("sleep", k=0) == []


def test_unrelated_query_returns_nothing():
    _, _, retriever, _ = build()
    assert retriever.retrieve("quarterly tax filing spreadsheet") == []


def test_passages_carry_source_ids_for_the_coach():
    _, _, retriever, _ = build()
    got = retriever.retrieve("slow breathing for stress", ["stress"])
    assert got and all(p.source_id and p.chunk_id.startswith(p.source_id) for p in got)
    assert [p.score for p in got] == sorted((p.score for p in got), reverse=True)


def test_cli_builds_an_index_file(tmp_path, capsys):
    out = tmp_path / "content.json"
    assert main([str(CORPUS), "--out", str(out)]) == 0
    data = json.loads(out.read_text())
    assert data["model_id"] == HashingEmbedder().model_id
    assert {r["chunk"]["review_status"] for r in data["rows"]} == {"approved"}
    printed = capsys.readouterr().out
    assert "indexed" in printed and "Breathe" not in printed
    # Second run reuses the file.
    assert main([str(CORPUS), "--out", str(out)]) == 0
    assert "indexed 0" in capsys.readouterr().out


def test_catalog_rejects_duplicate_ids():
    with pytest.raises(ValueError):
        ContentCatalog([_lesson(), _lesson()])


def test_catalog_status_lookup():
    item = _lesson(review_expires_at=date(2026, 12, 1))
    catalog = ContentCatalog([item])
    assert catalog.approved_version("x_lesson", TODAY) == 1
    assert catalog.approved_version("x_lesson", date(2026, 12, 2)) is None
    assert catalog.approved_version("nope", TODAY) is None


def test_repo_content_folders_validate():
    """Real lessons (content/lessons) and licensed book excerpts (content/book,
    never committed) must load with the same schema the pipeline enforces."""
    folders = [REPO_ROOT / "content" / "lessons", REPO_ROOT / "content" / "book"]
    catalog = ContentCatalog.from_paths([f for f in folders if f.is_dir()])
    for item in catalog:
        assert item.type in {"lesson", "book", "audio"}
