"""Builds the 14-frame set from the approved portrait (T-AVT-08d).

Every frame is an edit of the same face, made with the frame prompts
(docs/design/avatar-prompts.md, Appendix B): the neutral frame from the
portrait, then every other frame from the neutral one, so the mouth frames
keep its eyes, eyebrows and head. Each frame has its background removed and
is aligned to one canvas with the face in one place; a quality check compares
it with the neutral frame (same face, same position). A failed frame is made
again once, else it falls back to the neutral frame. The set is exported as
WebP at 2x and 3x, plus small PNG expression thumbnails for notifications and
the widget, with avatar_frames.json (packages/schemas/avatar_frames.schema.json).
"""

from __future__ import annotations

import io
import json
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Protocol

from PIL import Image

from .jobs import CostEntry, CostRecorder
from .prompts import FRAMES, PromptBook
from .stylizer import AvatarStylizer, StylizerError, check_endpoint

STYLE = "3d_adult"
#: The 3x canvas, square; 2x is two thirds of it.
CANVAS = 1024
SIZES = {"3x": CANVAS, "2x": round(CANVAS * 2 / 3)}
#: Where the face sits on the canvas: its centre, and its height.
FACE_CENTRE = (0.5, 0.42)
FACE_HEIGHT = 0.34
#: Expression thumbnails (notifications, the widget), PNG for every platform.
THUMB_PX = 192
THUMBNAILS = ("neutral", "happy", "waving", "listening", "calm", "celebrating")


class FramesError(RuntimeError):
    """No usable neutral frame: the set can't be made."""


@dataclass(frozen=True)
class FaceBox:
    """The face's bounding box in an image, in pixels."""

    x: float
    y: float
    w: float
    h: float

    @property
    def centre(self) -> tuple[float, float]:
        return (self.x + self.w / 2, self.y + self.h / 2)


class FaceLocator(Protocol):
    """Finds the one face in an image (a vision model at deploy)."""

    def locate(self, image: Image.Image) -> FaceBox | None: ...


class BackgroundRemover(Protocol):
    """Cuts the person out (transparent background)."""

    def remove(self, image: Image.Image) -> Image.Image: ...


class FrameChecker(Protocol):
    """How alike two frames' faces are, 0 to 1 (same person, same head)."""

    def similarity(self, frame: Image.Image, neutral: Image.Image) -> float: ...


class FrameStore(Protocol):
    """Cloud Storage avatars/{uid}/{version}/ in prod."""

    def next_version(self, uid: str) -> int: ...
    def put(self, uid: str, version: int, name: str, data: bytes) -> None: ...


@dataclass(frozen=True)
class FrameSet:
    uid: str
    version: int
    manifest: dict[str, object]
    #: Frames that failed the check twice and show the neutral face.
    fell_back: tuple[str, ...]


def align(image: Image.Image, face: FaceBox) -> Image.Image:
    """Scales and moves [image] so its face fills [FACE_HEIGHT] of the canvas
    with its centre at [FACE_CENTRE]; the rest stays transparent."""
    scale = (CANVAS * FACE_HEIGHT) / face.h
    resized = image.convert("RGBA").resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    cx, cy = face.centre
    left = round(CANVAS * FACE_CENTRE[0] - cx * scale)
    top = round(CANVAS * FACE_CENTRE[1] - cy * scale)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    # paste handles a face near an edge (negative offsets) too.
    canvas.paste(resized, (left, top), resized)
    return canvas


def face_crop(image: Image.Image) -> Image.Image:
    """The face and shoulders of an aligned frame, square (thumbnails)."""
    side = CANVAS * FACE_HEIGHT * 1.9
    cx, cy = CANVAS * FACE_CENTRE[0], CANVAS * FACE_CENTRE[1]
    box = (
        max(0, round(cx - side / 2)),
        max(0, round(cy - side / 2)),
        min(CANVAS, round(cx + side / 2)),
        min(CANVAS, round(cy + side / 2)),
    )
    return image.crop(box)


def encode(image: Image.Image, px: int, fmt: str) -> bytes:
    out = io.BytesIO()
    resized = image if image.size == (px, px) else image.resize((px, px), Image.Resampling.LANCZOS)
    if fmt == "WEBP":
        # method 4: near the smallest files at a fraction of method 6's time.
        resized.save(out, "WEBP", quality=88, method=4)
    else:
        resized.save(out, "PNG", optimize=True)
    return out.getvalue()


