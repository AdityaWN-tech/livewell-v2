"""T-AVT-08e: the raw selfie is never kept (FR-AVT-07, spec 16.3), with an
audit trail; liveness is required; the photo goes only to an approved host."""

from __future__ import annotations

import base64
import json

from fastapi.testclient import TestClient
from test_frames import (
    APPROVED,
    NOW,
    BlockLocator,
    Checker,
    MintCutter,
    PortraitStylizer,
    picture,
)

from media.app import Services, Settings, create_app
from media.audit import Events, InMemoryAuditLog
from media.auth import FakeAuthenticator, FakeConsents
from media.frames import InMemoryFrameStore
from media.jobs import InMemoryAvatarDocs, InMemoryCosts, InMemoryJobs, InMemoryPortraits
from media.safety import FakeInspector, ImageFacts

#: A real JPEG, with a marker we can search for anywhere it might be kept.
MARKER = b"SELFIE-MARKER-7d3f"
SELFIE = b"\xff\xd8\xff\xe0" + MARKER + bytes(range(256)) * 20
AUTH = {"Authorization": "Bearer token-u1", "X-Firebase-AppCheck": "app-check-ok"}


class SelfieStylizer(PortraitStylizer):
    """A selfie prompt gets a portrait too."""

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None):  # type: ignore[no-untyped-def]
        if "identity reference" in prompt:
            self.calls.append(("portrait", reference))
            from media.stylizer import Generated

            return Generated(picture((300, 200, 240, 300)), 0.05, "fake")
        return super().generate(prompt, avoid, reference)


def service(
    inspector: FakeInspector | None = None,
    stylizer: SelfieStylizer | None = None,
) -> tuple[TestClient, Services]:
    services = Services(
        settings=Settings(approved_hosts=APPROVED, from_photo_enabled=lambda: True),
        auth=FakeAuthenticator(),
        consents=FakeConsents({"u1": {"camera", "biometric"}}),
        stylizer=stylizer or SelfieStylizer(),
        inspector=inspector or FakeInspector(),
        jobs=InMemoryJobs(),
        portraits=InMemoryPortraits(),
        costs=InMemoryCosts(),
        locator=BlockLocator(),
        remover=MintCutter(),
        checker=Checker(),
        frame_store=InMemoryFrameStore(),
        docs=InMemoryAvatarDocs(),
        audit=InMemoryAuditLog(),
        clock=lambda: NOW,
    )
    return TestClient(create_app(services)), services


def body(**extra: object) -> dict[str, object]:
    return {
        "source": "selfie",
        "liveness": "blink",
        "selfie_jpeg_base64": base64.b64encode(SELFIE).decode(),
        **extra,
    }


def everything_kept(s: Services) -> list[bytes]:
    """Every byte the service keeps after a job, from every store."""
    assert isinstance(s.jobs, InMemoryJobs)
    assert isinstance(s.frame_store, InMemoryFrameStore)
    assert isinstance(s.docs, InMemoryAvatarDocs)
    assert isinstance(s.audit, InMemoryAuditLog)
    kept = [j.model_dump_json().encode() for j in s.jobs.jobs.values()]
    kept += [image for items in s.portraits.portraits.values() for _, image in items]
    kept += list(s.frame_store.files.values())
    kept += [json.dumps(s.docs.docs).encode()]
    kept += [repr(e).encode() for e in s.costs.entries]
    kept += [repr(e).encode() for e in s.audit.entries]
    return kept


def assert_selfie_gone(s: Services) -> None:
    b64 = base64.b64encode(SELFIE)
    for item in everything_kept(s):
        assert MARKER not in item
        assert SELFIE not in item
        assert b64 not in item


def test_a_made_coach_keeps_no_trace_of_the_selfie() -> None:
    c, s = service()
    r = c.post("/v1/avatar", json=body(), headers=AUTH)
    assert r.status_code == 202
    job = c.get(f"/v1/avatar/jobs/{r.json()['job_id']}", headers=AUTH).json()
    assert (job["status"], job["frames_version"]) == ("succeeded", 1)
    assert_selfie_gone(s)
    assert isinstance(s.audit, InMemoryAuditLog)
    assert s.audit.events("u1") == [
        Events.SELFIE_RECEIVED,
        Events.SELFIE_DISCARDED,
        Events.AVATAR_CREATED,
    ]
    assert s.audit.entries[0].detail == "liveness=blink"
    assert isinstance(s.docs, InMemoryAvatarDocs)
    assert s.docs.docs["u1"]["source"] == "selfie"


def test_a_rejected_result_keeps_no_trace_either() -> None:
    not_them = ImageFacts(1, False, False, False, False, similarity=0.2)
    c, s = service(inspector=FakeInspector([not_them]))
    r = c.post("/v1/avatar", json=body(), headers=AUTH)
    job = c.get(f"/v1/avatar/jobs/{r.json()['job_id']}", headers=AUTH).json()
    assert (job["status"], job["message_id"]) == ("rejected", "avatar_not_made")
    assert_selfie_gone(s)
    assert isinstance(s.audit, InMemoryAuditLog)
    assert s.audit.events("u1") == [
        Events.SELFIE_RECEIVED,
        Events.SELFIE_DISCARDED,
        Events.AVATAR_NOT_MADE,
    ]


def test_frames_that_cannot_be_made_keep_no_trace() -> None:
    stylizer = SelfieStylizer(broken={"neutral": 2})
    c, s = service(stylizer=stylizer)
    r = c.post("/v1/avatar", json=body(), headers=AUTH)
    job = c.get(f"/v1/avatar/jobs/{r.json()['job_id']}", headers=AUTH).json()
    assert job["status"] == "failed"
    assert_selfie_gone(s)


def test_an_unapproved_host_never_gets_the_selfie_and_it_is_still_discarded() -> None:
    stylizer = SelfieStylizer(endpoint="https://x.gradio.live/run")
    c, s = service(stylizer=stylizer)
    r = c.post("/v1/avatar", json=body(), headers=AUTH)
    job = c.get(f"/v1/avatar/jobs/{r.json()['job_id']}", headers=AUTH).json()
    assert (job["status"], job["message_id"]) == ("failed", "avatar_not_made")
    assert stylizer.calls == []
    assert_selfie_gone(s)
    assert isinstance(s.audit, InMemoryAuditLog)
    assert Events.SELFIE_DISCARDED in s.audit.events("u1")


def test_liveness_is_required_for_a_selfie() -> None:
    c, s = service()
    r = c.post("/v1/avatar", json=body(liveness=None), headers=AUTH)
    assert (r.status_code, r.json()["detail"]) == (422, "liveness_required")
    bad = c.post("/v1/avatar", json=body(liveness="smile"), headers=AUTH)
    assert bad.status_code == 422
    assert isinstance(s.jobs, InMemoryJobs)
    assert s.jobs.jobs == {}


def test_revoked_consent_stops_it_on_the_server() -> None:
    c, s = service()
    assert isinstance(s.consents, FakeConsents)
    s.consents.granted["u1"] = {"camera"}
    r = c.post("/v1/avatar", json=body(), headers=AUTH)
    assert (r.status_code, r.json()["detail"]) == (403, "consent_required")
