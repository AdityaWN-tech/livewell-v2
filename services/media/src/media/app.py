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
import secrets
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated, Literal

from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException, Response
from pydantic import BaseModel, Field

from .audit import AuditEntry, AuditLog, Events, InMemoryAuditLog
from .auth import (
    SELFIE_CONSENTS,
    Authenticator,
    ConsentChecker,
    NotAuthorized,
    NotConfiguredAuthenticator,
    NotConfiguredConsents,
)
from .comfyui import WORKFLOWS, ComfyUISettings, comfyui_stylizers
from .frames import (
    BackgroundRemover,
    FaceLocator,
    FrameBuilder,
    FrameChecker,
    FrameDrawer,
    FrameStore,
    InMemoryFrameStore,
    KeepBackground,
    NotConfiguredFaces,
    PixelFrameChecker,
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
    JobNotifier,
    JobRunner,
    JobStore,
    Messages,
    NoNotifier,
    new_job,
)
from .local_files import FrameLinks, LocalFrameStore, valid_name, valid_uid
from .prompts import OptionBook, PromptBook, PromptError
from .safety import ImageInspector, NotConfiguredInspector
from .stylizer import LOOPBACK_HOSTS, AvatarStylizer, NotConfiguredStylizer

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
    #: Hosts the stylizer may call (MEDIA_APPROVED_HOSTS, comma-separated):
    #: the ComfyUI service's host once it is deployed. Empty: nothing is sent.
    approved_hosts: frozenset[str] = field(
        default_factory=lambda: _hosts(os.environ.get("MEDIA_APPROVED_HOSTS", ""))
    )
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
    #: The 14 frames (avatar_frames.json); None: the portrait stylizer.
    frame_stylizer: AvatarStylizer | None = None
    #: Blink and mouth frames drawn from the portrait (MEDIA_DRAWN_FRAMES).
    drawer: FrameDrawer | None = None
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
    audit: AuditLog = field(default_factory=InMemoryAuditLog)
    notifier: JobNotifier = field(default_factory=NoNotifier)
    #: Frame sets on the service's own disk with signed download links
    #: (development without Cloud Storage, D-64); None in prod.
    local_frames: LocalFrameStore | None = None
    links: FrameLinks | None = None
    #: Off only in tests about the HTTP layer alone.
    build_frames: bool = True
    clock: Callable[[], datetime] = lambda: datetime.now(UTC)

    @classmethod
    def from_env(cls, env: dict[str, str] | None = None) -> "Services":
        """What the container runs: our ComfyUI server when MEDIA_COMFYUI_URL
        is set (from Secret Manager), else Gemini when MEDIA_GEMINI_API_KEY_FILE
        is set (D-64); otherwise nothing is configured. Firebase Admin checks
        callers and consents when MEDIA_FIREBASE_PROJECT is set, and
        MEDIA_FRAMES_DIR keeps frame sets on this computer (development)."""
        env = dict(os.environ if env is None else env)
        approved = _hosts(env.get("MEDIA_APPROVED_HOSTS", ""))
        if approved & LOOPBACK_HOSTS and env.get("MEDIA_ALLOW_LOOPBACK", "0") != "1":
            # Plain HTTP to this computer is for development only (D-64).
            raise ValueError("A loopback host is approved without MEDIA_ALLOW_LOOPBACK=1")
        from_photo = env.get("MEDIA_FROM_PHOTO", "0") == "1"
        settings = Settings(
            approved_hosts=approved,
            from_photo_enabled=lambda: from_photo,
        )
        s = cls(settings=settings)
        comfy = ComfyUISettings.from_env(env)
        key_file = env.get("MEDIA_GEMINI_API_KEY_FILE", "").strip()
        if comfy is not None:
            folder = env.get("MEDIA_WORKFLOWS_PATH")
            workflows = Path(folder) if folder else WORKFLOWS
            s.stylizer, s.frame_stylizer = comfyui_stylizers(
                comfy, settings.approved_hosts, workflows=workflows
            )
        elif key_file:
            from .gemini import GeminiClient, GeminiFaceLocator, GeminiInspector, GeminiStylizer

            client = GeminiClient(Path(key_file).read_text().strip(), settings.approved_hosts)
            s.stylizer = GeminiStylizer(client)
            s.inspector = GeminiInspector(client)
            s.locator = GeminiFaceLocator(client)
            s.checker = PixelFrameChecker()
        models = env.get("MEDIA_MODELS_DIR", "").strip()
        if env.get("MEDIA_LOCAL_CHECKS", "0") == "1" and models:
            from .local_checks import LocalInspector, SkinToneKeeper

            local = LocalInspector.from_dir(Path(models))
            s.inspector = local
            s.locator = local.faces
            s.checker = PixelFrameChecker()
            # Never lighten or darken the person's skin (D-64).
            s.stylizer = SkinToneKeeper(s.stylizer, local.faces)
        if env.get("MEDIA_DRAWN_FRAMES", "0") == "1" and models:
            from .drawn_frames import LandmarkDrawer
            from .local_checks import LANDMARKER

            s.drawer = LandmarkDrawer(str(Path(models) / LANDMARKER))
        project = env.get("MEDIA_FIREBASE_PROJECT", "").strip()
        if project:
            from firebase_admin import firestore

            from .firebase_store import (
                FirebaseAuthenticator,
                FirestoreAvatarDocs,
                FirestoreConsents,
                firebase_app,
            )

            app = firebase_app(project)
            s.auth = FirebaseAuthenticator(
                app, require_app_check=env.get("MEDIA_REQUIRE_APP_CHECK", "1") != "0"
            )
            db = firestore.client(app)
            s.consents = FirestoreConsents(db)
            s.docs = FirestoreAvatarDocs(db)
        frames_dir = env.get("MEDIA_FRAMES_DIR", "").strip()
        if frames_dir:
            s.local_frames = LocalFrameStore(Path(frames_dir))
            s.frame_store = s.local_frames
            # Links only live minutes: a new key per start is enough.
            s.links = FrameLinks(secrets.token_bytes(32))
        return s


