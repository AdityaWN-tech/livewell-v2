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
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions

ROOT = Path(__file__).resolve().parents[1]
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

# MediaPipe face mesh indices.
EYES = {
    "right": dict(ring=[33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246],
                  upper=[33, 246, 161, 160, 159, 158, 157, 173, 133],
                  lower=[33, 7, 163, 144, 145, 153, 154, 155, 133]),
    "left": dict(ring=[362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398],
                 upper=[362, 398, 384, 385, 386, 387, 388, 466, 263],
                 lower=[362, 382, 381, 380, 374, 373, 390, 249, 263]),
}
LIPS_INNER_UPPER = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308]
LIPS_INNER_LOWER = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308]
LIPS_OUTER = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185]

#: How each mouth shape opens: (opening as a share of the mouth's width,
#: width scale). E and I are close to a smile; O and U are rounder.
MOUTHS = {
    "mouth_A": (0.20, 1.00),
    "mouth_E": (0.10, 1.04),
    "mouth_I": (0.06, 1.06),
    "mouth_O": (0.19, 0.88),
    "mouth_U": (0.12, 0.82),
}


def landmarks(detector: vision.FaceLandmarker, rgb: np.ndarray) -> np.ndarray:
    res = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
    if not res.face_landmarks:
        raise SystemExit("No face found")
    h, w = rgb.shape[:2]
    return np.array([[p.x * w, p.y * h] for p in res.face_landmarks[0]], dtype=np.float32)


def remove_mark(img: np.ndarray) -> np.ndarray:
    """The generator's sparkle in the bottom-right corner."""
    h, w = img.shape[:2]
    mask = np.zeros((h, w), np.uint8)
    cv2.circle(mask, (int(w * 0.945), int(h * 0.945)), int(w * 0.045), 255, -1)
    return cv2.inpaint(img, mask, 9, cv2.INPAINT_TELEA)


def feather(mask: np.ndarray, px: int) -> np.ndarray:
    k = max(3, px | 1)
    return (cv2.GaussianBlur(mask.astype(np.float32) / 255.0, (k, k), 0))[..., None]


