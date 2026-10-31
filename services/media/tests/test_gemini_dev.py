"""D-64: Gemini as the image method, Firebase checks, and frame sets on the
service's own disk with signed links (development without Cloud Storage)."""

from __future__ import annotations

import base64
import io
import json
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

from media.app import Services, Settings, create_app
from media.auth import FakeAuthenticator, FakeConsents
from media.firebase_store import _latest_granted
from media.frames import CANVAS, FACE_CENTRE, FACE_HEIGHT, PixelFrameChecker
from media.gemini import (
    ENDPOINT,
    GeminiClient,
    GeminiError,
    GeminiFaceLocator,
    GeminiInspector,
    GeminiStylizer,
)
from media.local_files import FrameLinks, LocalFrameStore, valid_name
from media.stylizer import EndpointNotApproved

HOST = "generativelanguage.googleapis.com"
APPROVED = frozenset({HOST})
JPEG = b"\xff\xd8\xff\xe0selfie"


def png() -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (8, 8), "white").save(out, "PNG")
    return out.getvalue()


def gemini(
    answer: Callable[[httpx.Request], httpx.Response], approved: frozenset[str] = APPROVED
) -> tuple[GeminiClient, list[httpx.Request]]:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return answer(request)

    return GeminiClient("k-secret", approved, transport=httpx.MockTransport(handler)), seen


def text_answer(payload: dict[str, Any]) -> Callable[[httpx.Request], httpx.Response]:
    body = {"candidates": [{"content": {"parts": [{"text": json.dumps(payload)}]}}]}
    return lambda _: httpx.Response(200, json=body)


# ---------- the stylizer -----------------------------------------------------


def test_stylizer_sends_the_prompt_and_selfie_and_returns_the_image() -> None:
    image = png()
    body = {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {"text": "here"},
                        {
                            "inlineData": {
                                "mimeType": "image/png",
                                "data": base64.b64encode(image).decode(),
                            }
                        },
                    ]
                }
            }
        ]
    }
    client, seen = gemini(lambda _: httpx.Response(200, json=body))
    made = GeminiStylizer(client).generate("make a 3D portrait", "text, logos", JPEG)
    assert made.image == image
    assert made.model == "gemini-2.5-flash-image"
    assert made.cost_usd > 0
    request = seen[0]
    assert request.url.host == HOST
    assert request.url.path.endswith("gemini-2.5-flash-image:generateContent")
    assert request.headers["x-goog-api-key"] == "k-secret"
    sent = json.loads(request.content)
    parts = sent["contents"][0]["parts"]
    assert "make a 3D portrait" in parts[0]["text"]
    assert "Do not include: text, logos" in parts[0]["text"]
    assert parts[1]["inline_data"] == {
        "mime_type": "image/jpeg",
        "data": base64.b64encode(JPEG).decode(),
    }
    assert sent["generationConfig"]["responseModalities"] == ["IMAGE"]


def test_the_key_is_never_in_the_repr() -> None:
    client, _ = gemini(lambda _: httpx.Response(200))
    assert "k-secret" not in repr(client)
    assert "k-secret" not in repr(GeminiStylizer(client))


@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(429, json={"error": "quota"}),
        httpx.Response(200, json={"promptFeedback": {"blockReason": "SAFETY"}}),
        httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": "no"}]}}]}),
    ],
)
def test_stylizer_failures_are_stylizer_errors(response: httpx.Response) -> None:
    client, _ = gemini(lambda _: response)
    with pytest.raises(GeminiError):
        GeminiStylizer(client).generate("p", "", JPEG)


def test_nothing_is_sent_unless_gemini_is_approved() -> None:
    client, seen = gemini(lambda _: httpx.Response(200), approved=frozenset())
    with pytest.raises(EndpointNotApproved):
        GeminiStylizer(client).generate("p", "", JPEG)
    assert seen == []


def test_only_images_are_sent() -> None:
    client, seen = gemini(lambda _: httpx.Response(200))
    with pytest.raises(GeminiError):
        GeminiStylizer(client).generate("p", "", b"not an image")
    assert seen == []


# ---------- the inspector ----------------------------------------------------


def test_inspector_reads_the_facts_and_the_likeness() -> None:
    client, seen = gemini(
        text_answer(
            {
                "face_count": 1,
                "looks_under_18": False,
                "nudity": False,
                "violence": False,
                "text_or_logo": False,
                "similarity": 0.82,
            }
        )
    )
    facts = GeminiInspector(client).inspect(png(), JPEG)
    assert facts.face_count == 1
    assert facts.similarity == pytest.approx(0.82)
    sent = json.loads(seen[0].content)
    assert seen[0].url.path.endswith("gemini-2.5-flash:generateContent")
    # The portrait, then the selfie to compare with.
    assert len(sent["contents"][0]["parts"]) == 3
    assert sent["generationConfig"]["responseMimeType"] == "application/json"


