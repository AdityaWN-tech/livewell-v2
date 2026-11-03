"""Free checks that run on this computer (development, D-64): no image leaves
the machine and nothing is paid for.

- Face box and face count: OpenCV's YuNet detector (MIT).
- Likeness of the portrait to the selfie: OpenCV's SFace (Apache-2.0).
- Nudity, violence, text or logos, and a child-looking signal: OpenAI CLIP
  ViT-B/32 (MIT) by zero-shot comparison with fixed descriptions.

These are rough stand-ins for the vendor checks still to be chosen
(avatar-vendor-scorecard.md). CLIP is **not** a reliable age check: it can only
add rejections, and the dev build otherwise relies on the account's 18+ gate
(D-64). Any doubt fails safe, like the other inspectors.

    python -m media.local_checks download D:/ComfyUI-models/media-checks
"""

from __future__ import annotations

import io
import logging
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import httpx
from PIL import Image

from .frames import FaceBox
from .safety import ImageFacts
from .stylizer import AvatarStylizer, Generated

log = logging.getLogger("media")

YUNET = "face_detection_yunet_2023mar.onnx"
SFACE = "face_recognition_sface_2021dec.onnx"
CLIP = "clip-vit-base-patch32"
_ZOO = "https://github.com/opencv/opencv_zoo/raw/main/models"
DOWNLOADS = {
    YUNET: f"{_ZOO}/face_detection_yunet/{YUNET}",
    SFACE: f"{_ZOO}/face_recognition_sface/{SFACE}",
}

#: Zero-shot descriptions. A concern is raised when its share of the
#: softmax over every description passes its limit (set low: fail safe).
SAFE = (
    "a 3D cartoon portrait of an adult person",
    "a cartoon headshot of a smiling grown-up",
    "a photo of an adult's face",
)
CONCERNS: dict[str, tuple[tuple[str, ...], float]] = {
    "nudity": (("a nude person", "a person in underwear", "explicit sexual content"), 0.2),
    "violence": (("blood and gore", "a person holding a weapon", "an injured person"), 0.2),
    "text_or_logo": (
        ("an image with written text or letters", "a brand logo", "a watermark"),
        0.35,
    ),
    "child": (("a cartoon portrait of a child", "a photo of a young kid"), 0.35),
}

#: SFace cosine between a stylised portrait and the real photo, mapped to the
#: inspector's 0..1 scale: LIKENESS_LOW -> 0, LIKENESS_HIGH -> 1. A cartoon
#: scores lower than a photo of the same person; tune on real selfies.
LIKENESS_LOW = 0.05
LIKENESS_HIGH = 0.40


def _cv() -> Any:
    import cv2

    return cv2


def _bgr(image: Image.Image) -> Any:
    import numpy as np

    rgb = np.asarray(image.convert("RGB"))
    return rgb[:, :, ::-1].copy()


@dataclass
class YuNetFaces:
    """Faces in an image, biggest first: (box, the detector's raw row)."""

    models: Path
    min_score: float = 0.7
    _detector: Any = field(default=None, init=False, repr=False)

    def detect(self, image: Image.Image) -> list[tuple[FaceBox, Any]]:
        cv2 = _cv()
        if self._detector is None:
            self._detector = cv2.FaceDetectorYN.create(
                str(self.models / YUNET), "", (320, 320), self.min_score
            )
        bgr = _bgr(image)
        self._detector.setInputSize((bgr.shape[1], bgr.shape[0]))
        _, rows = self._detector.detect(bgr)
        if rows is None:
            return []
        found = [(FaceBox(float(r[0]), float(r[1]), float(r[2]), float(r[3])), r) for r in rows]
        return sorted(found, key=lambda f: f[0].w * f[0].h, reverse=True)

    def locate(self, image: Image.Image) -> FaceBox | None:
        """A FaceLocator: the one face, None when there is none or several."""
        try:
            faces = self.detect(image)
        except Exception:
            log.warning("local face location failed")
            return None
        return faces[0][0] if len(faces) == 1 else None


@dataclass
class SFaceLikeness:
    """How alike two faces are, 0..1 (see LIKENESS_LOW/HIGH)."""

    models: Path
    faces: YuNetFaces
    _model: Any = field(default=None, init=False, repr=False)

    def _feature(self, image: Image.Image) -> Any | None:
        found = self.faces.detect(image)
        if not found:
            return None
        if self._model is None:
            self._model = _cv().FaceRecognizerSF.create(str(self.models / SFACE), "")
        bgr = _bgr(image)
        return self._model.feature(self._model.alignCrop(bgr, found[0][1]))

    def similarity(self, portrait: Image.Image, selfie: Image.Image) -> float:
        a, b = self._feature(portrait), self._feature(selfie)
        if a is None or b is None:
            return 0.0
        cos = float(self._model.match(a, b, _cv().FaceRecognizerSF_FR_COSINE))
        return min(1.0, max(0.0, (cos - LIKENESS_LOW) / (LIKENESS_HIGH - LIKENESS_LOW)))


