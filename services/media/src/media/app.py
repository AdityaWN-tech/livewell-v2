"""HTTP API of the Media Service (spec 12.1, T-AVT-08c):

POST /v1/avatar            start a job: source selfie | built | adjust
GET  /v1/avatar/jobs/{id}  the job's status (owner only)

Every call needs a Firebase ID token (Authorization: Bearer) and an App
Check token (X-Firebase-AppCheck). POST is idempotent with an
Idempotency-Key header. Nothing personal is logged: job ids, statuses and
counts only.
"""

import base64
import binascii
import logging
import os
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated

from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from .auth import (
    SELFIE_CONSENTS,
    Authenticator,
    ConsentChecker,
    NotAuthorized,
    NotConfiguredAuthenticator,
    NotConfiguredConsents,
)
from .frames import (
    BackgroundRemover,
    FaceLocator,
    FrameBuilder,
    FrameChecker,
    FrameStore,
    InMemoryFrameStore,
    KeepBackground,
    NotConfiguredFaces,
)
from .jobs import (
    AvatarDocWriter,
    AvatarSource,
    DailyLimiter,
    DailyLimitReached,
    InMemoryAvatarDocs,
    InMemoryCosts,
    InMemoryJobs,
    InMemoryPortraits,
    JobRunner,
    JobStore,
    Messages,
    new_job,
)
from .prompts import OptionBook, PromptBook, PromptError
from .safety import ImageInspector, NotConfiguredInspector
from .stylizer import AvatarStylizer, NotConfiguredStylizer

log = logging.getLogger("media")

REPO = Path(__file__).resolve().parents[4]

#: A selfie upload, decoded (a phone JPEG at the app's capture size).
MAX_SELFIE_BYTES = 4 * 1024 * 1024


@dataclass
class Settings:
    #: The repo's files; the container sets MEDIA_PROMPTS_PATH and
    #: MEDIA_OPTIONS_PATH to its copies (see the Dockerfile).
    prompts_path: Path = field(
        default_factory=lambda: Path(
            os.environ.get("MEDIA_PROMPTS_PATH", REPO / "docs" / "design" / "avatar-prompts.md")
        )
    )
    options_path: Path = field(
        default_factory=lambda: Path(
            os.environ.get("MEDIA_OPTIONS_PATH", REPO / "content" / "avatar" / "options.json")
        )
    )
    #: Hosts the stylizer may call; empty until a vendor is chosen.
    approved_hosts: frozenset[str] = frozenset()
    min_similarity: float = 0.6
    #: Remote Config `avatar_daily_generations` (default 3).
    daily_limit: Callable[[], int] = lambda: 3
    #: Remote Config `avatar_from_photo` (off until counsel review, T-CMP-02).
    from_photo_enabled: Callable[[], bool] = lambda: False


@dataclass
class Services:
    settings: Settings = field(default_factory=Settings)
    auth: Authenticator = field(default_factory=NotConfiguredAuthenticator)
    consents: ConsentChecker = field(default_factory=NotConfiguredConsents)
    stylizer: AvatarStylizer = field(default_factory=NotConfiguredStylizer)
    inspector: ImageInspector = field(default_factory=NotConfiguredInspector)
    jobs: JobStore = field(default_factory=InMemoryJobs)
    portraits: InMemoryPortraits = field(default_factory=InMemoryPortraits)
    costs: InMemoryCosts = field(default_factory=InMemoryCosts)
    # The frame set (T-AVT-08d).
    locator: FaceLocator = field(default_factory=NotConfiguredFaces)
    remover: BackgroundRemover = field(default_factory=KeepBackground)
    checker: FrameChecker = field(default_factory=lambda: _NoFrameCheck())
    frame_store: FrameStore = field(default_factory=InMemoryFrameStore)
    docs: AvatarDocWriter = field(default_factory=InMemoryAvatarDocs)
    #: Off only in tests about the HTTP layer alone.
    build_frames: bool = True
    clock: Callable[[], datetime] = lambda: datetime.now(UTC)


class _NoFrameCheck:
    """No frame checker chosen yet: no frame passes (all fall back)."""

    def similarity(self, frame: object, neutral: object) -> float:
        return 0.0


