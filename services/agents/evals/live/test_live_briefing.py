"""OPT-IN live eval against the real Anthropic API (costs money).

Runs only when BOTH are set: ANTHROPIC_API_KEY (a dev key with zero data
retention, D-90) and LW_LIVE_EVALS=1. Never in CI. Synthetic users only.

    LW_LIVE_EVALS=1 pytest -m live evals/live -s

Reports, per synthetic user and run: route, post-check outcome and schema
validity (spec 15.2: schema validity 99.5% with retry; this small run is a
smoke test, not the 300-case gate of T-AGT-08).
"""

import json
import os

import jsonschema
import pytest

from conftest import NOW, dev_settings
from livewell_agents.anthropic_client import AnthropicModelClient
from livewell_agents.briefing import BriefingService
from livewell_agents.context import FixtureContextSource
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.events import ListSafetyEventSink

pytestmark = [
    pytest.mark.live,
    pytest.mark.skipif(
        not (os.environ.get("ANTHROPIC_API_KEY") and os.environ.get("LW_LIVE_EVALS") == "1"),
        reason="live eval: set ANTHROPIC_API_KEY and LW_LIVE_EVALS=1",
    ),
]

RUNS = int(os.environ.get("LW_LIVE_RUNS", "3"))


def test_live_morning_briefings(engine, fallback, schema_path):
    s = dev_settings(
        model_provider="anthropic",
        anthropic_model=os.environ.get("LW_ANTHROPIC_MODEL", "claude-opus-5-5"),
    )
    schema = json.loads(schema_path.read_text())
    contexts = FixtureContextSource(s.fixtures_path)
    routes: dict[str, int] = {}
    for uid in ("demo-us", "demo-in", "demo-x"):
        for _ in range(RUNS):
            service = BriefingService(
                engine=engine,
                model=AnthropicModelClient(
                    s.anthropic_model,
                    s.anthropic_effort,
                    s.anthropic_max_tokens,
                    s.anthropic_timeout_s,
                ),
                prompts=PromptRegistry(s.prompts_dir),
                fallback=fallback,
                events=ListSafetyEventSink(),
                allow_pending_prompts=True,
                clock=lambda: NOW,
            )
            ctx = contexts.load(uid, None)
            assert ctx is not None
            resp = service.morning(ctx, has_ai_consent=True)
            jsonschema.validate(resp.message.model_dump(mode="json"), schema)
            routes[resp.route] = routes.get(resp.route, 0) + 1
            print(uid, resp.route, resp.message.model, resp.message.safety.checks)
            print("   ", resp.message.text)
    print("routes:", routes)
    assert routes.get("coach", 0) >= 1, "no live draft passed the post-check"
