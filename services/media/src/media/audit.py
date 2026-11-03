"""The audit log (spec 10.2, 16.3; T-AVT-08e): what happened to a person's
selfie and avatar, append-only. Event names, ids and codes only: never the
photo, never anything about the person's health."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Protocol


@dataclass(frozen=True)
class AuditEntry:
    uid: str
    event: str
    job_id: str
    at: datetime
    detail: str = ""


class AuditLog(Protocol):
    """Append-only (BigQuery with a write-only account, or a Cloud Logging
    bucket with a retention lock, at deploy)."""

    def append(self, entry: AuditEntry) -> None: ...


@dataclass
class InMemoryAuditLog:
    entries: list[AuditEntry] = field(default_factory=list)

    def append(self, entry: AuditEntry) -> None:
        self.entries.append(entry)

    def events(self, uid: str) -> list[str]:
        return [e.event for e in self.entries if e.uid == uid]


class Events:
    SELFIE_RECEIVED = "selfie_received"
    SELFIE_DISCARDED = "selfie_discarded"
    AVATAR_CREATED = "avatar_created"
    AVATAR_NOT_MADE = "avatar_not_made"
