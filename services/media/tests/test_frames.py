"""T-AVT-08d: the 14-frame set from the approved portrait."""

from __future__ import annotations

import io
import json
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

import pytest
from PIL import Image, ImageChops, ImageDraw

from media.frames import (
    CANVAS,
    FACE_CENTRE,
    FACE_HEIGHT,
    SIZES,
    THUMB_PX,
    THUMBNAILS,
    FaceBox,
    FrameBuilder,
    FramesError,
    InMemoryFrameStore,
)
from media.jobs import (
    AvatarSource,
    InMemoryAvatarDocs,
    InMemoryCosts,
    InMemoryJobs,
    InMemoryPortraits,
    JobRunner,
    JobStatus,
    Messages,
    new_job,
)
from media.prompts import FRAMES, OptionBook, PromptBook
from media.safety import FakeInspector
from media.stylizer import EndpointNotApproved, Generated, StylizerError

REPO = Path(__file__).resolve().parents[3]
PROMPTS = PromptBook.load(REPO / "docs" / "design" / "avatar-prompts.md")
OPTIONS = OptionBook.load(REPO / "content" / "avatar" / "options.json")
SCHEMA = json.loads(
    (REPO / "packages" / "schemas" / "avatar_frames.schema.json").read_text(encoding="utf-8")
)
NOW = datetime(2026, 10, 22, 9, 0, tzinfo=UTC)
APPROVED = frozenset({"stylizer.test.livewell"})
MINT = (232, 249, 238)
FACE = (200, 120, 90)
PORTRAIT = b"portrait-bytes"


def picture(face: tuple[int, int, int, int]) -> bytes:
    """A mint picture with one 'face' block (x, y, w, h) on it."""
    im = Image.new("RGB", (900, 900), MINT)
    x, y, w, h = face
    ImageDraw.Draw(im).rectangle((x, y, x + w - 1, y + h - 1), fill=FACE)
    out = io.BytesIO()
    im.save(out, "PNG")
    return out.getvalue()


def frame_of(prompt: str) -> str:
    """Which frame a prompt asks for (by its expression text)."""
    for frame, text in PROMPTS.frame_expressions.items():
        if text in prompt:
            return frame
    raise AssertionError(prompt)


@dataclass
class ImageStylizer:
    """Draws the 'face' in a different place and size per call, so the
    alignment has work to do; [broken] frames fail [fails] times."""

    endpoint: str = "https://stylizer.test.livewell"
    broken: dict[str, int] = field(default_factory=dict)
    calls: list[tuple[str, bytes | None]] = field(default_factory=list)

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None) -> Generated:
        frame = frame_of(prompt)
        self.calls.append((frame, reference))
        if self.broken.get(frame, 0) > 0:
            self.broken[frame] -= 1
            raise StylizerError("broken frame")
        n = len(self.calls)
        return Generated(
            picture((100 + 7 * n, 150 + 5 * n, 200 + 3 * n, 260 + 4 * n)), 0.03, "fake"
        )


class BlockLocator:
    """Finds the 'face' block by its colour (Pillow channel ops, fast)."""

    def locate(self, image: Image.Image) -> FaceBox | None:
        rgba = image.convert("RGBA")
        rgb = rgba.convert("RGB")
        diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, FACE)).convert("L")
        near = diff.point(lambda v: 255 if v < 25 else 0)
        mask = ImageChops.multiply(near, rgba.getchannel("A"))
        box = mask.point(lambda v: 255 if v > 0 else 0).getbbox()
        if box is None:
            return None
        return FaceBox(box[0], box[1], box[2] - box[0], box[3] - box[1])


class MintCutter:
    """Makes the mint studio background transparent."""

    def remove(self, image: Image.Image) -> Image.Image:
        rgb = image.convert("RGB")
        diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, MINT)).convert("L")
        rgba = rgb.convert("RGBA")
        rgba.putalpha(diff.point(lambda v: 255 if v > 0 else 0))
        return rgba


@dataclass
class Checker:
    """Similarity per call, in order; 0.95 when the list runs out."""

    scores: list[float] = field(default_factory=list)

    def similarity(self, frame: Image.Image, neutral: Image.Image) -> float:
        return self.scores.pop(0) if self.scores else 0.95


def builder(
    stylizer: ImageStylizer | None = None,
    checker: Checker | None = None,
) -> tuple[FrameBuilder, InMemoryFrameStore, InMemoryCosts, ImageStylizer]:
    store, costs = InMemoryFrameStore(), InMemoryCosts()
    s = stylizer or ImageStylizer()
    return (
        FrameBuilder(
            prompts=PROMPTS,
            stylizer=s,
            locator=BlockLocator(),
            remover=MintCutter(),
            checker=checker or Checker(),
            store=store,
            costs=costs,
            approved_hosts=APPROVED,
            clock=lambda: NOW,
        ),
        store,
        costs,
        s,
    )


