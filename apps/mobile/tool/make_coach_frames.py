"""Builds the 8 ready-made coaches' frame sets from one portrait each
(T-AVT-08b art, the owner's Gemini portraits in docs/design/).

For each coach: removes the generator's corner mark, finds the eyes and lips
with MediaPipe's face landmarker, and makes the frames the coach engine plays
(T-AVT-08a): the neutral face (also used for the expressions, which move in
code: cheer, wave, lean, breathe), a blink with closed eyelids, and the mouth
shapes A, E, I, O, U and closed. Frames are aligned like the server's sets
(face centre at 50%/42%, face height 34% of a 1024 canvas) and written as
WebP at 2x (512 px) to assets/avatar/frames/coaches/<id>/ with
avatar_frames.json. Expression pictures made later (Gemini, the prompts in
docs/design/coach-frames-gemini.md) replace the generated ones: drop
<id>_<frame>.png in docs/design/coaches/ and run again.

    python tool/make_coach_frames.py <face_landmarker.task> [coach ...]

The face_landmarker.task model (Google MediaPipe, Apache-2.0):
https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import cv2
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions

ROOT = Path(__file__).resolve().parents[1]
# The drawing lives in the Media Service (it draws users' frames too, D-64).
sys.path.insert(0, str(ROOT.parents[1] / "services" / "media" / "src"))
from media.drawn_frames import MOUTHS, close_eyes, close_mouth, landmarks, mouth_geometry, open_mouth  # noqa: E402
DESIGN = ROOT.parents[1] / "docs" / "design" / "coaches"
OUT = ROOT / "assets" / "avatar" / "frames" / "coaches"

#: The owner's portraits (Gemini, 2026-10-24), saved without the
#: generator's corner mark as docs/design/coaches/<id>.webp (Appendix C).
COACHES = [
    "brown_hair", "long_black_hair", "green_hijab", "navy_turban",
    "grey_glasses", "short_curls", "short_black_hair", "wheelchair",
]

FRAMES = [
    "neutral", "happy", "waving", "listening", "calm", "celebrating", "blink",
    "mouth_A", "mouth_I", "mouth_U", "mouth_E", "mouth_O", "mouth_closed", "thumb",
]
PX = 512
CANVAS = 1024
FACE_CENTRE = (0.5, 0.42)
FACE_HEIGHT = 0.34

def remove_mark(img: np.ndarray) -> np.ndarray:
    """The generator's sparkle in the bottom-right corner."""
    h, w = img.shape[:2]
    mask = np.zeros((h, w), np.uint8)
    cv2.circle(mask, (int(w * 0.945), int(h * 0.945)), int(w * 0.045), 255, -1)
    return cv2.inpaint(img, mask, 9, cv2.INPAINT_TELEA)


def crop(img: np.ndarray, lm: np.ndarray, px: int = PX) -> np.ndarray:
    """Aligned like the server's frame sets: face centre at 50%/42%, face
    height 34% of the canvas, or a little larger when the portrait doesn't
    reach that far (never stretched edges)."""
    x0, y0 = lm.min(0)
    x1, y1 = lm.max(0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    h, w = img.shape[:2]
    fits = min(2 * cx, 2 * (w - cx), cy / FACE_CENTRE[1], (h - cy) / (1 - FACE_CENTRE[1]))
    side = min((y1 - y0) / FACE_HEIGHT, fits)
    left, top = cx - side * FACE_CENTRE[0], cy - side * FACE_CENTRE[1]
    m = np.array([[px / side, 0, -left * px / side], [0, px / side, -top * px / side]], np.float32)
    return cv2.warpAffine(img, m, (px, px), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)


def face_crop(img: np.ndarray, lm: np.ndarray, px: int = PX) -> np.ndarray:
    """The thumbnail: the face, a little loose."""
    x0, y0 = lm.min(0)
    x1, y1 = lm.max(0)
    side = (y1 - y0) * 1.35
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - (y1 - y0) * 0.05
    m = np.array([[px / side, 0, -(cx - side / 2) * px / side], [0, px / side, -(cy - side / 2) * px / side]], np.float32)
    return cv2.warpAffine(img, m, (px, px), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)


def frames_for(img: np.ndarray, lm: np.ndarray, own: dict[str, np.ndarray]) -> dict[str, np.ndarray]:
    g = mouth_geometry(lm)
    out = {name: img for name in ["neutral", "happy", "waving", "listening", "calm", "celebrating"]}
    out["blink"] = close_eyes(img, lm)
    out["mouth_closed"] = close_mouth(img, g)
    for name, (opening, width) in MOUTHS.items():
        out[name] = open_mouth(img, g, opening, width)
    # Pictures made by hand (Gemini) replace the generated ones.
    out.update(own)
    return out


def main() -> None:
    model = sys.argv[1]
    only = set(sys.argv[2:])
    detector = vision.FaceLandmarker.create_from_options(
        vision.FaceLandmarkerOptions(base_options=BaseOptions(model_asset_path=model), num_faces=1)
    )
    for coach in COACHES:
        if only and coach not in only:
            continue
        img = remove_mark(cv2.imread(str(DESIGN / f"{coach}.webp")))
        lm = landmarks(detector, cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        if lm is None:
            raise SystemExit(f"{coach}: no face found")
        own = {}
        for frame in FRAMES:
            extra = DESIGN / f"{coach}_{frame}.png"
            if extra.exists():
                own[frame] = remove_mark(cv2.imread(str(extra)))
        frames = frames_for(img, lm, own)
        out = OUT / coach
        out.mkdir(parents=True, exist_ok=True)
        files = {}
        for frame in FRAMES:
            picture = face_crop(frames["neutral"], lm) if frame == "thumb" else crop(frames[frame], lm)
            name = f"{frame}@2x.webp"
            cv2.imwrite(str(out / name), picture, [cv2.IMWRITE_WEBP_QUALITY, 82])
            files[frame] = {"2x": name}
        manifest = {
            "avatar_id": coach,
            "version": 2,
            "style": "3d_adult",
            "canvas": {"width": CANVAS, "height": CANVAS},
            "sizes": ["2x"],
            "note": (
                "Ready-made coach from the owner's portrait (Gemini, docs/design). Blink and mouth "
                "shapes made by tool/make_coach_frames.py until hand-made frames replace them; "
                "expressions move in code. Dev builds only until the art is final (licence review)."
            ),
            "frames": files,
        }
        (out / "avatar_frames.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(coach, "ok", "own:", sorted(own))


if __name__ == "__main__":
    main()
