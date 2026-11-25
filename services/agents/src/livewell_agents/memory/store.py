"""Where memory facts live (users/{uid}/memory_facts; docs/data-model.md).

`MemoryStore` is the port. `InMemoryMemoryStore` serves tests and dev;
`FirestoreMemoryStore` (firebase_store.py) is the real one. Until it is wired
the service refuses memory calls (`NotConfiguredMemoryStore`), so nothing is
silently kept in a process's memory in staging or prod.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Protocol

from livewell_agents.memory.models import MemoryFact, MemoryStatus


class MemoryUnavailable(RuntimeError):
    pass


class FactNotFound(LookupError):
    pass


class MemoryStore(Protocol):
    def list(self, uid: str) -> list[MemoryFact]:
        """Every fact of the person, deleted ones (scrubbed) included."""
        ...

    def add(self, uid: str, fact: MemoryFact) -> None: ...

    def set_status(self, uid: str, fact_id: str, status: MemoryStatus, now: datetime) -> MemoryFact:
        """Change the status. `deleted` also scrubs the text (keeps fact_key)."""
        ...


class NotConfiguredMemoryStore:
    def list(self, uid: str) -> list[MemoryFact]:
        raise MemoryUnavailable("memory store is not configured")

    def add(self, uid: str, fact: MemoryFact) -> None:
        raise MemoryUnavailable("memory store is not configured")

    def set_status(self, uid: str, fact_id: str, status: MemoryStatus, now: datetime) -> MemoryFact:
        raise MemoryUnavailable("memory store is not configured")


def apply_status(fact: MemoryFact, status: MemoryStatus, now: datetime) -> MemoryFact:
    update: dict[str, object] = {"status": status, "updated_at": now}
    if status == "deleted":
        update["fact"] = ""
    return fact.model_copy(update=update)


@dataclass
class InMemoryMemoryStore:
    facts: dict[str, dict[str, MemoryFact]] = field(default_factory=dict)

    def list(self, uid: str) -> list[MemoryFact]:
        return list(self.facts.get(uid, {}).values())

    def add(self, uid: str, fact: MemoryFact) -> None:
        self.facts.setdefault(uid, {})[fact.fact_id] = fact

    def set_status(self, uid: str, fact_id: str, status: MemoryStatus, now: datetime) -> MemoryFact:
        current = self.facts.get(uid, {}).get(fact_id)
        if current is None:
            raise FactNotFound(fact_id)
        updated = apply_status(current, status, now)
        self.facts[uid][fact_id] = updated
        return updated
