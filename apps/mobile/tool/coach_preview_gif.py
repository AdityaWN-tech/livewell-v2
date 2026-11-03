"""An animated preview of the 8 ready-made coaches (T-AVT-08b art): they
blink, talk (the mouth shapes) and cheer (a hop with sparkles, as the app
moves them). Writes docs/evidence/coach-art/coaches.gif.

    python tool/coach_preview_gif.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
COACHES = ROOT / "assets" / "avatar" / "frames" / "coaches"
OUT = ROOT.parents[1] / "docs" / "evidence" / "coach-art" / "coaches.gif"
IDS = [
    "brown_hair", "long_black_hair", "green_hijab", "navy_turban",
    "grey_glasses", "short_curls", "short_black_hair", "wheelchair",
]
TILE = 220
BG = (232, 249, 238)

# (frame, how many ticks, gesture) at 12 a second.
SCRIPT = (
    [("neutral", 6, None), ("blink", 2, None), ("neutral", 4, None)]
    + [(f, 2, None) for f in ["mouth_E", "mouth_A", "mouth_closed", "mouth_O", "mouth_I",
                             "mouth_A", "mouth_U", "mouth_closed", "mouth_E", "mouth_A",
                             "mouth_closed"]]
    + [("neutral", 3, None), ("blink", 2, None), ("neutral", 3, None)]
    + [("celebrating", 1, i / 16) for i in range(16)]
    + [("neutral", 6, None)]
)


def circle(im: Image.Image) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, im.width - 1, im.height - 1), fill=255)
    out = Image.new("RGB", im.size, BG)
    out.paste(im, (0, 0), mask)
    return out


def tile(coach: str, frame: str, t: float | None) -> Image.Image:
    face = Image.open(COACHES / coach / f"{frame}@2x.webp").convert("RGB")
    size = int(TILE * 0.82)
    face = circle(face.resize((size, size), Image.LANCZOS))
    canvas = Image.new("RGB", (TILE, TILE), BG)
    lift = 0
    if t is not None:
        hop = max(0.0, math.sin(4 * math.pi * t))
        lift = int(size * 0.05 * hop)
        grow = int(size * 0.03 * hop)
        face = face.resize((size + grow, size + grow), Image.LANCZOS)
    x = (TILE - face.width) // 2
    y = (TILE - face.height) // 2 + 8 - lift
    canvas.paste(face, (x, y))
    if t is not None:
        d = ImageDraw.Draw(canvas)
        cx, cy = TILE / 2, TILE / 2 + 8
        for i in range(7):
            phase = (t + i / 7) % 1.0
            a = -math.pi / 2 + (i - 3) * 0.42
            r = size * (0.5 + 0.08 * phase)
            px, py = cx + math.cos(a) * r, cy - lift + math.sin(a) * r
            s = size * 0.035 * (0.6 + 0.4 * math.sin(math.pi * phase))
            colour = (255, 201, 77) if i % 2 == 0 else (255, 241, 194)
            d.polygon([(px, py - s), (px + s * 0.35, py - s * 0.35), (px + s, py), (px + s * 0.35, py + s * 0.35),
                       (px, py + s), (px - s * 0.35, py + s * 0.35), (px - s, py), (px - s * 0.35, py - s * 0.35)],
                      fill=colour)
    return canvas


def main() -> None:
    frames: list[Image.Image] = []
    durations: list[int] = []
    for frame, ticks, t in SCRIPT:
        sheet = Image.new("RGB", (TILE * 4, TILE * 2), BG)
        for n, coach in enumerate(IDS):
            sheet.paste(tile(coach, frame, t), ((n % 4) * TILE, (n // 4) * TILE))
        frames.append(sheet.quantize(colors=255, method=Image.Quantize.MEDIANCUT))
        durations.append(ticks * 83)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)
    print(OUT, OUT.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