class AvatarRequest(BaseModel):
    source: AvatarSource
    #: Fixed option ids only (content/avatar/options.json).
    options: dict[str, str] = Field(default_factory=dict, max_length=20)
    #: From my photo: the live selfie, base64 JPEG. Held only for the job.
    selfie_jpeg_base64: str | None = Field(default=None, repr=False)


def create_app(services: Services | None = None) -> FastAPI:
    s = services or Services()
    prompts = PromptBook.load(s.settings.prompts_path)
    options = OptionBook.load(s.settings.options_path)
    runner = JobRunner(
        prompts=prompts,
        options=options,
        stylizer=s.stylizer,
        inspector=s.inspector,
        jobs=s.jobs,
        portraits=s.portraits,
        costs=s.costs,
        approved_hosts=s.settings.approved_hosts,
        min_similarity=s.settings.min_similarity,
        frames=FrameBuilder(
            prompts=prompts,
            stylizer=s.stylizer,
            locator=s.locator,
            remover=s.remover,
            checker=s.checker,
            store=s.frame_store,
            costs=s.costs,
            approved_hosts=s.settings.approved_hosts,
            clock=s.clock,
        )
        if s.build_frames
        else None,
        docs=s.docs,
        clock=s.clock,
    )
    limiter = DailyLimiter(s.jobs, s.settings.daily_limit)
    app = FastAPI(title="Live Well Media Service", version="1")

    def caller(
        authorization: Annotated[str, Header()] = "",
        x_firebase_appcheck: Annotated[str, Header()] = "",
    ) -> str:
        token = authorization.removeprefix("Bearer ").strip()
        try:
            return s.auth.uid_for(token, x_firebase_appcheck)
        except NotAuthorized:
            raise HTTPException(401, "not_authorized") from None

    @app.post("/v1/avatar", status_code=202)
    def start(
        body: AvatarRequest,
        background: BackgroundTasks,
        uid: Annotated[str, Depends(caller)],
        idempotency_key: Annotated[str | None, Header()] = None,
    ) -> dict[str, object]:
        if idempotency_key:
            existing = s.jobs.by_idempotency_key(uid, idempotency_key)
            if existing is not None:
                return existing.view()
        selfie: bytes | None = None
        if body.source is AvatarSource.SELFIE:
            if not s.settings.from_photo_enabled():
                raise HTTPException(403, "feature_off")
            if not s.consents.has(uid, SELFIE_CONSENTS):
                raise HTTPException(403, "consent_required")
            selfie = _decode_selfie(body.selfie_jpeg_base64)
        elif body.selfie_jpeg_base64 is not None:
            raise HTTPException(422, "selfie_only_for_selfie_source")
        now = s.clock()
        job = new_job(uid, body.source, body.options, now)
        try:
            # Refuse unknown options before anything is spent.
            runner.prompt_for(job)
        except PromptError:
            raise HTTPException(422, "bad_options") from None
        try:
            limiter.check(uid, now)
        except DailyLimitReached:
            raise HTTPException(429, Messages.DAILY_LIMIT) from None
        s.jobs.add(job)
        if idempotency_key:
            s.jobs.remember_key(uid, idempotency_key, job.id)
        log.info("avatar job %s queued (%s)", job.id, job.source.value)
        background.add_task(runner.run, job, selfie)
        return job.view()

    @app.get("/v1/avatar/jobs/{job_id}")
    def status(job_id: str, uid: Annotated[str, Depends(caller)]) -> dict[str, object]:
        job = s.jobs.get(job_id)
        # Someone else's job looks the same as no job.
        if job is None or job.uid != uid:
            raise HTTPException(404, "not_found")
        return job.view()

    return app


def _decode_selfie(data: str | None) -> bytes:
    if not data:
        raise HTTPException(422, "selfie_required")
    try:
        raw = base64.b64decode(data, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(422, "selfie_unreadable") from None
    if len(raw) > MAX_SELFIE_BYTES:
        raise HTTPException(413, "selfie_too_large")
    # A JPEG starts with FF D8 FF.
    if not raw.startswith(b"\xff\xd8\xff"):
        raise HTTPException(422, "selfie_not_jpeg")
    return raw