def stored(store: InMemoryFrameStore, name: str, uid: str = "u1", version: int = 1) -> bytes:
    return store.files[(uid, version, name)]


def test_the_whole_set_two_sizes_thumbnails_and_the_manifest() -> None:
    b, store, _, _ = builder()
    result = b.build("u1", PORTRAIT, "job1")
    m = result.manifest
    assert (m["style"], m["version"], m["sizes"]) == ("3d_adult", 1, ["3x", "2x"])
    frames = m["frames"]
    assert isinstance(frames, dict)
    assert list(frames) == [*FRAMES, "thumb"]
    for frame, files in frames.items():
        for size, px in SIZES.items():
            image = Image.open(io.BytesIO(stored(store, files[size])))
            assert image.format == "WEBP", frame
            assert image.size == (px, px), frame
    thumbnails = m["thumbnails"]
    assert isinstance(thumbnails, dict)
    assert list(thumbnails) == list(THUMBNAILS)
    for name in thumbnails.values():
        thumb = Image.open(io.BytesIO(stored(store, name)))
        assert (thumb.format, thumb.size) == ("PNG", (THUMB_PX, THUMB_PX))
    assert json.loads(stored(store, "avatar_frames.json")) == m
    assert result.fell_back == ()


def test_the_manifest_matches_the_schema_the_app_reads() -> None:
    b, _, _, _ = builder()
    m = b.build("u1", PORTRAIT, "job1").manifest
    for key in SCHEMA["required"]:
        assert key in m
    frames_schema = SCHEMA["properties"]["frames"]
    assert set(m["frames"]) == set(frames_schema["required"])  # type: ignore[arg-type]
    assert "thumbnails" in SCHEMA["properties"]


def test_neutral_from_the_portrait_then_every_frame_from_neutral() -> None:
    b, _store, _, s = builder()
    b.build("u1", PORTRAIT, "job1")
    assert s.calls[0] == ("neutral", PORTRAIT)
    neutral_png = s.calls[1][1]
    assert neutral_png is not None and neutral_png.startswith(b"\x89PNG")
    # Mouth frames (and every other one) are edits of the neutral face.
    assert {ref for _, ref in s.calls[1:]} == {neutral_png}
    assert sorted(f for f, _ in s.calls[1:]) == sorted(set(FRAMES) - {"neutral"})


def test_every_frame_is_aligned_to_one_canvas_and_position() -> None:
    b, store, _, _ = builder()
    m = b.build("u1", PORTRAIT, "job1").manifest
    locator = BlockLocator()
    for frame in FRAMES:
        name = m["frames"][frame]["3x"]  # type: ignore[index]
        image = Image.open(io.BytesIO(stored(store, name)))
        face = locator.locate(image)
        assert face is not None, frame
        cx, cy = face.centre
        assert abs(cx / CANVAS - FACE_CENTRE[0]) < 0.01, frame
        assert abs(cy / CANVAS - FACE_CENTRE[1]) < 0.01, frame
        assert abs(face.h / CANVAS - FACE_HEIGHT) < 0.01, frame


def test_the_background_is_removed() -> None:
    b, store, _, _ = builder()
    m = b.build("u1", PORTRAIT, "job1").manifest
    image = Image.open(io.BytesIO(stored(store, m["frames"]["happy"]["3x"])))  # type: ignore[index]
    assert image.mode == "RGBA"
    assert image.getpixel((5, 5))[3] == 0  # type: ignore[index]


def test_a_frame_that_fails_the_check_is_made_again_once() -> None:
    # The first non-neutral frame (happy) fails once, then passes.
    b, _, _, s = builder(checker=Checker([0.3]))
    result = b.build("u1", PORTRAIT, "job1")
    assert result.fell_back == ()
    assert [f for f, _ in s.calls].count("happy") == 2


def test_failing_twice_falls_back_to_neutral() -> None:
    b, _store, costs, s = builder(ImageStylizer(broken={"mouth_O": 2}))
    result = b.build("u1", PORTRAIT, "job1")
    assert result.fell_back == ("mouth_O",)
    frames = result.manifest["frames"]
    assert frames["mouth_O"] == frames["neutral"]  # type: ignore[index]
    # Costs: one per generation that came back (broken calls cost nothing).
    assert len(costs.entries) == len(s.calls) - 2


def test_a_moved_face_fails_the_position_check() -> None:
    b, _, _, _ = builder()
    neutral = Image.new("RGBA", (CANVAS, CANVAS))
    drifted = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ImageDraw.Draw(drifted).rectangle((10, 10, 200, 300), fill=(*FACE, 255))
    assert b._ok(drifted, neutral) is False


