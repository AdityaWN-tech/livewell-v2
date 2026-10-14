"""Redraws the Live Well logo from the reference screenshot (design-reference/portal-login.jpeg).

Provisional (docs/decisions.md D-15): replace with the client's original artwork when it arrives.
Usage (from apps/mobile):  python tool/draw_logo.py
Writes assets/brand/logo.png (full lockup), logo-mark.png (circle mark, transparent),
logo-mark.svg (vector mark).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "assets" / "brand"
TEAL = (11, 58, 78)
LIME = (139, 224, 62)
CREAM = (240, 248, 220)
TEXT = (236, 241, 246)
LEAF_FILL = (250, 253, 240)  # the leaf reads brighter than the line in the reference
SS = 4  # supersampling factor

# Stroke through the mark, in circle units (centre 0,0, radius 1), traced from the reference.
POINTS = [(-0.67, -0.45), (-0.59, -0.53), (-0.51, -0.42), (-0.48, 0.03), (-0.45, 0.42),
          (-0.42, 0.43), (-0.27, 0.12), (-0.08, -0.16), (0.10, -0.31), (0.20, -0.29),
          (0.33, 0.27), (0.44, 0.64), (0.50, 0.67), (0.66, 0.36), (0.77, -0.30)]
LEAF = {"cx": -0.18, "cy": -0.04, "length": 0.36, "width": 0.16, "angle": -52}
STROKE = 0.042


def beziers(pts):
    """Catmull-Rom through pts as cubic Bezier segments."""
    p = [pts[0]] + pts + [pts[-1]]
    segs = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        segs.append((p1, c1, c2, p2))
    return segs


def sample(segs, n=40):
    out = []
    for a, b, c, d in segs:
        for k in range(n):
            t = k / n
            mt = 1 - t
            out.append(tuple(mt**3 * a[i] + 3 * mt * mt * t * b[i] + 3 * mt * t * t * c[i] + t**3 * d[i]
                             for i in range(2)))
    out.append(segs[-1][3])
    return out


def leaf_polygon(cx, cy, length, width, angle, n=60):
    """Pointed leaf (vesica) shape."""
    pts = []
    for k in range(n + 1):
        t = k / n
        x = (t - 0.5) * length
        y = math.sin(math.pi * t) * width / 2
        pts.append((x, y))
    pts += [(x, -y) for x, y in reversed(pts)]
    a = math.radians(angle)
    return [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]


def draw_mark(d, cx, cy, r):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=LIME)
    line = [(cx + x * r, cy + y * r) for x, y in sample(beziers(POINTS))]
    w = max(1, round(STROKE * r))
    d.line(line, fill=CREAM, width=w, joint="curve")
    for end in (line[0], line[-1]):
        d.ellipse((end[0] - w / 2, end[1] - w / 2, end[0] + w / 2, end[1] + w / 2), fill=CREAM)
    leaf = leaf_polygon(**LEAF)
    d.polygon([(cx + x * r, cy + y * r) for x, y in leaf], fill=LEAF_FILL)


def font(names, size):
    for n in names:
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            continue
    raise SystemExit(f"none of {names} found")


def fit_text(d, text, f_names, width, start):
    size = start
    while size > 4:
        f = font(f_names, size)
        if d.textlength(text, font=f) <= width:
            return f
        size -= 2
    return font(f_names, size)


def lockup(size=1024):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, S - 1, S - 1), radius=int(S * 0.12), fill=TEAL)
    draw_mark(d, S * 0.50, S * 0.36, S * 0.22)
    title = fit_text(d, "LIVE WELL", ["times.ttf", "DejaVuSerif.ttf"], S * 0.72, int(S * 0.16))
    d.text((S / 2, S * 0.775), "LIVE WELL", font=title, fill=TEXT, anchor="ms")
    tag = fit_text(d, "Health. Habit. Happiness.", ["arialbd.ttf", "DejaVuSans-Bold.ttf"], S * 0.72, int(S * 0.06))
    d.text((S / 2, S * 0.865), "Health. Habit. Happiness.", font=tag, fill=TEXT, anchor="ms")
    return img.resize((size, size), Image.LANCZOS)


def mark(size=1024):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_mark(ImageDraw.Draw(img), S / 2, S / 2, S / 2 - SS)
    return img.resize((size, size), Image.LANCZOS)


def mark_svg():
    def pt(p):
        return f"{50 + p[0] * 50:.2f} {50 + p[1] * 50:.2f}"
    segs = beziers(POINTS)
    path = f"M{pt(segs[0][0])} " + " ".join(f"C{pt(b)} {pt(c)} {pt(e)}" for _, b, c, e in segs)
    leaf = " ".join(pt(p) for p in leaf_polygon(**LEAF, n=24))
    hexc = lambda c: "#%02X%02X%02X" % c
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
            f'<circle cx="50" cy="50" r="50" fill="{hexc(LIME)}"/>'
            f'<path d="{path}" fill="none" stroke="{hexc(CREAM)}" stroke-width="{STROKE * 50:.2f}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>'
            f'<polygon points="{leaf}" fill="{hexc(LEAF_FILL)}"/></svg>\n')


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    lockup().save(OUT / "logo.png")
    mark().save(OUT / "logo-mark.png")
    (OUT / "logo-mark.svg").write_text(mark_svg(), encoding="utf-8")
    print("wrote", *(p.name for p in sorted(OUT.glob("logo*"))))
