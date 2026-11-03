"""Generate the bundled coach-voice previews (T-ONB-03c, FR-VOC-01).

Closed script (FR-VOC-05): every line spoken here is fixed, approved app
text below; nothing a user typed. Voices: Kokoro-82M (Apache-2.0), run
through kokoro-onnx (MIT). Source and licence of each voice are recorded in
docs/voices.md; change both together.

Setup (outside the repo, the model is ~120 MB):
  python -m venv tts-venv
  tts-venv/Scripts/python -m pip install kokoro-onnx soundfile
  download kokoro-v1.0.int8.onnx and voices-v1.0.bin from
  https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0
Run from apps/mobile:
  tts-venv/Scripts/python tool/generate_voice_previews.py MODEL_DIR
Needs ffmpeg on PATH (encodes small AAC .m4a files).
"""

import pathlib
import subprocess
import sys
import tempfile

import soundfile as sf
from kokoro_onnx import Kokoro

# Library voice id -> Kokoro voice. Ids are stable (saved in Firestore).
VOICES = {
    'lw-warm': 'af_heart',  # default coach voice
    'lw-bright': 'af_bella',
    'lw-steady': 'am_michael',
    'lw-deep': 'am_fenrir',
    'lw-gentle': 'bf_emma',
    'lw-clear': 'bm_george',
}
DEFAULT = 'lw-warm'

GREETING = "Hi, I'm your Live Well coach. I'm here to help, one small step at a time."
SAMPLES = {
    'calm': ("Hi, I'm your Live Well coach. Let's take one small step together today.", 0.92),
    'energetic': ("Hi! I'm your Live Well coach. Let's make today count, one small step at a time!", 1.08),
}

OUT = pathlib.Path('assets/voices')


def speak(kokoro, voice, text, speed, out):
    samples, rate = kokoro.create(text, voice=voice, speed=speed, lang='en-us' if voice[0] == 'a' else 'en-gb')
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / 'a.wav'
        sf.write(wav, samples, rate)
        subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(wav), '-ac', '1', '-c:a', 'aac', '-b:a', '48k', str(out)],
            check=True,
        )
    print(out, f'{len(samples) / rate:.1f}s')


def main():
    model_dir = pathlib.Path(sys.argv[1])
    kokoro = Kokoro(str(model_dir / 'kokoro-v1.0.int8.onnx'), str(model_dir / 'voices-v1.0.bin'))
    OUT.mkdir(parents=True, exist_ok=True)
    speak(kokoro, VOICES[DEFAULT], GREETING, 1.0, OUT / 'greeting.m4a')
    for vid, kv in VOICES.items():
        for style, (text, speed) in SAMPLES.items():
            speak(kokoro, kv, text, speed, OUT / f'{vid}_{style}.m4a')


if __name__ == '__main__':
    main()
