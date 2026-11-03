"""Makes placeholder frame sets for the 8 ready-made coaches (T-AVT-08b) so
the frame player and the Avatar Studio can be built before the 3D art
exists: 14 labelled cards per coach, no face (avatar parts are never drawn
in code). Shown only in dev builds; staging and prod show the initial circle
until a coach's art is final (illustrations.json).

From apps/mobile:
    python tool/make_placeholder_frames.py

Writes assets/avatar/frames/coaches/<coach id>/ (WebP at 2x and 3x, and
avatar_frames.json). Needs Pillow with WebP.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path('assets/avatar/frames/coaches')
FONT = 'assets/fonts/poppins/Poppins-SemiBold.ttf'
FONT_BODY = 'assets/fonts/poppins/Poppins-Regular.ttf'
# Placeholders: one small size is enough (the real sets have 2x and 3x).
SIZES = {'2x': 288}

MINT = (232, 249, 238)
INK = (43, 36, 32)
SOFT = (95, 110, 102)

# The 8 ready-made coaches (T-AVT-08 Appendix C), in the Studio's order.
COACHES = [
    ('brown_hair', 'Brown hair, 30s'),
    ('long_black_hair', 'Long black hair, 30s'),
    ('green_hijab', 'Green hijab, 40s'),
    ('navy_turban', 'Navy turban, 40s'),
    ('grey_glasses', 'Grey hair, glasses, 60s'),
    ('short_curls', 'Short curls, 50s'),
    ('short_black_hair', 'Short black hair, 20s'),
    ('wheelchair', 'Auburn hair, wheelchair'),
]

# Frame id: (line, ring colour). Expressions have their own colour so a
# change is easy to see; blink and mouth frames share neutral's.
NEUTRAL = (46, 139, 98)
FRAMES = {
    'neutral': ('neutral', NEUTRAL),
    'happy': ('happy · big smile', (246, 195, 68)),
    'waving': ('waving · hand raised', (76, 201, 164)),
    'listening': ('listening · head tilted', (127, 178, 240)),
    'calm': ('calm · soft eyes', (163, 140, 214)),
    'celebrating': ('celebrating · hands up', (242, 141, 178)),
    'blink': ('neutral · eyes closed', NEUTRAL),
    'mouth_A': ('mouth  A  "ah"', NEUTRAL),
    'mouth_I': ('mouth  I  "ee"', NEUTRAL),
    'mouth_U': ('mouth  U  "oo"', NEUTRAL),
    'mouth_E': ('mouth  E  "eh"', NEUTRAL),
    'mouth_O': ('mouth  O  "oh"', NEUTRAL),
    'mouth_closed': ('mouth closed', NEUTRAL),
    'thumb': ('', NEUTRAL),
}


def card(px: int, n: int, title: str, line: str, ring: tuple) -> Image.Image:
    im = Image.new('RGB', (px, px), MINT)
    d = ImageDraw.Draw(im)
    w = max(4, px // 28)
    d.ellipse((w, w, px - w, px - w), outline=ring, width=w)
    big = ImageFont.truetype(FONT, px // 4)
    t = ImageFont.truetype(FONT, px // 14)
    b = ImageFont.truetype(FONT_BODY, px // 17)
    s = ImageFont.truetype(FONT_BODY, px // 24)
    d.text((px / 2, px * 0.30), str(n), font=big, fill=INK, anchor='mm')
    d.text((px / 2, px * 0.52), title, font=t, fill=INK, anchor='mm')
    if line:
        d.text((px / 2, px * 0.64), line, font=b, fill=INK, anchor='mm')
    d.text((px / 2, px * 0.76), 'placeholder', font=s, fill=SOFT, anchor='mm')
    return im


def main() -> None:
    for n, (coach, title) in enumerate(COACHES, start=1):
        out = OUT / coach
        out.mkdir(parents=True, exist_ok=True)
        files = {}
        for frame, (line, ring) in FRAMES.items():
            files[frame] = {}
            for size, px in SIZES.items():
                name = f'{frame}@{size}.webp'
                card(px, n, title, line, ring).save(out / name, 'WEBP', quality=70)
                files[frame][size] = name
        manifest = {
            'avatar_id': coach,
            'version': 1,
            'style': '3d_adult',
            'canvas': {'width': 1024, 'height': 1024},
            'sizes': list(SIZES),
            'note': 'Placeholder cards, not a face (T-AVT-08b). Dev builds only until the final art exists.',
            'frames': files,
        }
        (out / 'avatar_frames.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