def _hosts(value: str) -> frozenset[str]:
    return frozenset(h.strip().lower() for h in value.split(",") if h.strip())


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
    #: How the app saw a live person (T-AVT-08e): a blink or a head turn.
    liveness: Literal["blink", "turn"] | None = None


def create_app(services: Services | None = None) -> FastAPI:
    s = services or Services.from_env()
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
            stylizer=s.frame_stylizer or s.stylizer,
            drawer=s.drawer,
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
        audit=s.audit,
        notifier=s.notifier,
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
            if body.liveness is None:
                raise HTTPException(422, "liveness_required")
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
        if selfie is not None:
            s.audit.append(
                AuditEntry(uid, Events.SELFIE_RECEIVED, job.id, now, f"liveness={body.liveness}")
            )
        log.info("avatar job %s queued (%s)", job.id, job.source.value)
        background.add_task(runner.run, job, selfie)
        return job.view()

    @app.get("/v1/avatar/frames/{version}")
    def frame_links(version: int, uid: Annotated[str, Depends(caller)]) -> dict[str, str]:
        """Signed download links for the caller's own frame set (what the
        Core API's signed Cloud Storage URLs do in prod)."""
        if s.local_frames is None or s.links is None:
            raise HTTPException(404, "not_found")
        links = s.links
        try:
            names = s.local_frames.names(uid, version)
        except ValueError:
            names = []
        if not names:
            raise HTTPException(404, "not_found")
        return {n: links.path(uid, version, n) for n in names}

    @app.get("/v1/avatar/files/{uid}/{version}/{name}")
    def frame_file(uid: str, version: int, name: str, exp: int, sig: str) -> Response:
        store, links = s.local_frames, s.links
        if (
            store is None
            or links is None
            or not valid_uid(uid)
            or not valid_name(name)
            or not links.ok(uid, version, name, exp, sig)
        ):
            raise HTTPException(404, "not_found")
        data = store.read(uid, version, name)
        if data is None:
            raise HTTPException(404, "not_found")
        kind = {"webp": "image/webp", "png": "image/png", "json": "application/json"}
        return Response(
            data,
            media_type=kind[name.rsplit(".", 1)[1]],
            headers={"Cache-Control": "private, no-store"},
        )

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
