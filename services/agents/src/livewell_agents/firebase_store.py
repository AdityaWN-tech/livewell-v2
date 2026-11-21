"""Firebase Admin behind the auth interfaces (same shape as
services/media/src/media/firebase_store.py; a shared Python package for the
two services is a follow-up). Credentials: Application Default Credentials
(Cloud Run service account; locally GOOGLE_APPLICATION_CREDENTIALS). Never in
the repo. Not exercised in CI (the `firebase` extra isn't installed there).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from livewell_agents.auth import NotAuthorized


def firebase_app(project_id: str) -> Any:
    import firebase_admin

    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(options={"projectId": project_id})


@dataclass
class FirebaseAuthenticator:
    app: Any
    require_app_check: bool = True

    def uid_for(self, id_token: str, app_check_token: str) -> str:
        from firebase_admin import app_check, auth

        if not id_token:
            raise NotAuthorized("no ID token")
        try:
            claims = auth.verify_id_token(id_token, app=self.app, check_revoked=True)
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
    """Newest record per consent type wins (append-only users/{uid}/consents)."""

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
    db: Any

    def has(self, uid: str, consents: frozenset[str]) -> bool:
        docs = self.db.collection("users").document(uid).collection("consents").stream()
        current = _latest_granted([d.to_dict() or {} for d in docs])
        return all(current.get(c, False) for c in consents)
