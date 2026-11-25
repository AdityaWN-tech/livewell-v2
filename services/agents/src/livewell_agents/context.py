"""Where the user context comes from.

This slice reads SYNTHETIC fixtures only (fixtures/synthetic_users.json). D-21:
no agent reads a real person's Why until T-AGT-02 adds the classifier; the
Firestore context loader comes with that task. Outside dev nothing is loaded.
"""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Protocol

from livewell_agents.models import UserContext


class ContextSource(Protocol):
    def load(self, uid: str, local_date: date | None) -> UserContext | None: ...


class NoContextSource:
    """Staging/prod until the real loader exists: nobody has a context."""

    def load(self, uid: str, local_date: date | None) -> UserContext | None:
        return None


class FixtureContextSource:
    def __init__(self, path: Path) -> None:
        raw = json.loads(path.read_text(encoding="utf-8"))
        self._users = {u["uid"]: UserContext.model_validate(u) for u in raw["users"]}

    def load(self, uid: str, local_date: date | None) -> UserContext | None:
        ctx = self._users.get(uid)
        if ctx is None or local_date is None:
            return ctx
        return ctx.model_copy(update={"local_date": local_date})
