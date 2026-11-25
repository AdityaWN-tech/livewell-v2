"""The typed engine gives the same answers as the reference engine
(packages/safety-rules/check_cases.py) on the whole shared case set."""

import importlib.util
import json

import pytest

from livewell_agents.config import REPO_ROOT

RULES_DIR = REPO_ROOT / "packages" / "safety-rules"
CASES = json.loads((RULES_DIR / "cases.json").read_text(encoding="utf-8"))["cases"]


def _reference():
    spec = importlib.util.spec_from_file_location("check_cases", RULES_DIR / "check_cases.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


REF = _reference()
PRIORITY, COMPILED = REF.load_rules()


@pytest.mark.parametrize("case", CASES, ids=lambda c: c["text"][:40])
def test_same_answer_as_reference_engine(engine, case):
    ours = engine.check(case["text"])
    ref_cat, ref_ids = REF.check(case["text"], PRIORITY, COMPILED)
    assert ours.category == ref_cat
    assert list(ours.rule_ids) == ref_ids
    assert ours.category == case["expected"]


def test_unknown_region_gets_every_region(engine):
    assert [c.region for c in engine.contacts_for(None)] == ["US", "IN"]
    assert [c.region for c in engine.contacts_for("IN")] == ["IN"]
