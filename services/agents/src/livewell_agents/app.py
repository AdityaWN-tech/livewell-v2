"""FastAPI app for Cloud Run (spec 10.2 Agent Service).

    GET  /healthz                  -> {"status": "ok"}
    POST /v1/briefings/morning     -> CoachResponse, mode briefing (T-AGT-01)
    POST /v1/conversation/turn     -> CoachResponse, mode reply (spec 9.4, 12.1; T-AGT-04)
    POST /v1/reflections           -> CoachResponse, mode reflection (spec 12.1, FR-DLY-05)
    POST /v1/nudges/copy           -> CoachResponse, mode nudge (FR-DLY-04; job endpoint)
    POST /v1/reviews/weekly        -> CoachResponse, mode weekly_review (FR-DLY-06; job endpoint)
All in docs/api/openapi.yaml.

Run locally: uvicorn livewell_agents.app:create_app --factory (see README).
"""

import logging
import os
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException

from livewell_agents.anthropic_client import AnthropicModelClient
from livewell_agents.auth import (
    AI_CONSENTS,
    Authenticator,
    ConsentChecker,
    FakeAuthenticator,
    FakeConsents,
    NotAuthorized,
    NotConfiguredAuthenticator,
    NotConfiguredConsents,
)
from livewell_agents.briefing import BriefingService
from livewell_agents.coach import ConsentRequired, ModeInputs, PassageSource
from livewell_agents.config import Settings, load_settings
from livewell_agents.context import ContextSource, FixtureContextSource, NoContextSource
from livewell_agents.model_client import FakeModelClient, ModelClient
from livewell_agents.models import (
    BriefingRequest,
    BriefingResponse,
    CoachMode,
    CoachResponse,
    ConversationTurnRequest,
    NudgeRequest,
    ReflectionRequest,
    WeeklyReviewRequest,
)
from livewell_agents.prompts import PromptRegistry
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.events import LoggingSafetyEventSink, SafetyEventSink
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.safety.templates import FallbackBriefing
from livewell_agents.tracing import configure_console_tracing

log = logging.getLogger("livewell_agents.app")


@dataclass
class Deps:
    settings: Settings
    auth: Authenticator
    consents: ConsentChecker
    contexts: ContextSource
    model: ModelClient
    #: The safety classifier's own client (T-AGT-02): same provider, shorter timeout.
    classifier_model: ModelClient
    events: SafetyEventSink


def default_deps(settings: Settings) -> Deps:
    model: ModelClient
    classifier_model: ModelClient
    if settings.model_provider == "anthropic":
        model = AnthropicModelClient(
            settings.anthropic_model,
            settings.anthropic_effort,
            settings.anthropic_max_tokens,
            settings.anthropic_timeout_s,
        )
        classifier_model = AnthropicModelClient(
            settings.anthropic_model,
            "low",
            settings.classifier_max_tokens,
            settings.classifier_timeout_s,
        )
    else:
        model, classifier_model = FakeModelClient(), FakeModelClient()
    auth: Authenticator = NotConfiguredAuthenticator()
    consents: ConsentChecker = NotConfiguredConsents()
    project = os.environ.get("LW_FIREBASE_PROJECT")
    if project:
        from livewell_agents.firebase_store import (
            FirebaseAuthenticator,
            FirestoreConsents,
            firebase_app,
        )

        fb = firebase_app(project)
        from firebase_admin import firestore

        auth = FirebaseAuthenticator(
            fb, require_app_check=os.environ.get("LW_REQUIRE_APP_CHECK", "1") != "0"
        )
        consents = FirestoreConsents(firestore.client(app=fb))
    elif settings.env == "dev" and os.environ.get("LW_DEV_FAKE_AUTH") == "1":
        # Local dev only: fake tokens, and the synthetic users have AI consent.
        auth = FakeAuthenticator()
        consents = FakeConsents({u: {"ai_disclosure"} for u in ("demo-us", "demo-in", "demo-x")})
    contexts: ContextSource = (
        FixtureContextSource(settings.fixtures_path) if settings.env == "dev" else NoContextSource()
    )
    return Deps(
        settings, auth, consents, contexts, model, classifier_model, LoggingSafetyEventSink()
    )


