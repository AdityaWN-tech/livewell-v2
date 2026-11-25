import pytest

from livewell_agents.anthropic_client import AnthropicModelClient, MissingApiKey
from livewell_agents.config import ConfigError, load_settings


def test_defaults_to_prod_and_refuses_fake_model_there(monkeypatch):
    monkeypatch.delenv("AGENTS_ENV", raising=False)
    monkeypatch.delenv("AGENTS_MODEL_PROVIDER", raising=False)
    with pytest.raises(ConfigError):
        load_settings()


def test_dev_settings(monkeypatch):
    monkeypatch.setenv("AGENTS_ENV", "dev")
    monkeypatch.delenv("LW_ANTHROPIC_MODEL", raising=False)
    s = load_settings()
    assert s.allow_pending_prompts and s.anthropic_model == "claude-opus-5-5"
    assert s.anthropic_effort == "low"


def test_model_is_configurable(monkeypatch):
    monkeypatch.setenv("AGENTS_ENV", "prod")
    monkeypatch.setenv("AGENTS_MODEL_PROVIDER", "anthropic")
    monkeypatch.setenv("LW_ANTHROPIC_MODEL", "claude-sonnet-5-5")
    s = load_settings()
    assert s.anthropic_model == "claude-sonnet-5-5" and not s.allow_pending_prompts


def test_real_client_needs_key_from_env(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    with pytest.raises(MissingApiKey):
        AnthropicModelClient("claude-opus-5-5", "low", 16000, 60)


def test_langsmith_tracing_forced_off(monkeypatch):
    import importlib
    import os

    import livewell_agents

    monkeypatch.setenv("LANGSMITH_TRACING", "true")
    importlib.reload(livewell_agents)
    assert os.environ["LANGSMITH_TRACING"] == "false"
    assert os.environ["LANGCHAIN_TRACING_V2"] == "false"
