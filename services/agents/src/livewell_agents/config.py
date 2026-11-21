"""Settings from the environment. No secret has a default (AGENTS.md rule 4)."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

SERVICE_DIR = Path(__file__).resolve().parents[2]
REPO_ROOT = SERVICE_DIR.parents[1]

#: Default model (D-90: Claude through the official SDK). Override with LW_ANTHROPIC_MODEL.
DEFAULT_MODEL = "claude-opus-5-5"

Env = Literal["dev", "staging", "prod"]
Effort = Literal["low", "medium", "high"]


class ConfigError(RuntimeError):
    pass


@dataclass(frozen=True)
class Settings:
    env: Env
    model_provider: Literal["fake", "anthropic"]
    anthropic_model: str
    anthropic_effort: Effort
    anthropic_max_tokens: int
    anthropic_timeout_s: float
    safety_rules_dir: Path
    prompts_dir: Path
    moments_path: Path
    fixtures_path: Path

    @property
    def allow_pending_prompts(self) -> bool:
        """Prompts are pending clinical review; only dev may use them (like content)."""
        return self.env == "dev"


def _path(name: str, default: Path) -> Path:
    raw = os.environ.get(name)
    return Path(raw) if raw else default


def load_settings() -> Settings:
    env = os.environ.get("AGENTS_ENV", "prod")
    if env not in ("dev", "staging", "prod"):
        raise ConfigError(f"AGENTS_ENV must be dev, staging or prod, not {env!r}")
    provider = os.environ.get("AGENTS_MODEL_PROVIDER", "fake")
    if provider not in ("fake", "anthropic"):
        raise ConfigError("AGENTS_MODEL_PROVIDER must be fake or anthropic")
    if provider == "fake" and env != "dev":
        raise ConfigError("The fake model client is for dev and tests only")
    effort = os.environ.get("LW_ANTHROPIC_EFFORT", "low")
    if effort not in ("low", "medium", "high"):
        raise ConfigError("LW_ANTHROPIC_EFFORT must be low, medium or high")
    return Settings(
        env=env,  # type: ignore[arg-type]
        model_provider=provider,  # type: ignore[arg-type]
        anthropic_model=os.environ.get("LW_ANTHROPIC_MODEL", DEFAULT_MODEL),
        anthropic_effort=effort,  # type: ignore[arg-type]
        anthropic_max_tokens=int(os.environ.get("LW_ANTHROPIC_MAX_TOKENS", "16000")),
        anthropic_timeout_s=float(os.environ.get("LW_ANTHROPIC_TIMEOUT_S", "60")),
        safety_rules_dir=_path("LW_SAFETY_RULES_DIR", REPO_ROOT / "packages" / "safety-rules"),
        prompts_dir=_path("LW_PROMPTS_DIR", SERVICE_DIR / "prompts"),
        moments_path=_path(
            "LW_MORNING_MOMENT_PATH", REPO_ROOT / "content" / "coach" / "moments" / "morning.json"
        ),
        fixtures_path=_path("LW_FIXTURES_PATH", SERVICE_DIR / "fixtures" / "synthetic_users.json"),
    )
