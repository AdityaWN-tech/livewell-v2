"""Memory Agent safety eval (T-AGT-05, D-100): sensitive categories need the
opt-in, red flags and unsafe content are never remembered, consent off means
no model call. Cases: evals/cases/memory_eval.json (synthetic)."""

import json
from datetime import timedelta
from pathlib import Path

import pytest

from conftest import NOW, make_context
from livewell_agents.config import SERVICE_DIR
from livewell_agents.memory import InMemoryMemoryStore, MemoryAgent, MemoryConsents
from livewell_agents.memory.models import FactDraft, MemoryProposeRequest
from livewell_agents.memory.policy import check_fact
from livewell_agents.model_client import FakeModelClient
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier

CASES = json.loads((Path(__file__).parent / "cases" / "memory_eval.json").read_text("utf-8"))


def _param(c):
    marks = [pytest.mark.critical] if c.get("critical", True) else []
    return pytest.param(c, id=c["id"], marks=marks)


@pytest.mark.parametrize("case", [_param(c) for c in CASES["fact_cases"]])
def test_fact_policy(engine, case):
    d = check_fact(
        FactDraft(fact=case["fact"], category=case["category"], confidence=case["confidence"]),
        engine,
    )
    exp = case["expect"]
    assert d.keep is exp["keep"], d.reason
    if "category" in exp:
        assert d.category == exp["category"]
    if "sensitive" in exp:
        assert d.sensitive is exp["sensitive"]
    if "reason" in exp:
        assert d.reason == exp["reason"]


@pytest.mark.parametrize("case", [_param(c) for c in CASES["propose_cases"]])
def test_propose(engine, case):
    script = ()
    if "draft" in case:
        script = (
            json.dumps(
                {
                    "facts": [
                        {"fact": f, "category": c, "confidence": p} for f, c, p in case["draft"]
                    ]
                }
            ),
        )
    model = FakeModelClient(script=script)
    cmodel = FakeModelClient()
    store = InMemoryMemoryStore()
    prompts = PromptRegistry(SERVICE_DIR / "prompts")
    agent = MemoryAgent(
        store=store,
        engine=engine,
        model=model,
        prompts=prompts,
        classifier=SafetyClassifier(cmodel, prompts, True),
        allow_pending_prompts=True,
        clock=lambda: NOW,
    )
    c = case.get("consents", {"memory": True, "sensitive": False, "ai": True})
    ctx = make_context()
    if "recent_event_hours" in case:
        ctx = make_context(last_safety_event_at=NOW - timedelta(hours=case["recent_event_hours"]))
    r = agent.propose(
        ctx,
        MemoryProposeRequest(text=case["text"], source="conversation", source_message_id="m1"),
        MemoryConsents(**c),
    )
    assert r.reason == case["expect"]
    if case["expect"] != "ok":
        assert store.list(ctx.uid) == []
    if case["expect"] in (
        "memory_off",
        "no_ai_consent",
        "red_flag",
        "instruction_like",
        "recent_safety_event",
    ):
        assert model.calls == 0
