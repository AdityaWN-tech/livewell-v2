"""Adversarial model outputs against Safety.post (spec 15.2: zero medication
or dose-change instructions in outputs). The FakeModelClient plays a model
that writes the unsafe draft; the user must get the fixed fallback."""

import json
from pathlib import Path

import pytest

from conftest import make_context
from livewell_agents.models import CoachDraft
from livewell_agents.safety.postcheck import post_check

CASES = json.loads((Path(__file__).parent / "cases" / "adversarial_outputs.json").read_text())


def _draft(text: str) -> str:
    return json.dumps({"text": text, "emotion": "encouraging"})


@pytest.mark.critical
@pytest.mark.parametrize("case", CASES["unsafe"], ids=lambda c: c["id"])
def test_post_check_rejects(engine, case):
    result = post_check(CoachDraft(text=case["text"], emotion="happy"), engine)
    assert result.verdict in ("rewrite", "block")
    assert case["reason"] in result.reasons, result.reasons


@pytest.mark.critical
@pytest.mark.parametrize("case", CASES["unsafe"], ids=lambda c: c["id"])
def test_unsafe_draft_never_reaches_the_user(make_service, fallback, case):
    service, model, _ = make_service(script=(_draft(case["text"]),))
    resp = service.morning(make_context(), has_ai_consent=True)
    assert resp.route == "fallback"
    assert resp.message.text == fallback.text
    assert resp.message.safety.status == "fallback"
    assert model.calls <= 2


@pytest.mark.parametrize("case", CASES["safe"], ids=lambda c: c["id"])
def test_ordinary_briefings_are_approved(engine, make_service, case):
    assert post_check(CoachDraft(text=case["text"], emotion="happy"), engine).verdict == "approve"
    service, model, _ = make_service(script=(_draft(case["text"]),))
    resp = service.morning(make_context(), has_ai_consent=True)
    assert resp.route == "coach" and resp.message.text == case["text"] and model.calls == 1


def test_case_counts():
    assert len(CASES["unsafe"]) >= 20 and len(CASES["safe"]) >= 5
