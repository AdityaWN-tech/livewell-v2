"""T-AGT-03 Done when, part 2: retrieval precision@5 >= 0.8 on the eval set.

Fully offline (HashingEmbedder + LocalVectorIndex over the synthetic corpus).
precision@5 counts the retrieved chunks whose source is relevant, divided by 5
(strict: returning fewer than 5 counts the gaps as misses). Runs in CI.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.content_support import NEVER, build

HERE = Path(__file__).parent
EVAL = json.loads((HERE / "cases" / "retrieval_eval.json").read_text(encoding="utf-8"))
K = EVAL["k"]
THRESHOLD = EVAL["threshold"]


def _precision(retriever, case, use_drivers=True):
    tags = case["driver_tags"] if use_drivers else ()
    got = retriever.retrieve(case["query"], tags, k=K, region="US")
    assert all(p.source_id not in NEVER for p in got), case["id"]
    return sum(p.source_id in case["relevant"] for p in got) / K


def test_eval_set_is_well_formed():
    catalog, _, _, _ = build()
    assert len(EVAL["cases"]) >= 20 and THRESHOLD >= 0.8 and K == 5
    for case in EVAL["cases"]:
        for source_id in case["relevant"]:
            item = catalog.get(source_id)
            assert item is not None and item.review_status == "approved", source_id


@pytest.mark.critical
def test_precision_at_5_meets_threshold():
    _, _, retriever, _ = build()
    scores = {c["id"]: _precision(retriever, c) for c in EVAL["cases"]}
    mean = sum(scores.values()) / len(scores)
    print(f"\nretrieval precision@{K} = {mean:.3f} over {len(scores)} cases")
    assert mean >= THRESHOLD, {k: v for k, v in scores.items() if v < 1}


def test_precision_without_driver_tags_is_reported():
    """When the focus driver is unknown, precision drops; it must still clear
    the bar so retrieval does not rely on the driver boost alone."""
    _, _, retriever, _ = build()
    scores = [_precision(retriever, c, use_drivers=False) for c in EVAL["cases"]]
    mean = sum(scores) / len(scores)
    print(f"\nretrieval precision@{K} without driver tags = {mean:.3f}")
    assert mean >= THRESHOLD
