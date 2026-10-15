# Coach voices (T-ONB-03c, FR-VOC-01)

Every library voice must be licensed for commercial use, with its source and licence recorded here. **Legal review is required before launch** (spec 6.x "legal review required").

## Library voices in the app today (6 of the 12 needed by launch)

| App id (stored in Firestore) | Name in the app | Accent | Source voice | Model | Licence |
|---|---|---|---|---|---|
| `lw-warm` (default) | Warm | US English | Kokoro `af_heart` | Kokoro-82M v1.0 | Apache-2.0 |
| `lw-bright` | Bright | US English | Kokoro `af_bella` | Kokoro-82M v1.0 | Apache-2.0 |
| `lw-steady` | Steady | US English | Kokoro `am_michael` | Kokoro-82M v1.0 | Apache-2.0 |
| `lw-deep` | Deep | US English | Kokoro `am_fenrir` | Kokoro-82M v1.0 | Apache-2.0 |
| `lw-gentle` | Gentle | UK English | Kokoro `bf_emma` | Kokoro-82M v1.0 | Apache-2.0 |
| `lw-clear` | Clear | UK English | Kokoro `bm_george` | Kokoro-82M v1.0 | Apache-2.0 |

**Sources:**
- Model: Kokoro-82M by hexgrad, https://huggingface.co/hexgrad/Kokoro-82M. Weights and voices are Apache-2.0, which allows commercial use and modification with attribution.
- Runtime: kokoro-onnx by thewh1teagle (MIT), https://github.com/thewh1teagle/kokoro-onnx. Model files are from release `model-files-v1.0`: `kokoro-v1.0.int8.onnx` and `voices-v1.0.bin`.
- Generated with `apps/mobile/tool/generate_voice_previews.py`. The output is bundled in `apps/mobile/assets/voices/` (AAC, mono, 48 kbps).

**Attribution** (Apache-2.0): add "Voices: Kokoro-82M by hexgrad (Apache-2.0)" to the app's open-source licences page (Help & about, ONB-03f).

## What each voice says (closed script, FR-VOC-05)
Previews are fixed, approved app text, pre-generated and bundled. There is no live text-to-speech, and nothing a user typed is ever spoken.

| File | Text |
|---|---|
| `greeting.m4a` (default voice) | "Hi, I'm your Live Well coach. I'm here to help, one small step at a time." |
| `<id>_calm.m4a` (speed 0.92) | "Hi, I'm your Live Well coach. Let's take one small step together today." |
| `<id>_energetic.m4a` (speed 1.08) | "Hi! I'm your Live Well coach. Let's make today count, one small step at a time!" |

The screen shows "Hi {first name}, …" as **text**. A bundled recording can't say each person's name, so the audio greets without a name.

**Speed:** the 0.8x–1.2x speed setting is applied at playback.

## Open (needs-product / legal)
- **Legal review of these voices for commercial use.** Apache-2.0 covers the weights; the training-data provenance is described on the model card.
- **12 voices by launch:** 6 more are needed. Which accents? An Indian English voice would help the India market.
- **Production voices:** the voice vendor for the Coach Agent (T-VOC-01) may replace these. Keep the app ids stable and remap the source.
