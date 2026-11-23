"""Firebase Admin behind the auth interfaces (same shape as
services/media/src/media/firebase_store.py; a shared Python package for the
two services is a follow-up). Credentials: Application Default Credentials
(Cloud Run service account; locally GOOGLE_APPLICATION_CREDENTIALS). Never in
the repo. Not exercised in CI (the `firebase` extra isn't installed there).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any

from livewell_agents.auth import NotAuthorized
from livewell_agents.insights.models import WeekActivity
from livewell_agents.insights.store import checkin_from, goal_from, habit_log_from, streak_from
from livewell_agents.memory.models import MemoryFact, MemoryStatus
from livewell_agents.memory.store import FactNotFound


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


#: users/{uid}/memory_facts schema version (docs/data-model.md).
MEMORY_SCHEMA_VERSION = 1


@dataclass
class FirestoreMemoryStore:
    """users/{uid}/memory_facts/{fact_id} (T-AGT-05). The server writes with
    the Admin SDK; the rules let the owner only read, save or delete."""

    db: Any

    def _col(self, uid: str) -> Any:
        return self.db.collection("users").document(uid).collection("memory_facts")

    def list(self, uid: str) -> list[MemoryFact]:
        out: list[MemoryFact] = []
        for d in self._col(uid).stream():
            raw = d.to_dict() or {}
            raw.pop("schema_version", None)
            out.append(MemoryFact.model_validate({**raw, "fact_id": d.id}))
        return out

    def add(self, uid: str, fact: MemoryFact) -> None:
        data = fact.model_dump(exclude={"fact_id"})
        data["schema_version"] = MEMORY_SCHEMA_VERSION
        self._col(uid).document(fact.fact_id).create(data)

    def set_status(self, uid: str, fact_id: str, status: MemoryStatus, now: Any) -> MemoryFact:
        ref = self._col(uid).document(fact_id)
        snap = ref.get()
        if not snap.exists:
            raise FactNotFound(fact_id)
        update: dict[str, Any] = {"status": status, "updated_at": now}
        if status == "deleted":
            update["fact"] = ""
        ref.update(update)
        raw = {**(snap.to_dict() or {}), **update}
        raw.pop("schema_version", None)
        return MemoryFact.model_validate({**raw, "fact_id": fact_id})


@dataclass
class FirestoreActivitySource:
    """Reads one week for the Insights Agent (T-AGT-06): checkins/{date},
    habit_logs by date, goals/primary and streaks/current. Read only; only the
    numeric fields and codes are kept (barrier_text is never read out)."""

    db: Any

    def week(self, uid: str, start: date, end: date) -> WeekActivity:
        from google.cloud.firestore_v1.base_query import FieldFilter

        user = self.db.collection("users").document(uid)
        days = [start + timedelta(days=i) for i in range((end - start).days + 1)]
        refs = [user.collection("checkins").document(d.isoformat()) for d in days]
        checkins = [
            c
            for snap in self.db.get_all(refs)
            if snap.exists and (c := checkin_from(snap.id, snap.to_dict() or {})) is not None
        ]
        query = (
            user.collection("habit_logs")
            .where(filter=FieldFilter("date", ">=", start.isoformat()))
            .where(filter=FieldFilter("date", "<=", end.isoformat()))
        )
        logs = [h for d in query.stream() if (h := habit_log_from(d.to_dict() or {})) is not None]
        goal = user.collection("goals").document("primary").get()
        streak = user.collection("streaks").document("current").get()
        return WeekActivity(
            checkins=tuple(checkins),
            habit_logs=tuple(logs),
            goal=goal_from(goal.to_dict() if goal.exists else None),
            streak_days=streak_from(streak.to_dict() if streak.exists else None),
        )
