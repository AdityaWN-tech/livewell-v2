"""Turns the new-user journey frames into the T-ONB-03 walkthrough video.

Make the frames first (from apps/mobile):
    flutter test --update-goldens --run-skipped --tags walkthrough test/journey
Then:
    python tool/make_journey_video.py

Writes docs/evidence/T-ONB-03/journey.mp4 (about 1.5 s per step) and
journey_steps.png (every step on one sheet). Needs ffmpeg on PATH and Pillow.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FRAMES = Path('test/journey/frames')
OUT = Path('../../docs/evidence/T-ONB-03')
SECONDS = 1.5
WIDTH = 540  # half of the 1080 px test phone


def main() -> int:
    frames = sorted(FRAMES.glob('*.png'))
    if not frames:
        print('No frames: run the walkthrough test first.', file=sys.stderr)
        return 1
    ffmpeg = shutil.which('ffmpeg')
    if ffmpeg is None:
        print('ffmpeg is not on PATH.', file=sys.stderr)
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(frames):
            im = Image.open(f).convert('RGB')
            h = int(im.height * WIDTH / im.width) // 2 * 2
            im.resize((WIDTH, h), Image.LANCZOS).save(Path(tmp) / f'{i:03d}.png')
        subprocess.run(
            [ffmpeg, '-y', '-loglevel', 'error',
             '-framerate', f'1/{SECONDS}', '-i', str(Path(tmp) / '%03d.png'),
             '-vf', 'fps=30,format=yuv420p', '-c:v', 'libx264',
             '-movflags', '+faststart', str(OUT / 'journey.mp4')],
            check=True,
        )
    # Every step on one sheet, numbered, for the PR description.
    thumbs = [Image.open(f).convert('RGB') for f in frames]
    tw = 220
    thumbs = [t.resize((tw, int(t.height * tw / t.width))) for t in thumbs]
    th = max(t.height for t in thumbs)
    cols = 8
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (tw + 16) + 16, rows * (th + 44) + 16), 'white')
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 20)
    except OSError:
        font = ImageFont.load_default()
    for i, t in enumerate(thumbs):
        x = 16 + (i % cols) * (tw + 16)
        y = 16 + (i // cols) * (th + 44)
        d.text((x, y), str(i + 1), fill=(27, 36, 51), font=font)
        sheet.paste(t, (x, y + 28))
    sheet.save(OUT / 'journey_steps.png')
    print(f'{len(frames)} steps -> {OUT / "journey.mp4"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
