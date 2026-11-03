"""Firebase Admin behind the Media Service's interfaces (T-AVT-08c, D-64):
the caller's ID token (and App Check token), the camera and biometric
consents, and the server-only avatar fields in users/{uid}/avatar/current.

Credentials come from Application Default Credentials: the Cloud Run service
account in prod, a service-account key file (GOOGLE_APPLICATION_CREDENTIALS)
on a developer's computer. Never in the repo.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from .auth import NotAuthorized

log = logging.getLogger("media.firebase")


def firebase_app(project_id: str) -> Any:
    """The default Firebase Admin app for [project_id] (created once)."""
    import firebase_admin

    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(options={"projectId": project_id})


@dataclass
class FirebaseAuthenticator:
    """Checks the Firebase ID token and, unless turned off for local
    development (MEDIA_REQUIRE_APP_CHECK=0), the App Check token."""

    app: Any
    require_app_check: bool = True

    def uid_for(self, id_token: str, app_check_token: str) -> str:
        from firebase_admin import app_check, auth

        if not id_token:
            raise NotAuthorized("no ID token")
        try:
            claims = auth.verify_id_token(id_token, app=self.app)
        except Exception:
            raise NotAuthorized("bad ID token") from None
        if self.require_app_check:
            try:
                app_check.verify_token(app_check_token, app=self.app)
            except Exception:
                raise NotAuthorized("bad App Check token") from None
        uid: str = claims["uid"]
        return uid


def _latest_granted(records: list[dict[str, Any]]) -> dict[str, bool]:
    """Like the app's currentConsents: the newest record per type wins; a
    record without created_at sorts last (it was just written)."""

    def key(r: dict[str, Any]) -> tuple[int, float]:
        at = r.get("created_at")
        return (1, 0.0) if at is None else (0, at.timestamp())

    out: dict[str, bool] = {}
    for r in sorted(records, key=key):
        if isinstance(r.get("type"), str):
            out[r["type"]] = r.get("granted") is True and r.get("revoked_at") is None
    return out


@dataclass
class FirestoreConsents:
    """users/{uid}/consents, append-only (FR-ONB-02/03)."""

    db: Any

    def has(self, uid: str, consents: frozenset[str]) -> bool:
        docs = self.db.collection("users").document(uid).collection("consents").stream()
        current = _latest_granted([d.to_dict() or {} for d in docs])
        return all(current.get(c, False) for c in consents)


@dataclass
class FirestoreAvatarDocs:
    """Writes users/{uid}/avatar/current's server-only fields."""

    db: Any

    def set_frames(self, uid: str, source: str | None, frames_version: int) -> None:
        from google.cloud.firestore import SERVER_TIMESTAMP

        fields: dict[str, Any] = {
            "type": "3d_adult",
            "frames_version": frames_version,
            "raw_media_retained": False,
            "updated_at": SERVER_TIMESTAMP,
        }
        if source is not None:
            # coach_id stays: the rules need a ready-made one there, and the
            # app falls back to it if the frames can't be loaded.
            fields["source"] = source
        doc = self.db.collection("users").document(uid).collection("avatar").document("current")
        doc.set(fields, merge=True)
        log.info("avatar doc updated (frames_version=%s)", frames_version)
