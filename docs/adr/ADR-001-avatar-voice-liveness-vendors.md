# ADR-001: Avatar, voice and liveness: packages, services and vendors (T-FND-03, avatar part)

| | |
|---|---|
| Status | **Proposed**: what is built is listed as in use; every open choice needs the product owner, and licences and data terms need legal review |
| Date | 2026-10-28 |
| Task | T-FND-03 (vendor spike, ADRs with §8.3 scorecards), the avatar, voice and liveness part. The LLM, STT and agent-framework ADRs are still to do. |
| Related | D-36, D-38, D-39, D-49, D-50; `docs/design/avatar-vendor-scorecard.md`; `docs/design/asset-licences.md`; `docs/voices.md` |

## Context

The coach has a 3D-style face (ready-made, built from options, adjusted, or made from the person's photo), speaks only approved text (closed-script rule, FR-VOC-05), and "From my photo" needs proof that the selfie is live and is the person's own (FR-AVT-03). Spec §8.3 asks for a scored choice per vendor. No paid vendor keys exist yet, so the spike's measured scores (likeness, speed, cost) are not in; this ADR records what is in use now, what is a candidate, and what blocks each choice.

## Decision (current state)

### Avatar images

| Part | In use / proposed | Licence | Status |
|---|---|---|---|
| Ready-made coaches (8) | Bundled frame sets, `assets/avatar/frames/coaches/` (art made per `docs/design/coach-frames-gemini.md`) | Owner's art, see `asset-licences.md` | In use |
| Image generation for Build my own, Adjust, From my photo and frames | **Own ComfyUI server** on private Cloud Run (one NVIDIA L4, scales to zero) with Qwen-Image-Edit-2511 (GGUF Q5_K_M), Qwen2.5-VL 7B fp8 text encoder, Qwen-Image VAE, 4-step Lightning LoRA (D-39) | All Apache-2.0 | Built, **not deployed** (needs Blaze billing, D-17) |
| Dev-only image generation, safety + likeness check and face box (D-64) | Google Gemini API: `gemini-2.5-flash-image` (edits, about $0.039 per image) and `gemini-2.5-flash` (checks), **billing-enabled key only** | Commercial (Gemini API terms) | In use on the developer's computer only; prod needs the DPA and counsel review |
| Dev-only free image generation and checks (D-65) | Local ComfyUI on the developer's laptop: SD 1.5 fp16 + LCM-LoRA + ControlNet canny (one portrait); blink/mouth drawn with MediaPipe; YuNet, SFace, CLIP checks | OpenRAIL-M (SD 1.5, dev-only exception); MIT/Apache for the rest | In use on the laptop only; never deployed |
| Media Service | `services/media`: FastAPI, Pydantic, Uvicorn, Pillow, httpx on Cloud Run | MIT/BSD-style | Built, not deployed |
| Commercial fallback candidates | Google Vertex AI image editing, OpenAI image editing, BFL FLUX Kontext API, Stability AI API | Commercial terms | Candidates only; scored by `avatar-vendor-scorecard.md` |
| Image safety check (`ImageInspector`) | Candidate: Google Cloud Vision (safe search, text, logo) | Commercial | **Not chosen** |
| Face similarity and age check (From my photo) | Candidates in `asset-licences.md` (for example FaceTec, Paravision, a commercially licensed model) | Commercial | **Not chosen; blocks From my photo** |
| Refused | Anything built on InsightFace weights, FLUX.1 dev, BRIA RMBG (non-commercial); public demo hosts (Gradio, Spaces, Colab, tunnels) | — | Refused in code |

### Voice

| Part | In use / proposed | Licence | Status |
|---|---|---|---|
| Library voice previews (6 of 12) | Kokoro-82M v1.0 via kokoro-onnx, pre-generated and bundled (`docs/voices.md`) | Apache-2.0 / MIT | In use |
| The coach speaking in the app (interim) | Phone text-to-speech (`flutter_tts`), closest phone voice to the chosen one (D-49) | Platform | In use, interim |
| The coach's own voices, voice clone, Dr. Gokula's voice (T-VOC-01) | Candidates per spec §8.3 (to score: a commercial TTS with cloning and consent controls, or Kokoro served from our own server for library voices) | — | **Not chosen**; `voice_clone` and `dr_gokula_voice` flags off |

### Liveness and own-face check

| Part | In use / proposed | Licence | Status |
|---|---|---|---|
| Live selfie capture | `camera` plugin, front camera, no gallery (D-38) | BSD | In use behind `avatar_from_photo` |
| On-device face detection and liveness (blink, or head turn) | Google ML Kit, `google_mlkit_face_detection` (nothing leaves the phone to read the face) | ML Kit terms | In use behind the flag; terms need legal review |
| Server-side liveness or face match | Not used; candidates FaceTec, Paravision (`asset-licences.md`) | Commercial | Not chosen; only needed if counsel asks for more than on-device checks |

## Consequences

- **Prod today:** Coaches, Background and Voice only. Build my own and Adjust need `avatar_maker` on plus a deployed Media Service; From my photo also needs `avatar_from_photo`, which waits for counsel review (T-CMP-02) and a chosen face-similarity and age check.
- **Costs to approve:** Blaze billing for Cloud Run GPU (L4, scale to zero; about 8–11 minutes of GPU per full coach, estimated, D-39); a Cloud Vision bill per image if chosen.
- Every vendor must pass the hard requirements in `avatar-vendor-scorecard.md` (commercial licence, no training on user data, deletion, DPA, India and US) before it is scored.

## Owner decisions needed

1. Turn on Blaze and deploy the ComfyUI server and Media Service (then the spike measures real speed and cost).
2. Pick the image safety check (Cloud Vision or another).
3. Pick a face-similarity and age check for From my photo, or keep it off.
4. Pick the voice vendor for the coach's own voices and the clone (T-VOC-01).
5. Legal review: ML Kit terms, the camera and biometric consent text, every licence above.
