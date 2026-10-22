"""Makes the placeholder avatar frame set (T-AVT-08a) for developing the
frame player before the 3D art exists: 14 labelled cards, no face (avatar
parts are never drawn in code). Dev preview and dev gallery only.

From apps/mobile:
    python tool/make_placeholder_frames.py

Writes assets/avatar/frames/placeholder/ (WebP at 2x and 3x, and
avatar_frames.json). Needs Pillow with WebP.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path('assets/avatar/frames/placeholder')
FONT = 'assets/fonts/poppins/Poppins-SemiBold.ttf'
FONT_BODY = 'assets/fonts/poppins/Poppins-Regular.ttf'
SIZES = {'2x': 512, '3x': 768}

MINT = (232, 249, 238)
INK = (43, 36, 32)
SOFT = (95, 110, 102)

# Frame id: (title, line, ring colour). Expressions have their own colour so
# a change is easy to see; blink and mouth frames share neutral's.
NEUTRAL = (46, 139, 98)
FRAMES = {
    'neutral': ('Neutral', 'gentle smile', NEUTRAL),
    'happy': ('Happy', 'big smile', (246, 195, 68)),
    'waving': ('Waving', 'hand raised', (76, 201, 164)),
    'listening': ('Listening', 'head tilted', (127, 178, 240)),
    'calm': ('Calm', 'soft eyes', (163, 140, 214)),
    'celebrating': ('Celebrating', 'hands up', (242, 141, 178)),
    'blink': ('Neutral', 'eyes closed', NEUTRAL),
    'mouth_A': ('Neutral', 'mouth  A  "ah"', NEUTRAL),
    'mouth_I': ('Neutral', 'mouth  I  "ee"', NEUTRAL),
    'mouth_U': ('Neutral', 'mouth  U  "oo"', NEUTRAL),
    'mouth_E': ('Neutral', 'mouth  E  "eh"', NEUTRAL),
    'mouth_O': ('Neutral', 'mouth  O  "oh"', NEUTRAL),
    'mouth_closed': ('Neutral', 'mouth closed', NEUTRAL),
    'thumb': ('Coach', 'thumbnail', NEUTRAL),
}


def card(px: int, title: str, line: str, ring: tuple) -> Image.Image:
    im = Image.new('RGB', (px, px), MINT)
    d = ImageDraw.Draw(im)
    w = px // 28
    d.ellipse((w, w, px - w, px - w), outline=ring, width=w)
    t = ImageFont.truetype(FONT, px // 9)
    b = ImageFont.truetype(FONT_BODY, px // 15)
    s = ImageFont.truetype(FONT_BODY, px // 22)
    d.text((px / 2, px * 0.42), title, font=t, fill=INK, anchor='mm')
    d.text((px / 2, px * 0.56), line, font=b, fill=INK, anchor='mm')
    d.text((px / 2, px * 0.70), 'placeholder frame', font=s, fill=SOFT, anchor='mm')
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = {}
    for frame, (title, line, ring) in FRAMES.items():
        files[frame] = {}
        for size, px in SIZES.items():
            name = f'{frame}@{size}.webp'
            card(px, title, line, ring).save(OUT / name, 'WEBP', quality=90)
            files[frame][size] = name
    manifest = {
        'avatar_id': 'placeholder',
        'version': 1,
        'style': '3d_adult',
        'canvas': {'width': 1024, 'height': 1024},
        'sizes': list(SIZES),
        'note': 'Placeholder cards, not a face: for developing the frame player (T-AVT-08a). Dev builds only.',
        'frames': files,
    }
    (OUT / 'avatar_frames.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