def test_inspector_without_a_selfie_has_no_likeness() -> None:
    client, seen = gemini(
        text_answer(
            {
                "face_count": 1,
                "looks_under_18": False,
                "nudity": False,
                "violence": False,
                "text_or_logo": False,
                "similarity": 0.9,
            }
        )
    )
    assert GeminiInspector(client).inspect(png(), None).similarity is None
    assert len(json.loads(seen[0].content)["contents"][0]["parts"]) == 2


@pytest.mark.parametrize(
    "answer",
    [
        lambda _: httpx.Response(500),
        text_answer({"face_count": 1}),
        lambda _: httpx.Response(
            200, json={"candidates": [{"content": {"parts": [{"text": "not json"}]}}]}
        ),
    ],
)
def test_inspector_fails_safe(answer: Callable[[httpx.Request], httpx.Response]) -> None:
    client, _ = gemini(answer)
    facts = GeminiInspector(client).inspect(png(), JPEG)
    # No face and child-looking: safety.judge rejects it.
    assert facts.face_count == 0
    assert facts.looks_under_18


# ---------- the face locator -------------------------------------------------


def test_locator_scales_the_box_to_the_image() -> None:
    client, _ = gemini(text_answer({"found": True, "box_2d": [100, 250, 500, 750]}))
    face = GeminiFaceLocator(client).locate(Image.new("RGBA", (1000, 800)))
    assert face is not None
    assert (face.x, face.y, face.w, face.h) == pytest.approx((250, 80, 500, 320))


@pytest.mark.parametrize(
    "payload",
    [
        {"found": False, "box_2d": []},
        {"found": True, "box_2d": [500, 500, 100, 100]},
        {"found": True, "box_2d": [0, 0, 2000, 10]},
        {"found": True, "box_2d": [1, 2]},
    ],
)
def test_locator_returns_none_for_no_or_a_bad_box(payload: dict[str, Any]) -> None:
    client, _ = gemini(text_answer(payload))
    assert GeminiFaceLocator(client).locate(Image.new("RGBA", (64, 64))) is None


# ---------- the frame check --------------------------------------------------


def face_canvas(mouth: int = 10, shift: int = 0) -> Image.Image:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    cx, cy = CANVAS * FACE_CENTRE[0] + shift, CANVAS * FACE_CENTRE[1]
    r = CANVAS * FACE_HEIGHT / 2
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(220, 180, 150, 255))
    draw.ellipse((cx - 80, cy - 60, cx - 40, cy - 20), fill=(30, 30, 30, 255))
    draw.ellipse((cx + 40, cy - 60, cx + 80, cy - 20), fill=(30, 30, 30, 255))
    draw.rectangle((cx - 50, cy + 70, cx + 50, cy + 70 + mouth), fill=(120, 40, 40, 255))
    return image


def test_pixel_check_passes_a_mouth_change_and_fails_a_moved_head() -> None:
    check = PixelFrameChecker()
    neutral = face_canvas()
    assert check.similarity(neutral, neutral) == pytest.approx(1.0)
    assert check.similarity(face_canvas(mouth=30), neutral) >= 0.8
    assert check.similarity(face_canvas(shift=200), neutral) < 0.8


# ---------- frame sets on disk, signed links --------------------------------


def test_local_store_versions_and_refuses_odd_names(tmp_path: Path) -> None:
    store = LocalFrameStore(tmp_path)
    assert store.next_version("u1") == 1
    store.put("u1", 1, "neutral@3x.webp", b"x")
    assert store.next_version("u1") == 2
    assert store.names("u1", 1) == ["neutral@3x.webp"]
    for name in ("../secret.json", "a/b.png", "x.exe", "NEUTRAL.webp"):
        assert not valid_name(name)
        with pytest.raises(ValueError):
            store.put("u1", 1, name, b"x")
    with pytest.raises(ValueError):
        store.put("../u2", 1, "neutral@3x.webp", b"x")


