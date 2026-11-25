"""Embeddings behind one interface (T-AGT-03, D-94).

`HashingEmbedder` is the dev/test/CI implementation: deterministic, offline,
no model download, standard library only. It hashes stemmed words and word
pairs into a fixed-size signed vector (the "hashing trick"), so similar
wording gives similar vectors. It is lexical: it knows no synonyms.

PRODUCTION ADAPTER POINT: the production embedding provider is an open
question (D-94; candidates include Vertex AI text embeddings next to the
Firestore vector store). Add a class with the same `Embedder` shape and
register it in `make_embedder`. Rules for any provider: zero data retention,
no content text in logs, and the index must be rebuilt when `model_id`
changes (vectors from different models are never mixed; the index checks).
"""

from __future__ import annotations

import hashlib
import itertools
import math
import re
from collections import Counter
from collections.abc import Sequence
from typing import Protocol

Vector = list[float]


class Embedder(Protocol):
    @property
    def model_id(self) -> str: ...

    @property
    def dim(self) -> int: ...

    def embed(self, texts: Sequence[str]) -> list[Vector]: ...


_WORD = re.compile(r"[a-z0-9]+")
_STOPWORDS = frozenset(
    """a about after again all also am an and any are as at be because been before
    being but by can could did do does doing down during each few for from had has
    have having he her here hers him his how i if in into is it its just let lets
    me more most my myself no nor not now of off on once only or other our ours
    out over own same she should so some such than that the their them then there
    these they this those through to too under until up very was we were what when
    where which while who whom why will with would you your yours yourself""".split()  # noqa: SIM905
)
# Longest first; a stem keeps at least 3 letters.
_SUFFIXES = ("ingly", "edly", "ness", "ment", "ing", "ies", "ied", "ed", "ly", "es", "s")


def stem(word: str) -> str:
    """A tiny suffix stripper: 'walking', 'walked', 'walks' -> 'walk'."""
    for suffix in _SUFFIXES:
        if word.endswith(suffix) and len(word) - len(suffix) >= 3:
            base = word[: -len(suffix)]
            if suffix in ("ies", "ied"):
                return base + "y"
            if suffix == "es" and not base.endswith(("s", "x", "z", "ch", "sh")):
                return word[:-1]  # 'breathes' -> 'breathe'
            if len(base) >= 4 and base[-1] == base[-2] and base[-1] not in "lsz":
                base = base[:-1]  # 'stepping' -> 'step'
            return base
    return word


def tokens(text: str) -> list[str]:
    return [stem(w) for w in _WORD.findall(text.lower()) if w not in _STOPWORDS]


def _bucket(feature: str, dim: int) -> tuple[int, float]:
    # blake2b, not hash(): Python's hash() changes between processes.
    digest = hashlib.blake2b(feature.encode("utf-8"), digest_size=8).digest()
    value = int.from_bytes(digest, "big")
    return value % dim, (1.0 if (value >> 63) & 1 else -1.0)


class HashingEmbedder:
    """Deterministic lexical embedder for dev, tests and CI (no network)."""

    def __init__(self, dim: int = 4096, bigram_weight: float = 0.5) -> None:
        self._dim = dim
        self._bigram_weight = bigram_weight

    @property
    def model_id(self) -> str:
        return f"hashing-v1-{self._dim}"

    @property
    def dim(self) -> int:
        return self._dim

    def _one(self, text: str) -> Vector:
        toks = tokens(text)
        bigrams = Counter(f"{a}_{b}" for a, b in itertools.pairwise(toks))
        vec = [0.0] * self._dim
        for feats, weight in ((Counter(toks), 1.0), (bigrams, self._bigram_weight)):
            for feat, count in feats.items():
                idx, sign = _bucket(feat, self._dim)
                vec[idx] += sign * weight * (1.0 + math.log(count))
        norm = math.sqrt(sum(v * v for v in vec))
        return [v / norm for v in vec] if norm else vec

    def embed(self, texts: Sequence[str]) -> list[Vector]:
        return [self._one(t) for t in texts]


def make_embedder(provider: str = "hashing") -> Embedder:
    """The embedder for `provider`. Only the offline one exists so far."""
    if provider == "hashing":
        return HashingEmbedder()
    # PRODUCTION ADAPTER POINT (D-94): register the chosen provider here.
    raise NotImplementedError(f"embedding provider {provider!r} is not chosen yet (D-94)")


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    """Dot product; both vectors are already unit length (or zero)."""
    return sum(x * y for x, y in zip(a, b, strict=True))
