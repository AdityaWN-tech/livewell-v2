"""Avatar generation jobs (T-AVT-08c): one job makes one adult 3D portrait
from a selfie, from fixed options (Build my own), or by adjusting the approved
portrait. Every result passes the safety check; a failed attempt is retried
once, then the person gets a kind message. The frame set is built from the
approved portrait in T-AVT-08d.
"""

from __future__ import annotations

import logging
import secrets
import threading
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from enum import StrEnum
from typing import Protocol

from pydantic import BaseModel, Field

from .audit import AuditEntry, AuditLog, Events
from .prompts import OptionBook, PromptBook
from .safety import ImageInspector, Rejection, judge
from .stylizer import AvatarStylizer, EndpointNotApproved, StylizerError, check_endpoint

log = logging.getLogger("media")


class AvatarSource(StrEnum):
    SELFIE = "selfie"
    BUILT = "built"
    ADJUST = "adjust"


class JobStatus(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    #: The safety check refused both attempts.
    REJECTED = "rejected"
    #: The image method failed both attempts, or nothing to adjust.
    FAILED = "failed"


class Messages:
    """Message ids the app turns into kind, plain words (never raw errors)."""

    NOT_MADE = "avatar_not_made"
    NO_PORTRAIT = "avatar_no_portrait"
    DAILY_LIMIT = "avatar_daily_limit"


class Job(BaseModel):
    id: str
    uid: str
    source: AvatarSource
    options: dict[str, str] = Field(default_factory=dict)
    status: JobStatus = JobStatus.QUEUED
    attempts: int = 0
    #: Why the safety check refused (codes only; no image or personal data).
    rejections: list[str] = Field(default_factory=list)
    message_id: str | None = None
    portrait_id: str | None = None
    #: The frame set made from the portrait (T-AVT-08d).
    frames_version: int | None = None
    created_at: datetime
    updated_at: datetime

    def view(self) -> dict[str, object]:
        """What GET /v1/avatar/jobs/{id} returns."""
        return {
            "job_id": self.id,
            "source": self.source.value,
            "status": self.status.value,
            "message_id": self.message_id,
            "portrait_id": self.portrait_id,
            "frames_version": self.frames_version,
        }


class JobStore(Protocol):
    def add(self, job: Job) -> None: ...
    def get(self, job_id: str) -> Job | None: ...
    def save(self, job: Job) -> None: ...
    def count_on(self, uid: str, day: date) -> int: ...
    def by_idempotency_key(self, uid: str, key: str) -> Job | None: ...
    def remember_key(self, uid: str, key: str, job_id: str) -> None: ...


class PortraitStore(Protocol):
    """Approved portraits (Cloud Storage avatars/{uid}/portraits/ in prod)."""

    def put(self, uid: str, image: bytes) -> str: ...
    def latest(self, uid: str) -> tuple[str, bytes] | None: ...


@dataclass(frozen=True)
class CostEntry:
    """One generation's cost, for the cost dashboard (spec 8.4)."""

    uid: str
    job_id: str
    model: str
    usd: float
    at: datetime


class CostRecorder(Protocol):
    def record(self, entry: CostEntry) -> None: ...


@dataclass
class InMemoryJobs:
    jobs: dict[str, Job] = field(default_factory=dict)
    keys: dict[tuple[str, str], str] = field(default_factory=dict)
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def add(self, job: Job) -> None:
        with self._lock:
            self.jobs[job.id] = job

    def get(self, job_id: str) -> Job | None:
        return self.jobs.get(job_id)

    def save(self, job: Job) -> None:
        with self._lock:
            self.jobs[job.id] = job

    def count_on(self, uid: str, day: date) -> int:
        return sum(1 for j in self.jobs.values() if j.uid == uid and j.created_at.date() == day)

    def by_idempotency_key(self, uid: str, key: str) -> Job | None:
        job_id = self.keys.get((uid, key))
        return None if job_id is None else self.jobs.get(job_id)

    def remember_key(self, uid: str, key: str, job_id: str) -> None:
        self.keys[(uid, key)] = job_id


@dataclass
class InMemoryPortraits:
    portraits: dict[str, list[tuple[str, bytes]]] = field(default_factory=dict)

    def put(self, uid: str, image: bytes) -> str:
        portrait_id = secrets.token_hex(8)
        self.portraits.setdefault(uid, []).append((portrait_id, image))
        return portrait_id

    def latest(self, uid: str) -> tuple[str, bytes] | None:
        items = self.portraits.get(uid)
        return items[-1] if items else None


@dataclass
class InMemoryCosts:
    entries: list[CostEntry] = field(default_factory=list)

    def record(self, entry: CostEntry) -> None:
        self.entries.append(entry)


class FrameMaker(Protocol):
    """Builds the frame set from an approved portrait (frames.FrameBuilder);
    returns the new frame set version, or raises when no set can be made."""

    def build_version(self, uid: str, portrait: bytes, job_id: str) -> int: ...


class AvatarDocWriter(Protocol):
    """Writes the server-only fields of users/{uid}/avatar/current:
    `source` (selfie | built) and `frames_version` (Firestore at deploy)."""

    def set_frames(self, uid: str, source: str | None, frames_version: int) -> None:
        """[source] None keeps the current one (Adjust)."""
        ...


@dataclass
class InMemoryAvatarDocs:
    docs: dict[str, dict[str, object]] = field(default_factory=dict)

    def set_frames(self, uid: str, source: str | None, frames_version: int) -> None:
        doc = self.docs.setdefault(uid, {})
        doc.update({"type": "3d_adult", "frames_version": frames_version})
        if source is not None:
            doc["source"] = source


class DailyLimitReached(Exception):
    """Max generations per person per day (Remote Config; default 3)."""


@dataclass
class DailyLimiter:
    jobs: JobStore
    #: Read on every request so a Remote Config change applies at once.
    limit: Callable[[], int] = lambda: 3

    def check(self, uid: str, now: datetime) -> None:
        if self.jobs.count_on(uid, now.date()) >= self.limit():
            raise DailyLimitReached


@dataclass
class JobRunner:
    """Runs one job: prompt → image → safety check, retried once."""

    prompts: PromptBook
    options: OptionBook
    stylizer: AvatarStylizer
    inspector: ImageInspector
    jobs: JobStore
    portraits: PortraitStore
    costs: CostRecorder
    approved_hosts: frozenset[str]
    min_similarity: float = 0.6
    attempts: int = 2
    #: Builds the frame set once the portrait is approved (T-AVT-08d).
    frames: FrameMaker | None = None
    docs: AvatarDocWriter | None = None
    audit: AuditLog | None = None
    clock: Callable[[], datetime] = lambda: datetime.now(UTC)

    def prompt_for(self, job: Job) -> str:
        template = {
            AvatarSource.SELFIE: self.prompts.selfie,
            AvatarSource.BUILT: self.prompts.build,
            AvatarSource.ADJUST: self.prompts.adjust,
        }[job.source]
        return self.options.fill(template, job.options, self.prompts.master)

    def run(self, job: Job, selfie: bytes | None = None) -> Job:
        """Runs [job]. The selfie is only held for this call: it is never
        stored, and the reference to it is dropped when the job ends."""
        try:
            done = self._run(job, selfie)
        except Exception:
            self._audit(job, Events.AVATAR_NOT_MADE, "error")
            raise
        finally:
            if selfie is not None:
                # Only ever in memory: nothing to delete but our reference.
                selfie = None
                self._audit(job, Events.SELFIE_DISCARDED)
        if done.status is JobStatus.SUCCEEDED:
            self._audit(done, Events.AVATAR_CREATED, f"frames_version={done.frames_version}")
        else:
            self._audit(done, Events.AVATAR_NOT_MADE, done.status.value)
        return done

    def _audit(self, job: Job, event: str, detail: str = "") -> None:
        if self.audit is not None:
            self.audit.append(AuditEntry(job.uid, event, job.id, self.clock(), detail))

    def _finish(self, job: Job, status: JobStatus, message: str | None = None) -> Job:
        job.status = status
        job.message_id = message
        job.updated_at = self.clock()
        self.jobs.save(job)
        return job

    def _run(self, job: Job, selfie: bytes | None) -> Job:
        job.status = JobStatus.RUNNING
        self.jobs.save(job)
        reference: bytes | None
        if job.source is AvatarSource.ADJUST:
            current = self.portraits.latest(job.uid)
            if current is None:
                return self._finish(job, JobStatus.FAILED, Messages.NO_PORTRAIT)
            reference = current[1]
        else:
            reference = selfie
        prompt = self.prompt_for(job)
        # Never send a photo to an endpoint we haven't approved. That is a
        # setup mistake: logged loudly, and the person gets the kind message.
        try:
            check_endpoint(self.stylizer.endpoint, self.approved_hosts)
        except EndpointNotApproved:
            log.error("avatar job %s: stylizer endpoint not approved", job.id)
            return self._finish(job, JobStatus.FAILED, Messages.NOT_MADE)
        rejected = False
        for _ in range(self.attempts):
            job.attempts += 1
            try:
                made = self.stylizer.generate(prompt, self.prompts.avoid, reference)
            except StylizerError:
                continue
            self.costs.record(CostEntry(job.uid, job.id, made.model, made.cost_usd, self.clock()))
            verdict = judge(
                self.inspector.inspect(
                    made.image, selfie if job.source is AvatarSource.SELFIE else None
                ),
                selfie=job.source is AvatarSource.SELFIE,
                min_similarity=self.min_similarity,
            )
            if verdict.ok:
                job.portrait_id = self.portraits.put(job.uid, made.image)
                return self._frames(job, made.image)
            rejected = True
            job.rejections = sorted({*job.rejections, *(r.value for r in verdict.reasons)})
        return self._finish(
            job,
            JobStatus.REJECTED if rejected else JobStatus.FAILED,
            Messages.NOT_MADE,
        )

    def _frames(self, job: Job, portrait: bytes) -> Job:
        if self.frames is None:
            return self._finish(job, JobStatus.SUCCEEDED)
        try:
            version = self.frames.build_version(job.uid, portrait, job.id)
        except Exception:  # any failure building frames: a kind message
            return self._finish(job, JobStatus.FAILED, Messages.NOT_MADE)
        job.frames_version = version
        if self.docs is not None:
            # Adjust keeps where the coach came from (selfie or built).
            source = None if job.source is AvatarSource.ADJUST else job.source.value
            self.docs.set_frames(job.uid, source, version)
        return self._finish(job, JobStatus.SUCCEEDED)


def new_job(uid: str, source: AvatarSource, options: dict[str, str], now: datetime) -> Job:
    return Job(
        id=secrets.token_urlsafe(12),
        uid=uid,
        source=source,
        options=options,
        created_at=now,
        updated_at=now,
    )


__all__ = [
    "AvatarSource",
    "CostEntry",
    "DailyLimitReached",
    "DailyLimiter",
    "InMemoryCosts",
    "InMemoryJobs",
    "InMemoryPortraits",
    "Job",
    "JobRunner",
    "JobStatus",
    "Messages",
    "Rejection",
    "new_job",
]