def test_no_neutral_frame_no_set() -> None:
    b, store, _, _ = builder(ImageStylizer(broken={"neutral": 2}))
    with pytest.raises(FramesError):
        b.build("u1", PORTRAIT, "job1")
    assert store.files == {}


def test_frames_only_go_to_an_approved_endpoint() -> None:
    b, _, _, s = builder(ImageStylizer(endpoint="https://x.gradio.live/run"))
    with pytest.raises(EndpointNotApproved):
        b.build("u1", PORTRAIT, "job1")
    assert s.calls == []


def test_each_set_gets_the_next_version() -> None:
    b, store, _, _ = builder()
    assert b.build("u1", PORTRAIT, "a").version == 1
    assert b.build("u1", PORTRAIT, "b").version == 2
    assert b.build("u2", PORTRAIT, "c").version == 1
    assert ("u1", 2, "avatar_frames.json") in store.files


# ---------- in the job ---------------------------------------------------------

BUILT = {
    "age_range": "30s",
    "face": "round",
    "skin": "tone_8",
    "eyes": "almond",
    "eyebrows": "thick",
    "nose": "broad",
    "lips": "full",
    "hairstyle": "coily",
    "hair_colour": "black",
}


@dataclass
class PortraitStylizer(ImageStylizer):
    """Portrait prompts get a picture too (not a frame prompt)."""

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None) -> Generated:
        if "Create an original adult" in prompt or "Only change:" in prompt:
            self.calls.append(("portrait", reference))
            return Generated(picture((300, 200, 240, 300)), 0.05, "fake")
        return super().generate(prompt, avoid, reference)


def job_runner() -> tuple[JobRunner, InMemoryAvatarDocs, InMemoryFrameStore]:
    stylizer = PortraitStylizer()
    frames, store, costs, _ = builder(stylizer)
    docs = InMemoryAvatarDocs()
    return (
        JobRunner(
            prompts=PROMPTS,
            options=OPTIONS,
            stylizer=stylizer,
            inspector=FakeInspector(),
            jobs=InMemoryJobs(),
            portraits=InMemoryPortraits(),
            costs=costs,
            approved_hosts=APPROVED,
            frames=frames,
            docs=docs,
            clock=lambda: NOW,
        ),
        docs,
        store,
    )


def test_an_approved_portrait_becomes_a_frame_set_and_the_avatar_doc_points_to_it() -> None:
    runner, docs, store = job_runner()
    job = runner.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert (job.status, job.frames_version) == (JobStatus.SUCCEEDED, 1)
    assert docs.docs["u1"] == {"type": "3d_adult", "source": "built", "frames_version": 1}
    assert job.view()["frames_version"] == 1
    assert ("u1", 1, "neutral@3x.webp") in store.files


def test_adjust_makes_a_new_version_and_keeps_the_source() -> None:
    runner, docs, _ = job_runner()
    runner.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    docs.docs["u1"]["source"] = "selfie"
    adjusted = runner.run(new_job("u1", AvatarSource.ADJUST, {"glasses": "round"}, NOW))
    assert adjusted.frames_version == 2
    assert docs.docs["u1"]["source"] == "selfie"


def test_frames_that_cannot_be_made_end_with_a_kind_message() -> None:
    runner, docs, _ = job_runner()
    assert isinstance(runner.stylizer, ImageStylizer)
    runner.stylizer.broken["neutral"] = 2
    job = runner.run(new_job("u1", AvatarSource.BUILT, BUILT, NOW))
    assert (job.status, job.message_id) == (JobStatus.FAILED, Messages.NOT_MADE)
    assert "u1" not in docs.docs


def test_over_http_a_job_ends_with_a_frame_set() -> None:
    from fastapi.testclient import TestClient

    from media.app import Services, Settings, create_app
    from media.auth import FakeAuthenticator, FakeConsents

    services = Services(
        settings=Settings(approved_hosts=APPROVED),
        auth=FakeAuthenticator(),
        consents=FakeConsents(),
        stylizer=PortraitStylizer(),
        inspector=FakeInspector(),
        locator=BlockLocator(),
        remover=MintCutter(),
        checker=Checker(),
        clock=lambda: NOW,
    )
    client = TestClient(create_app(services))
    auth = {"Authorization": "Bearer token-u1", "X-Firebase-AppCheck": "app-check-ok"}
    job = client.post("/v1/avatar", json={"source": "built", "options": BUILT}, headers=auth)
    status = client.get(f"/v1/avatar/jobs/{job.json()['job_id']}", headers=auth).json()
    assert (status["status"], status["frames_version"]) == ("succeeded", 1)
    assert isinstance(services.docs, InMemoryAvatarDocs)
    assert services.docs.docs["u1"]["frames_version"] == 1