def blend(base: np.ndarray, top: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    return (base.astype(np.float32) * (1 - alpha) + top.astype(np.float32) * alpha).clip(0, 255).astype(np.uint8)


def smooth_curve(pts: np.ndarray, n: int = 40) -> np.ndarray:
    """A smooth line through the points (for the lash line and lip line)."""
    t = np.linspace(0, 1, len(pts))
    tt = np.linspace(0, 1, n)
    return np.stack([np.interp(tt, t, pts[:, 0]), np.interp(tt, t, pts[:, 1])], 1)


def close_eyes(img: np.ndarray, lm: np.ndarray) -> np.ndarray:
    """Closed eyelids: the lid skin just above each eye is drawn down over
    the eye, then a soft lash line where the lids meet."""
    out = img.copy()
    for eye in EYES.values():
        ring = lm[eye["ring"]]
        x0, y0 = ring.min(0)
        x1, y1 = ring.max(0)
        ew, eh = x1 - x0, y1 - y0
        pad = int(max(6, eh * 0.35))
        mask = np.zeros(img.shape[:2], np.uint8)
        cv2.fillPoly(mask, [ring.astype(np.int32)], 255)
        mask = cv2.dilate(mask, np.ones((pad, pad), np.uint8))
        # Lid skin: the band above the eye, moved down over it.
        shift = int(eh * 1.05)
        lid = np.roll(img, shift, axis=0)
        # Shade it a little towards the lash line, like a lid.
        shade = np.zeros(img.shape[:2], np.float32)
        yy = np.arange(img.shape[0], dtype=np.float32)[:, None]
        centre = (y0 + y1) / 2
        shade[:] = np.clip(1 - np.abs(yy - centre) / (eh * 0.9), 0, 1)
        lid = (lid.astype(np.float32) * (1 - 0.10 * shade[..., None])).clip(0, 255)
        out = blend(out, lid, feather(mask, pad * 2 + 1))
        # The lash line: a curve a little below the middle of the eye.
        upper = smooth_curve(lm[eye["upper"]])
        lower = smooth_curve(lm[eye["lower"]])
        line = upper * 0.35 + lower * 0.65
        line[:, 1] += eh * 0.05
        lash = np.zeros(img.shape[:2], np.uint8)
        cv2.polylines(lash, [line.astype(np.int32)], False, 255, max(3, int(eh * 0.13)), cv2.LINE_AA)
        dark = np.full_like(img, (34, 26, 24))
        out = blend(out, dark, feather(lash, max(3, int(eh * 0.12))) * 0.85)
        # A soft crease above the closed lid.
        crease = upper.copy()
        crease[:, 1] -= eh * 0.25
        cm = np.zeros(img.shape[:2], np.uint8)
        cv2.polylines(cm, [crease.astype(np.int32)], False, 255, max(2, int(eh * 0.08)), cv2.LINE_AA)
        out = blend(out, (out.astype(np.float32) * 0.85), feather(cm, max(5, int(eh * 0.3))) * 0.5)
    return out


def mouth_geometry(lm: np.ndarray) -> dict:
    up = smooth_curve(lm[LIPS_INNER_UPPER])
    lo = smooth_curve(lm[LIPS_INNER_LOWER])
    outer = lm[LIPS_OUTER]
    x0, y0 = outer.min(0)
    x1, y1 = outer.max(0)
    return dict(up=up, lo=lo, outer=outer, box=(x0, y0, x1, y1), w=x1 - x0,
                cx=(x0 + x1) / 2, gap=float(np.max(lo[:, 1] - up[:, 1])))


def lip_colour(img: np.ndarray, g: dict) -> np.ndarray:
    """The lower lip's colour (between the inner and outer lip lines)."""
    lo = g["lo"]
    outer_lo = smooth_curve(g["outer"][0:11])
    band = np.vstack([lo, outer_lo[::-1]])
    m = np.zeros(img.shape[:2], np.uint8)
    cv2.fillPoly(m, [band.astype(np.int32)], 255)
    return np.array(cv2.mean(img, m)[:3])


def close_mouth(img: np.ndarray, g: dict) -> np.ndarray:
    """Lips together: the open part (teeth) is filled with lip colour, with a
    soft line where the lips meet."""
    if g["gap"] < g["w"] * 0.03:
        return img.copy()
    inner = np.vstack([g["up"], g["lo"][::-1]])
    m = np.zeros(img.shape[:2], np.uint8)
    cv2.fillPoly(m, [inner.astype(np.int32)], 255)
    m = cv2.dilate(m, np.ones((5, 5), np.uint8))
    filled = cv2.inpaint(img, m, 7, cv2.INPAINT_TELEA)
    colour = lip_colour(img, g)
    tint = np.zeros_like(img)
    tint[:] = colour
    filled = blend(filled, tint, feather(m, 9) * 0.55)
    line = (g["up"] + g["lo"]) / 2
    lm_ = np.zeros(img.shape[:2], np.uint8)
    cv2.polylines(lm_, [line.astype(np.int32)], False, 255, max(3, int(g["w"] * 0.012)), cv2.LINE_AA)
    dark = np.zeros_like(img)
    dark[:] = colour * 0.45
    return blend(filled, dark, feather(lm_, 5) * 0.8)


def open_mouth(img: np.ndarray, g: dict, opening: float, width: float) -> np.ndarray:
    """Opens the mouth by moving the lower lip and jaw down (and narrowing
    for O and U), then shows a dark mouth inside with the upper teeth."""
    h, w = img.shape[:2]
    x0, y0, x1, y1 = g["box"]
    mw = g["w"]
    amp = opening * mw
    cx = g["cx"]
    mid = (g["up"][:, 1].mean() + g["lo"][:, 1].mean()) / 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Horizontal falloff across the mouth, vertical: full below the lips,
    # fading out down the chin.
    fx = np.exp(-(((xx - cx) / (mw * 0.62)) ** 2))
    below = np.clip((yy - mid) / (amp + 1e-3), 0, 1)
    fade = np.exp(-(np.clip(yy - (y1 + amp), 0, None) / (mw * 0.9)) ** 2)
    dy = amp * fx * below * fade
    # Narrow towards the centre (O, U), strongest at the lips.
    near = np.exp(-(((yy - mid) / (mw * 0.35)) ** 2)) * np.exp(-(((xx - cx) / (mw * 0.8)) ** 2))
    dx = (xx - cx) * (1 - 1 / width) * near
    mapx = (xx - dx).astype(np.float32)
    moved = cv2.remap(img, mapx, (yy - dy).astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    # The opening: between the upper lip and the moved lower lip.
    up = g["up"].copy()
    lo = g["lo"].copy()
    up[:, 0] = cx + (up[:, 0] - cx) / width
    lo[:, 0] = cx + (lo[:, 0] - cx) / width
    lo_fx = np.exp(-(((lo[:, 0] - cx) / (mw * 0.62)) ** 2))
    lo[:, 1] += amp * lo_fx
    cavity = np.vstack([up, lo[::-1]])
    m = np.zeros((h, w), np.uint8)
    cv2.fillPoly(m, [cavity.astype(np.int32)], 255)
    # A dark, warm mouth (BGR), a little lighter at the edges, with the
    # tongue's red at the bottom.
    top_y, bot_y = up[:, 1].min(), lo[:, 1].max()
    t = np.clip((yy - top_y) / max(1.0, bot_y - top_y), 0, 1)[..., None]
    deep = np.array([28, 22, 48], np.float32)
    tongue = np.array([70, 70, 150], np.float32)
    inside = deep * (1 - t**3) + tongue * t**3
    edge = np.exp(-(((xx - cx) / (mw * 0.45 / width)) ** 2))[..., None]
    inside = inside * (0.75 + 0.25 * edge)
    out = blend(moved, inside, feather(m, 7))
    # The upper teeth under the upper lip: the portrait's own teeth when it
    # shows them, else a soft white band.
    own_teeth = g["gap"] > mw * 0.03
    teeth_h = g["gap"] * 0.8 if own_teeth else amp * 0.22
    band = np.vstack([up, (up + np.array([0, teeth_h]))[::-1]])
    tm = np.zeros((h, w), np.uint8)
    cv2.fillPoly(tm, [band.astype(np.int32)], 255)
    tm = cv2.bitwise_and(tm, m)
    if not own_teeth and amp < mw * 0.12:
        return out
    if own_teeth:
        teeth = cv2.remap(img, mapx, yy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT).astype(np.float32)
    else:
        teeth = np.zeros((h, w, 3), np.float32)
        teeth[:] = (222, 228, 236)
        teeth *= (1 - 0.18 * np.clip((yy - top_y) / max(1.0, teeth_h), 0, 1))[..., None]
    alpha = feather(tm, 3) * 0.95
    if not own_teeth:
        # Made-up teeth only in the middle, fading towards the corners.
        alpha *= np.exp(-(((xx - cx) / (mw * 0.32 / width)) ** 2))[..., None]
    out = blend(out, teeth, alpha)
    return out


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
