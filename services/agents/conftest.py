"""Shared pytest fixtures for tests/ and evals/. Everything here is synthetic
and offline: FakeModelClient only, no network, no keys."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import pytest
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from livewell_agents.briefing import BriefingService
from livewell_agents.config import REPO_ROOT, SERVICE_DIR, Settings
from livewell_agents.model_client import FakeModelClient
from livewell_agents.models import UserContext
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.events import ListSafetyEventSink
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import FallbackBriefing

NOW = datetime(2026, 11, 19, 6, 0, tzinfo=UTC)
TODAY = date(2026, 11, 19)

_EXPORTER = InMemorySpanExporter()
_provider = TracerProvider()
_provider.add_span_processor(SimpleSpanProcessor(_EXPORTER))
trace.set_tracer_provider(_provider)


@pytest.fixture
def spans() -> Iterator[InMemorySpanExporter]:
    _EXPORTER.clear()
    yield _EXPORTER
    _EXPORTER.clear()


def dev_settings(**overrides: Any) -> Settings:
    base: dict[str, Any] = {
        "env": "dev",
        "model_provider": "fake",
        "anthropic_model": "claude-opus-5-5",
        "anthropic_effort": "low",
        "anthropic_max_tokens": 16000,
        "anthropic_timeout_s": 60.0,
        "safety_rules_dir": REPO_ROOT / "packages" / "safety-rules",
        "prompts_dir": SERVICE_DIR / "prompts",
        "moments_path": REPO_ROOT / "content" / "coach" / "moments" / "morning.json",
        "fixtures_path": SERVICE_DIR / "fixtures" / "synthetic_users.json",
    }
    base.update(overrides)
    return Settings(**base)


@pytest.fixture(scope="session")
def engine() -> RedFlagEngine:
    return RedFlagEngine(REPO_ROOT / "packages" / "safety-rules")


@pytest.fixture(scope="session")
def fallback() -> FallbackBriefing:
    return FallbackBriefing(REPO_ROOT / "content" / "coach" / "moments" / "morning.json")


@pytest.fixture(scope="session")
def schema_path() -> Path:
    return REPO_ROOT / "packages" / "schemas" / "coach_message.schema.json"


def make_context(**overrides: Any) -> UserContext:
    """A synthetic person (invented; no real data)."""
    base: dict[str, Any] = {
        "uid": "synthetic-1",
        "first_name": "Maya",
        "coach_name": "Sam",
        "region": "US",
        "local_date": TODAY,
        "why": "Energy to play with my grandkids at the park",
        "focus_driver": "move_more",
        "plan_step": {"title": "Walk after lunch", "minutes": 10, "smaller_minutes": 5},
        "last_checkin": {"day": "2026-11-18", "mood": 4, "energy": 3},
        "streak_days": 4,
    }
    base.update(overrides)
    return UserContext.model_validate(base)


ServiceFactory = Callable[..., tuple[BriefingService, FakeModelClient, ListSafetyEventSink]]


@pytest.fixture
def make_service(engine: RedFlagEngine, fallback: FallbackBriefing) -> ServiceFactory:
    def factory(
        script: tuple[Any, ...] = (),
        allow_pending: bool = True,
        classifier_model: FakeModelClient | None = None,
    ) -> tuple[BriefingService, FakeModelClient, ListSafetyEventSink]:
        """`model` is the Coach model only. The safety classifier has its own
        fake (pass `classifier_model` to script or inspect it; by default it
        answers "clear", which can never clear a rule hit)."""
        model = FakeModelClient(script=script)
        events = ListSafetyEventSink()
        prompts = PromptRegistry(SERVICE_DIR / "prompts")
        service = BriefingService(
            engine=engine,
            model=model,
            prompts=prompts,
            fallback=fallback,
            events=events,
            classifier=SafetyClassifier(
                classifier_model if classifier_model is not None else FakeModelClient(),
                prompts,
                allow_pending,
            ),
            allow_pending_prompts=allow_pending,
            clock=lambda: NOW,
        )
        return service, model, events

    return factory
