"""Blink and mouth frames drawn from one portrait (no image model): MediaPipe's
face landmarker finds the eyes and lips, then the lids are drawn closed and the
mouth is opened into each shape. Used by the ready-made coaches' tool
(apps/mobile/tool/make_coach_frames.py) and, in development, by the Media
Service for "From my photo" (D-64): one AI portrait, the rest drawn, and the
expressions move in code like the ready-made coaches.

Images are OpenCV BGR arrays. The landmarker model is Google MediaPipe's
face_landmarker.task (Apache-2.0):
https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
"""

# mypy: ignore-errors
# Ported as-is from the coaches' tool, which is tuned by eye.

from __future__ import annotations

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision

# MediaPipe face mesh indices.
EYES = {
    "right": dict(
        ring=[33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246],
        upper=[33, 246, 161, 160, 159, 158, 157, 173, 133],
        lower=[33, 7, 163, 144, 145, 153, 154, 155, 133],
    ),
    "left": dict(
        ring=[362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398],
        upper=[362, 398, 384, 385, 386, 387, 388, 466, 263],
        lower=[362, 382, 381, 380, 374, 373, 390, 249, 263],
    ),
}
LIPS_INNER_UPPER = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308]
LIPS_INNER_LOWER = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308]
LIPS_OUTER = [
    61,
    146,
    91,
    181,
    84,
    17,
    314,
    405,
    321,
    375,
    291,
    409,
    270,
    269,
    267,
    0,
    37,
    39,
    40,
    185,
]

#: How each mouth shape opens: (opening as a share of the mouth's width,
#: width scale). E and I are close to a smile; O and U are rounder.
MOUTHS = {
    "mouth_A": (0.20, 1.00),
    "mouth_E": (0.10, 1.04),
    "mouth_I": (0.06, 1.06),
    "mouth_O": (0.19, 0.88),
    "mouth_U": (0.12, 0.82),
}


def landmarks(detector: vision.FaceLandmarker, rgb: np.ndarray) -> np.ndarray | None:
    res = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
    if not res.face_landmarks:
        return None
    h, w = rgb.shape[:2]
    return np.array([[p.x * w, p.y * h] for p in res.face_landmarks[0]], dtype=np.float32)


def feather(mask: np.ndarray, px: int) -> np.ndarray:
    k = max(3, px | 1)
    return (cv2.GaussianBlur(mask.astype(np.float32) / 255.0, (k, k), 0))[..., None]


def blend(base: np.ndarray, top: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    return (
        (base.astype(np.float32) * (1 - alpha) + top.astype(np.float32) * alpha)
        .clip(0, 255)
        .astype(np.uint8)
    )


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
        _, y0 = ring.min(0)
        _, y1 = ring.max(0)
        eh = y1 - y0
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
        cv2.polylines(
            lash, [line.astype(np.int32)], False, 255, max(3, int(eh * 0.13)), cv2.LINE_AA
        )
        dark = np.full_like(img, (34, 26, 24))
        out = blend(out, dark, feather(lash, max(3, int(eh * 0.12))) * 0.85)
        # A soft crease above the closed lid.
        crease = upper.copy()
        crease[:, 1] -= eh * 0.25
        cm = np.zeros(img.shape[:2], np.uint8)
        cv2.polylines(
            cm, [crease.astype(np.int32)], False, 255, max(2, int(eh * 0.08)), cv2.LINE_AA
        )
        out = blend(out, (out.astype(np.float32) * 0.85), feather(cm, max(5, int(eh * 0.3))) * 0.5)
    return out


def mouth_geometry(lm: np.ndarray) -> dict:
    up = smooth_curve(lm[LIPS_INNER_UPPER])
    lo = smooth_curve(lm[LIPS_INNER_LOWER])
    outer = lm[LIPS_OUTER]
    x0, y0 = outer.min(0)
    x1, y1 = outer.max(0)
    return dict(
        up=up,
        lo=lo,
        outer=outer,
        box=(x0, y0, x1, y1),
        w=x1 - x0,
        cx=(x0 + x1) / 2,
        gap=float(np.max(lo[:, 1] - up[:, 1])),
    )


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
    cv2.polylines(
        lm_, [line.astype(np.int32)], False, 255, max(3, int(g["w"] * 0.012)), cv2.LINE_AA
    )
    dark = np.zeros_like(img)
    dark[:] = colour * 0.45
    return blend(filled, dark, feather(lm_, 5) * 0.8)


def open_mouth(img: np.ndarray, g: dict, opening: float, width: float) -> np.ndarray:
    """Opens the mouth by moving the lower lip and jaw down (and narrowing
    for O and U), then shows a dark mouth inside with the upper teeth."""
    h, w = img.shape[:2]
    *_, y1 = g["box"]
    mw = g["w"]
    amp = opening * mw
    cx = g["cx"]
    mid = (g["up"][:, 1].mean() + g["lo"][:, 1].mean()) / 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Horizontal falloff across the mouth, vertical: full below the lips,
    # fading out down the chin.
    fx = np.exp(-(((xx - cx) / (mw * 0.62)) ** 2))
    below = np.clip((yy - mid) / (amp + 1e-3), 0, 1)
    fade = np.exp(-((np.clip(yy - (y1 + amp), 0, None) / (mw * 0.9)) ** 2))
    dy = amp * fx * below * fade
    # Narrow towards the centre (O, U), strongest at the lips.
    near = np.exp(-(((yy - mid) / (mw * 0.35)) ** 2)) * np.exp(-(((xx - cx) / (mw * 0.8)) ** 2))
    dx = (xx - cx) * (1 - 1 / width) * near
    mapx = (xx - dx).astype(np.float32)
    moved = cv2.remap(
        img, mapx, (yy - dy).astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT
    )
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
        teeth = cv2.remap(img, mapx, yy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT).astype(
            np.float32
        )
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


#: The frames the drawer makes (the rest show the neutral face).
DRAWN = frozenset({"blink", "mouth_closed", *MOUTHS})


class LandmarkDrawer:
    """A FrameDrawer (frames.py) for the Media Service: PIL in and out, the
    landmarks found again on each call (fast next to an image model)."""

    frames = DRAWN

    def __init__(self, model: str) -> None:
        from mediapipe.tasks.python.core.base_options import BaseOptions

        self._detector = vision.FaceLandmarker.create_from_options(
            vision.FaceLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=model), num_faces=1
            )
        )

    def draw(self, neutral, frame):
        from PIL import Image

        rgba = np.asarray(neutral.convert("RGBA"))
        rgb = np.ascontiguousarray(rgba[:, :, :3])
        lm = landmarks(self._detector, rgb)
        if lm is None:
            return None
        bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
        if frame == "blink":
            out = close_eyes(bgr, lm)
        elif frame == "mouth_closed":
            out = close_mouth(bgr, mouth_geometry(lm))
        elif frame in MOUTHS:
            out = open_mouth(bgr, mouth_geometry(lm), *MOUTHS[frame])
        else:
            return None
        image = Image.fromarray(cv2.cvtColor(out, cv2.COLOR_BGR2RGB)).convert("RGBA")
        image.putalpha(neutral.convert("RGBA").getchannel("A"))
        return image