@dataclass
class ClipConcerns:
    """CLIP zero-shot shares for each concern in CONCERNS."""

    models: Path
    _model: Any = field(default=None, init=False, repr=False)
    _processor: Any = field(default=None, init=False, repr=False)

    def _labels(self) -> list[str]:
        return [*SAFE, *(t for texts, _ in CONCERNS.values() for t in texts)]

    def shares(self, image: Image.Image) -> dict[str, float]:
        import torch
        from transformers import CLIPModel, CLIPProcessor

        if self._model is None:
            model: Any = CLIPModel.from_pretrained(str(self.models / CLIP))
            self._model = model.eval()
            self._processor = CLIPProcessor.from_pretrained(str(self.models / CLIP))
        labels = self._labels()
        inputs = self._processor(
            text=labels, images=image.convert("RGB"), return_tensors="pt", padding=True
        )
        with torch.no_grad():
            probs = self._model(**inputs).logits_per_image.softmax(dim=1)[0].tolist()
        by_label = dict(zip(labels, probs, strict=True))
        return {k: sum(by_label[t] for t in texts) for k, (texts, _) in CONCERNS.items()}

    def raised(self, image: Image.Image) -> set[str]:
        shares = self.shares(image)
        return {k for k, (_, limit) in CONCERNS.items() if shares[k] > limit}


@dataclass
class LocalInspector:
    """An ImageInspector made of the free local checks above."""

    faces: YuNetFaces
    likeness: SFaceLikeness
    concerns: ClipConcerns

    @classmethod
    def from_dir(cls, models: Path) -> LocalInspector:
        faces = YuNetFaces(models)
        return cls(faces, SFaceLikeness(models, faces), ClipConcerns(models))

    def inspect(self, image: bytes, reference: bytes | None) -> ImageFacts:
        try:
            portrait = Image.open(io.BytesIO(image))
            portrait.load()
            raised = self.concerns.raised(portrait)
            similarity = None
            if reference is not None:
                selfie = Image.open(io.BytesIO(reference))
                selfie.load()
                similarity = self.likeness.similarity(portrait, selfie)
            return ImageFacts(
                face_count=len(self.faces.detect(portrait)),
                # Not an age check (D-64): only a rough extra rejection.
                looks_under_18="child" in raised,
                nudity="nudity" in raised,
                violence="violence" in raised,
                text_or_logo="text_or_logo" in raised,
                similarity=similarity,
            )
        except Exception:
            log.warning("local inspection failed; the image is not used")
            return ImageFacts(
                face_count=0,
                looks_under_18=True,
                nudity=False,
                violence=False,
                text_or_logo=False,
            )


#: MediaPipe's face landmarker for the drawn blink and mouth frames.
LANDMARKER = "face_landmarker.task"
DOWNLOADS[LANDMARKER] = (
    "https://storage.googleapis.com/mediapipe-models/face_landmarker/"
    "face_landmarker/float16/1/face_landmarker.task"
)


@dataclass
class SkinToneKeeper:
    """An AvatarStylizer around another: when there is a reference photo,
    moves the portrait's colours so the face's average skin tone (Lab) matches
    the photo's. A restyle must never lighten or darken someone's skin; SD 1.5
    tends to (D-64). Without a face in either image the portrait is unchanged
    and the likeness check decides."""

    inner: AvatarStylizer
    faces: YuNetFaces
    endpoint: str = field(init=False)

    def __post_init__(self) -> None:
        self.endpoint = self.inner.endpoint

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None) -> Generated:
        made = self.inner.generate(prompt, avoid, reference)
        if reference is None:
            return made
        try:
            fixed = self._match(made.image, reference)
        except Exception:
            log.warning("skin tone match failed; portrait unchanged")
            return made
        if fixed is None:
            return made
        return Generated(image=fixed, cost_usd=made.cost_usd, model=made.model)

    def _face_lab(self, image: Image.Image) -> Any | None:
        import numpy as np

        found = self.faces.detect(image)
        if not found:
            return None
        box = found[0][0]
        # The middle of the face: cheeks and nose, not hair, beard or eyes.
        x0, x1 = round(box.x + box.w * 0.25), round(box.x + box.w * 0.75)
        y0, y1 = round(box.y + box.h * 0.45), round(box.y + box.h * 0.70)
        lab = _cv().cvtColor(_bgr(image), _cv().COLOR_BGR2LAB).astype(np.float32)
        patch = lab[max(0, y0) : y1, max(0, x0) : x1]
        return patch.reshape(-1, 3).mean(0) if patch.size else None

    def _match(self, portrait_png: bytes, selfie_bytes: bytes) -> bytes | None:
        import numpy as np

        portrait = Image.open(io.BytesIO(portrait_png)).convert("RGB")
        selfie = Image.open(io.BytesIO(selfie_bytes)).convert("RGB")
        have, want = self._face_lab(portrait), self._face_lab(selfie)
        if have is None or want is None:
            return None
        cv2 = _cv()
        lab = cv2.cvtColor(_bgr(portrait), cv2.COLOR_BGR2LAB).astype(np.float32)
        lab += (want - have)[None, None, :]
        bgr = cv2.cvtColor(lab.clip(0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
        out = io.BytesIO()
        Image.fromarray(bgr[:, :, ::-1]).save(out, "PNG")
        return out.getvalue()


def download(target: Path) -> None:
    """Fetches the model files into [target] (about 650 MB, CLIP mostly)."""
    target.mkdir(parents=True, exist_ok=True)
    for name, url in DOWNLOADS.items():
        if not (target / name).exists():
            print(f"{url} -> {name}")
            r = httpx.get(url, follow_redirects=True, timeout=120)
            r.raise_for_status()
            (target / name).write_bytes(r.content)
    if not (target / CLIP).exists():
        from transformers import CLIPModel, CLIPProcessor

        print(f"openai/{CLIP} -> {CLIP}/")
        CLIPModel.from_pretrained(f"openai/{CLIP}").save_pretrained(target / CLIP)
        CLIPProcessor.from_pretrained(f"openai/{CLIP}").save_pretrained(target / CLIP)


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] != "download":
        print(__doc__)
        raise SystemExit(2)
    download(Path(sys.argv[2]))
