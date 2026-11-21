"""CLI: run the golden set and write the gate summary (T-AGT-08).

Exit codes: 0 merge gate passed, 1 merge gate failed, 2 bad golden set or
setup. CI (agents.yml) runs the offline tier and uploads the JSON summary.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from evals.harness.cases import GoldenSetError, load_golden_set
from evals.harness.runner import render_text, run_and_summarise
from evals.harness.targets import Env, ModelFactory
from livewell_agents.config import REPO_ROOT, SERVICE_DIR
from livewell_agents.model_client import ModelClient

GOLDEN_DIR = SERVICE_DIR / "evals" / "golden"


def default_env(model_factory: ModelFactory | None = None) -> Env:
    return Env.create(
        rules_dir=REPO_ROOT / "packages" / "safety-rules",
        moments_path=REPO_ROOT / "content" / "coach" / "moments" / "morning.json",
        prompts_dir=SERVICE_DIR / "prompts",
        schema_path=REPO_ROOT / "packages" / "schemas" / "coach_message.schema.json",
        model_factory=model_factory,
    )


def _live_factory() -> ModelFactory:
    """The real model, only when the owner opts in (costs money; D-90 key
    with zero data retention). Never used in CI."""
    if not (os.environ.get("ANTHROPIC_API_KEY") and os.environ.get("LW_LIVE_EVALS") == "1"):
        raise SystemExit("live tier: set ANTHROPIC_API_KEY and LW_LIVE_EVALS=1 (never in CI)")
    from livewell_agents.anthropic_client import AnthropicModelClient

    model = AnthropicModelClient(
        os.environ.get("LW_ANTHROPIC_MODEL", "claude-opus-5-5"),
        os.environ.get("LW_ANTHROPIC_EFFORT", "low"),  # type: ignore[arg-type]
        int(os.environ.get("LW_ANTHROPIC_MAX_TOKENS", "16000")),
        float(os.environ.get("LW_ANTHROPIC_TIMEOUT_S", "60")),
    )

    def factory(_script: tuple[Any, ...]) -> ModelClient:
        return model

    return factory


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="python -m evals.harness", description=__doc__)
    p.add_argument("--golden", type=Path, default=GOLDEN_DIR)
    p.add_argument("--tier", choices=["offline", "live"], default="offline")
    p.add_argument("--json", type=Path, help="write the machine-readable summary here")
    p.add_argument("--markdown", type=Path, help="write the human summary here")
    args = p.parse_args(argv)
    try:
        golden = load_golden_set(args.golden)
    except (GoldenSetError, OSError, ValueError) as exc:
        print(f"golden set error: {exc}", file=sys.stderr)
        return 2
    factory = _live_factory() if args.tier == "live" else None
    summary = run_and_summarise(golden, default_env(factory), args.tier)
    text = render_text(summary)
    print(text)
    if args.json:
        args.json.write_text(json.dumps(summary, indent=2, sort_keys=False) + "\n", "utf-8")
    if args.markdown:
        args.markdown.write_text(text, "utf-8")
    return 0 if summary["merge_gate"]["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