def test_links_expire_and_are_bound_to_the_file() -> None:
    now = [1000.0]
    links = FrameLinks(b"k" * 32, ttl_s=60, clock=lambda: now[0])
    path = links.path("u1", 2, "neutral@3x.webp")
    query = dict(p.split("=") for p in path.split("?")[1].split("&"))
    exp, sig = int(query["exp"]), query["sig"]
    assert links.ok("u1", 2, "neutral@3x.webp", exp, sig)
    assert not links.ok("u2", 2, "neutral@3x.webp", exp, sig)
    assert not links.ok("u1", 3, "neutral@3x.webp", exp, sig)
    assert not links.ok("u1", 2, "happy@3x.webp", exp, sig)
    assert not links.ok("u1", 2, "neutral@3x.webp", exp + 1, sig)
    now[0] = 1061
    assert not links.ok("u1", 2, "neutral@3x.webp", exp, sig)


def frame_client(tmp_path: Path) -> tuple[TestClient, LocalFrameStore]:
    store = LocalFrameStore(tmp_path)
    store.put("u1", 1, "avatar_frames.json", b"{}")
    store.put("u1", 1, "neutral@3x.webp", b"RIFF....WEBP")
    services = Services(
        settings=Settings(approved_hosts=APPROVED),
        auth=FakeAuthenticator(),
        consents=FakeConsents(),
        local_frames=store,
        frame_store=store,
        links=FrameLinks(b"k" * 32),
        build_frames=False,
        clock=lambda: datetime(2026, 10, 31, tzinfo=UTC),
    )
    return TestClient(create_app(services)), store


def auth(uid: str = "u1") -> dict[str, str]:
    return {"Authorization": f"Bearer token-{uid}", "X-Firebase-AppCheck": "app-check-ok"}


def test_owner_gets_signed_links_that_download_the_files(tmp_path: Path) -> None:
    http, _ = frame_client(tmp_path)
    assert http.get("/v1/avatar/frames/1").status_code == 401
    links = http.get("/v1/avatar/frames/1", headers=auth()).json()
    assert set(links) == {"avatar_frames.json", "neutral@3x.webp"}
    r = http.get("/" + links["neutral@3x.webp"])
    assert r.status_code == 200
    assert r.content == b"RIFF....WEBP"
    assert r.headers["content-type"] == "image/webp"
    assert http.get("/" + links["avatar_frames.json"]).headers["content-type"] == (
        "application/json"
    )


def test_someone_else_gets_no_links_and_a_tampered_link_fails(tmp_path: Path) -> None:
    http, _ = frame_client(tmp_path)
    assert http.get("/v1/avatar/frames/1", headers=auth("u2")).status_code == 404
    link = http.get("/v1/avatar/frames/1", headers=auth()).json()["neutral@3x.webp"]
    assert http.get("/" + link.replace("/u1/", "/u2/")).status_code == 404
    assert http.get("/" + link.replace("neutral@3x", "happy@3x")).status_code == 404
    assert http.get("/" + link[:-4] + "0000").status_code == 404


def test_no_frame_endpoints_without_local_frames() -> None:
    services = Services(auth=FakeAuthenticator(), build_frames=False)
    http = TestClient(create_app(services))
    assert http.get("/v1/avatar/frames/1", headers=auth()).status_code == 404


# ---------- configuration from the environment ------------------------------


def test_gemini_is_configured_from_a_key_file(tmp_path: Path) -> None:
    key = tmp_path / "key"
    key.write_text("k-from-file\n")
    s = Services.from_env(
        {
            "MEDIA_GEMINI_API_KEY_FILE": str(key),
            "MEDIA_APPROVED_HOSTS": HOST,
            "MEDIA_FRAMES_DIR": str(tmp_path / "frames"),
            "MEDIA_FROM_PHOTO": "1",
        }
    )
    assert isinstance(s.stylizer, GeminiStylizer)
    assert s.stylizer.endpoint == ENDPOINT
    assert s.stylizer.client.api_key == "k-from-file"
    assert isinstance(s.inspector, GeminiInspector)
    assert isinstance(s.locator, GeminiFaceLocator)
    assert isinstance(s.checker, PixelFrameChecker)
    assert s.frame_store is s.local_frames
    assert s.settings.from_photo_enabled()


def test_from_photo_stays_off_unless_turned_on() -> None:
    assert not Services.from_env({}).settings.from_photo_enabled()


# ---------- consents ---------------------------------------------------------


def test_latest_consent_record_wins() -> None:
    t = lambda h: datetime(2026, 10, 31, h, tzinfo=UTC)  # noqa: E731
    current = _latest_granted(
        [
            {"type": "camera", "granted": True, "created_at": t(1)},
            {"type": "camera", "granted": False, "created_at": t(2)},
            {"type": "biometric", "granted": False, "created_at": t(1)},
            {"type": "biometric", "granted": True, "created_at": None},
            {"type": "notifications", "granted": True, "created_at": t(1), "revoked_at": t(2)},
        ]
    )
    assert current == {"camera": False, "biometric": True, "notifications": False}