def build_retriever(dirs: tuple[Path, ...], today: date) -> PassageSource | None:
    """Approved-only retrieval (T-AGT-03, D-94) over the given content
    folders, indexed in memory at start-up. No folders, no retriever."""
    if not dirs:
        return None
    from livewell_agents.content import (
        ContentCatalog,
        ContentRetriever,
        HashingEmbedder,
        LocalVectorIndex,
        ingest,
    )

    catalog = ContentCatalog.from_paths(dirs)
    embedder = HashingEmbedder()
    index = LocalVectorIndex(embedder.model_id)
    report = ingest(catalog, embedder, index, today)
    log.info("content index built items=%d chunks=%d", len(report.indexed), report.chunks)
    return ContentRetriever(index, embedder, catalog)


def create_app(deps: Deps | None = None) -> FastAPI:
    if deps is None:
        settings = load_settings()
        if os.environ.get("LW_OTEL_CONSOLE") == "1":
            configure_console_tracing()
        deps = default_deps(settings)
    s = deps.settings
    prompts = PromptRegistry(s.prompts_dir)
    service = BriefingService(
        engine=RedFlagEngine(s.safety_rules_dir),
        model=deps.model,
        prompts=prompts,
        fallback=FallbackBriefing(s.moments_path),
        events=deps.events,
        classifier=SafetyClassifier(deps.classifier_model, prompts, s.allow_pending_prompts),
        allow_pending_prompts=s.allow_pending_prompts,
        fallbacks_path=s.fallbacks_path,
        retriever=build_retriever(s.content_dirs, date.today()),
    )
    agent = service.agent
    app = FastAPI(title="Live Well Agent Service", version="0.2.0")

    def caller(
        authorization: Annotated[str, Header()] = "",
        x_firebase_appcheck: Annotated[str, Header()] = "",
    ) -> str:
        token = authorization.removeprefix("Bearer ").strip()
        try:
            return deps.auth.uid_for(token, x_firebase_appcheck)
        except NotAuthorized:
            raise HTTPException(401, "not_authorized") from None

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/v1/briefings/morning")
    def morning_briefing(
        body: BriefingRequest, uid: Annotated[str, Depends(caller)]
    ) -> BriefingResponse:
        ctx = deps.contexts.load(uid, body.local_date)
        if ctx is None:
            raise HTTPException(404, "no_context")
        try:
            return service.morning(ctx, has_ai_consent=deps.consents.has(uid, AI_CONSENTS))
        except ConsentRequired:
            raise HTTPException(403, "consent_required") from None

    def coach(
        mode: CoachMode, uid: str, local_date: date | None, inputs: ModeInputs
    ) -> CoachResponse:
        ctx = deps.contexts.load(uid, local_date)
        if ctx is None:
            raise HTTPException(404, "no_context")
        try:
            return agent.run(mode, ctx, deps.consents.has(uid, AI_CONSENTS), inputs)
        except ConsentRequired:
            raise HTTPException(403, "consent_required") from None

    @app.post("/v1/conversation/turn")
    def conversation_turn(
        body: ConversationTurnRequest, uid: Annotated[str, Depends(caller)]
    ) -> CoachResponse:
        # session_id: session memory (spec 9.8) is not built yet; one turn at a time.
        return coach("reply", uid, body.local_date, ModeInputs(message=body.text))

    @app.post("/v1/reflections")
    def reflection(body: ReflectionRequest, uid: Annotated[str, Depends(caller)]) -> CoachResponse:
        return coach("reflection", uid, body.local_date, ModeInputs(reflection=body.text))

    @app.post("/v1/nudges/copy")
    def nudge(body: NudgeRequest, uid: Annotated[str, Depends(caller)]) -> CoachResponse:
        return coach("nudge", uid, body.local_date, ModeInputs(time_of_day=body.time_of_day))

    @app.post("/v1/reviews/weekly")
    def weekly_review(
        body: WeeklyReviewRequest, uid: Annotated[str, Depends(caller)]
    ) -> CoachResponse:
        return coach("weekly_review", uid, body.local_date, ModeInputs(stats=body.stats))

    return app
