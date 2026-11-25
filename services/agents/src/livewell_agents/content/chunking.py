"""Split an approved content item into retrievable chunks (T-AGT-03).

Lessons: one chunk per card (cards are already short, D-57) plus one for the
MY GOAL DO IT microhabit. Book excerpts: paragraphs packed up to
`MAX_WORDS`, a long paragraph split at sentence ends. Chunk text is the
approved text unchanged: nothing is added, rewritten or summarised.
"""

from __future__ import annotations

import re

from livewell_agents.content.models import Chunk, ContentItem, text_sha256

MAX_WORDS = 120
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")


def chunk_id(source_id: str, version: int, ordinal: int) -> str:
    return f"{source_id}@v{version}#{ordinal}"


def _pack(paragraphs: list[str], max_words: int) -> list[str]:
    pieces: list[str] = []
    for para in paragraphs:
        para = " ".join(para.split())
        if not para:
            continue
        if len(para.split()) <= max_words:
            pieces.append(para)
            continue
        current: list[str] = []
        for sentence in _SENTENCE_END.split(para):
            if current and len(" ".join([*current, sentence]).split()) > max_words:
                pieces.append(" ".join(current))
                current = []
            current.append(sentence)
        if current:
            pieces.append(" ".join(current))
    # Merge neighbours that fit together, so tiny paragraphs don't become
    # chunks with too little context.
    merged: list[str] = []
    for piece in pieces:
        if merged and len(merged[-1].split()) + len(piece.split()) <= max_words // 2:
            merged[-1] = f"{merged[-1]} {piece}"
        else:
            merged.append(piece)
    return merged


def chunk_item(item: ContentItem, max_words: int = MAX_WORDS) -> list[Chunk]:
    """Chunks for one item. The caller decides whether the item may be indexed."""
    if item.type == "lesson":
        texts = [" ".join(c.split()) for c in item.cards if c.strip()]
        if item.microhabit is not None:
            mh = item.microhabit
            texts.append(f"MY GOAL DO IT: {mh.title} ({mh.minutes} minutes).")
    elif item.type == "book":
        texts = _pack(item.sections, max_words)
    else:
        texts = []
    return [
        Chunk(
            chunk_id=chunk_id(item.id, item.version, n),
            source_id=item.id,
            type=item.type,
            title=item.title,
            ordinal=n,
            text=text,
            text_sha256=text_sha256(text),
            driver_tags=tuple(item.driver_tags),
            pillar_tags=tuple(item.pillar_tags),
            version=item.version,
            review_status=item.review_status,
            locale=item.locale,
            region=item.region,
            source_ref=item.source_ref,
            review_expires_at=item.review_expires_at,
        )
        for n, text in enumerate(texts)
    ]


def embedding_text(chunk: Chunk) -> str:
    """What is embedded: a short header (title and driver tags) gives a short
    card its topic. The stored and returned text is the card alone."""
    tags = " ".join(t.replace("_", " ") for t in (*chunk.driver_tags, *chunk.pillar_tags))
    return f"{chunk.title}. {tags}. {chunk.text}"