@dataclass
class FrameBuilder:
    prompts: PromptBook
    stylizer: AvatarStylizer
    locator: FaceLocator
    remover: BackgroundRemover
    checker: FrameChecker
    store: FrameStore
    costs: CostRecorder
    approved_hosts: frozenset[str]
    #: Below this the frame is made again (then falls back to neutral).
    min_similarity: float = 0.8
    #: How far (share of the canvas) the aligned face may drift.
    max_drift: float = 0.03
    clock: Callable[[], datetime] = lambda: datetime.now(UTC)
    log: list[str] = field(default_factory=list)

    def _make(self, frame: str, reference: bytes, uid: str, job_id: str) -> Image.Image | None:
        """One frame, cut out and aligned; None when it can't be made."""
        try:
            made = self.stylizer.generate(
                self.prompts.frame_prompt(frame), self.prompts.avoid, reference
            )
        except StylizerError:
            return None
        self.costs.record(CostEntry(uid, job_id, made.model, made.cost_usd, self.clock()))
        image = Image.open(io.BytesIO(made.image))
        image.load()
        cut = self.remover.remove(image)
        face = self.locator.locate(cut)
        if face is None:
            return None
        return align(cut, face)

    def _ok(self, frame: Image.Image, neutral: Image.Image) -> bool:
        face = self.locator.locate(frame)
        if face is None:
            return False
        cx, cy = face.centre
        drift = max(abs(cx / CANVAS - FACE_CENTRE[0]), abs(cy / CANVAS - FACE_CENTRE[1]))
        if drift > self.max_drift:
            return False
        return self.checker.similarity(frame, neutral) >= self.min_similarity

    def build(self, uid: str, portrait: bytes, job_id: str) -> FrameSet:
        check_endpoint(self.stylizer.endpoint, self.approved_hosts)
        neutral = None
        for _ in range(2):
            neutral = self._make("neutral", portrait, uid, job_id)
            if neutral is not None:
                break
        if neutral is None:
            raise FramesError("No neutral frame")
        neutral_bytes = encode(neutral, CANVAS, "PNG")
        images: dict[str, Image.Image] = {"neutral": neutral}
        fell_back: list[str] = []
        for frame in FRAMES:
            if frame == "neutral":
                continue
            made = None
            # Made again once if it fails the check.
            for _ in range(2):
                attempt = self._make(frame, neutral_bytes, uid, job_id)
                if attempt is not None and self._ok(attempt, neutral):
                    made = attempt
                    break
            if made is None:
                fell_back.append(frame)
            images[frame] = made if made is not None else neutral

        version = self.store.next_version(uid)
        files: dict[str, dict[str, str]] = {}
        images["thumb"] = face_crop(neutral)
        for frame in (*FRAMES, "thumb"):
            source = images[frame]
            if frame in fell_back:
                # Point at the neutral files rather than store copies.
                files[frame] = files["neutral"]
                continue
            files[frame] = {}
            for size, px in SIZES.items():
                name = f"{frame}@{size}.webp"
                self.store.put(uid, version, name, encode(source, px, "WEBP"))
                files[frame][size] = name
        thumbnails: dict[str, str] = {}
        for expression in THUMBNAILS:
            name = f"thumb_{expression}.png"
            thumb = face_crop(images[expression])
            self.store.put(uid, version, name, encode(thumb, THUMB_PX, "PNG"))
            thumbnails[expression] = name
        manifest: dict[str, object] = {
            "avatar_id": f"{uid}-{version}",
            "version": version,
            "style": STYLE,
            "canvas": {"width": CANVAS, "height": CANVAS},
            "sizes": list(SIZES),
            "frames": files,
            "thumbnails": thumbnails,
        }
        self.store.put(uid, version, "avatar_frames.json", json.dumps(manifest, indent=2).encode())
        self.log.append(f"frames {uid}/{version}: {len(fell_back)} fell back")
        return FrameSet(uid, version, manifest, tuple(fell_back))

    def build_version(self, uid: str, portrait: bytes, job_id: str) -> int:
        """For the job runner: builds the set, returns its version."""
        return self.build(uid, portrait, job_id).version


@dataclass
class InMemoryFrameStore:
    files: dict[tuple[str, int, str], bytes] = field(default_factory=dict)
    versions: dict[str, int] = field(default_factory=dict)

    def next_version(self, uid: str) -> int:
        self.versions[uid] = self.versions.get(uid, 0) + 1
        return self.versions[uid]

    def put(self, uid: str, version: int, name: str, data: bytes) -> None:
        self.files[(uid, version, name)] = data


class NotConfiguredFaces:
    """No vision model chosen yet: no face is ever found."""

    def locate(self, image: Image.Image) -> FaceBox | None:
        return None


class KeepBackground:
    """Leaves the background as is (the default until a cut-out model is
    chosen; the frames' mint studio background is then kept)."""

    def remove(self, image: Image.Image) -> Image.Image:
        return image.convert("RGBA")
