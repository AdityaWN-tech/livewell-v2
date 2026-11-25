"""The Media Service asks core-api for a push when a coach job ends
(T-TCH-01, D-77): a push_outbox request with only who, which category and
which job. The words, consent, quiet hours and the daily cap are core-api's
(services/core-api/src/push)."""

from __future__ import annotations

from typing import Any

from media.firebase_store import FirestorePushOutbox


class _Doc:
    def __init__(self, store: dict[str, dict[str, Any]], path: str) -> None:
        self.store, self.path = store, path

    def set(self, data: dict[str, Any]) -> None:
        self.store[self.path] = data


class _Collection:
    def __init__(self, store: dict[str, dict[str, Any]], name: str) -> None:
        self.store, self.name = store, name

    def document(self, doc_id: str) -> _Doc:
        return _Doc(self.store, f"{self.name}/{doc_id}")


class FakeDb:
    def __init__(self) -> None:
        self.docs: dict[str, dict[str, Any]] = {}

    def collection(self, name: str) -> _Collection:
        return _Collection(self.docs, name)


def test_a_finished_job_asks_for_a_generic_push() -> None:
    db = FakeDb()
    outbox = FirestorePushOutbox(db, now=lambda: "server-time")
    outbox.job_done("u1", "Ab_c-12", made=True)
    outbox.job_done("u1", "Zz9", made=False)
    assert db.docs == {
        "push_outbox/coach_Ab_c-12": {
            "uid": "u1",
            "category": "coach_ready",
            "ref_id": "Ab_c-12",
            "created_at": "server-time",
        },
        "push_outbox/coach_Zz9": {
            "uid": "u1",
            "category": "coach_not_made",
            "ref_id": "Zz9",
            "created_at": "server-time",
        },
    }


def test_the_request_has_no_words_or_personal_data() -> None:
    db = FakeDb()
    FirestorePushOutbox(db, now=lambda: None).job_done("u1", "job1", made=True)
    (request,) = db.docs.values()
    assert set(request) == {"uid", "category", "ref_id", "created_at"}


def test_the_same_job_asks_once() -> None:
    db = FakeDb()
    outbox = FirestorePushOutbox(db, now=lambda: None)
    outbox.job_done("u1", "job1", made=True)
    outbox.job_done("u1", "job1", made=True)
    assert len(db.docs) == 1
