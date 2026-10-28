# ADR-001: Avatar, voice and liveness: packages, services and vendors

- **Task:** T-FND-03 (vendor + framework spike), the avatar, voice and liveness part only. The agent framework (LangGraph vs ADK), the LLM, cloud speech-to-text and vector search get their own ADRs.
- **Status:** Accepted for what is built today (2026-10-28). The vendor choices marked **Open** below still need the spike, the owner's decision and legal review.
- **Spec:** §7 (FR-AVT-01..07, FR-VOC-01/05), §8.3 (candidate vendors), §8.4 (cost guardrails).
- **Decisions it summarises:** D-35, D-36, D-37, D-38, D-39, D-49, D-50 (`docs/decisions.md`). Licences: `docs/design/asset-licences.md`, `docs/voices.md`. Image method scorecard: `docs/design/avatar-vendor-scorecard.md`.

## Context

Spec §8.3 lists candidate vendors for each capability and asks for every vendor to sit behind an adapter, so it can be swapped without changing app code. Phase 1 needs a coach with a face and a voice that works for India and US users, with no vendor contract signed yet, no budget for per-minute avatar video, and the closed-script voice rule (FR-VOC-05: the coach only says approved text).

So far we have chosen open, commercially licensed models we run ourselves, plus on-device features of the phone, and have kept paid vendors out until the spike. This ADR writes down what is in use, why, and what is still open.

## Decision

### 1. Avatar

| Part | What we use | Licence / terms | Status |
|---|---|---|---|
| Coach style | **3D-caricature portrait + 14 still frames per coach** (neutral, blink, mouth shapes, expressions), animated in Flutter code (breath, blink, lip flaps, expression cross-fades). Not Rive or Unity (spec 7.1's example) | Our code | In the app |
| Ready-made coaches (8, Appendix C) | Portraits made by the owner with Google Gemini; frame sets made by `tool/make_coach_frames.py` | **Needs review:** Gemini's terms for commercial use of generated images | Bundled; dev builds show them, staging/prod only once art is `final` (D-35) |
| Build my own, Adjust, From my photo | **Media Service** (`services/media`, FastAPI on Cloud Run) behind the `AvatarStylizer` adapter, backed by **our own ComfyUI server** (private Cloud Run L4 GPU) | ComfyUI GPL-3.0 (run as a server, not distributed; **needs legal review**) | Built and tested; **not deployed** (needs Blaze + GPU quota, D-39). App tabs hidden until deployed (flag `avatarMaker`, D-50) |
| Image model on ComfyUI | Qwen-Image-Edit-2511 (GGUF Q5_K_M) + Qwen2.5-VL 7B text encoder + Qwen-Image VAE + 4-step Lightning LoRA | All Apache-2.0 (checked 2026-10-23); the download script refuses anything else | Built |
| Image safety check (`ImageInspector`: one face, adult-looking, no nudity/violence/text/logo) | **Open:** none chosen. Candidates: Google Cloud Vision SafeSearch, Falconsai NSFW (Apache-2.0), YuNet (MIT) | — | Without it, no frame passes (frames fall back to neutral) |
| Face similarity + age check (From my photo) | **Open, blocker.** InsightFace-based models are non-commercial; a commercially licensed option is needed | — | `avatar_from_photo` stays off |
| Frame alignment tool (developer machine only) | MediaPipe face landmarker | Apache-2.0 | Not shipped |

**Why:** the per-avatar cost is one GPU minute or two, not a per-minute video bill; models are commercially licensed and nothing about a person's face goes to a third party; frames are bundled or cached, so the coach works offline and with reduced motion (FR-AVT-05/06). The **photo-realistic avatar** (HeyGen, Tavus, D-ID, Synthesia) is Phase 2 and out of scope here.

### 2. Voice

| Part | What we use | Licence / terms | Status |
|---|---|---|---|
| Library voice previews (6 of 12) | **Kokoro-82M v1.0** via kokoro-onnx, pre-generated, bundled as AAC; played with `audioplayers` | Apache-2.0 (model), MIT (runtime) | In the app; needs legal review and 6 more voices (`docs/voices.md`) |
| The coach speaking at run time (interim) | The phone's own text-to-speech via **`flutter_tts`**, with a voice picked to match the chosen library voice (D-49) | OS voices (Google TTS on Android, Apple on iOS); on-device | In the app until T-VOC-01 |
| Production coach voice + voice clone | **Open (T-VOC-01, T-VOC-02).** Candidates from §8.3: ElevenLabs, Cartesia, Azure AI Speech, Resemble AI, Google Cloud TTS. Clone needs the speaker's consent and a deletion API | — | Clone and Dr. Gokula voice behind flags (`voiceClone`, `drGokulaVoice`), off |
| Speech-to-text (Care, check-ins) | On-device **`speech_to_text`** (Android SpeechRecognizer / iOS Speech) | OS terms | In the app; cloud STT is part of the agent ADR |

**Rule kept:** only approved text is ever spoken (FR-VOC-05). Nothing a person typed reaches any voice engine; custom routine labels appear only as text (D-47).

### 3. Liveness (From my photo, FR-AVT-03)

| Part | What we use | Licence / terms | Status |
|---|---|---|---|
| Live selfie only | `camera` plugin, front camera; the avatar feature never uses the gallery (`image_picker` is not used there; tested) | BSD-3 | Built, flag off |
| On-device liveness | **Google ML Kit face detection** (`google_mlkit_face_detection`): exactly one face, then a random blink or head turn | Plugin MIT; ML Kit terms (free, on-device): **verify for commercial use** | Built, flag off |
| Server liveness + match "selfie is the same person" | **Open, blocker.** Needs a commercially licensed face-match / presentation-attack check with a spoof test set (FR-AVT-03 acceptance). Candidates to score: AWS Rekognition Face Liveness, Azure Face liveness, iProov, FaceTec, or a commercial InsightFace licence | — | Not chosen |

Selfies are held in memory for one job and discarded (tested: `test_selfie_privacy.py`); ComfyUI deletes its input, output and history after each job (`livewell_forget`); every step goes to the append-only audit log.

## Scorecard status (spec 8.3)

| Capability | Criteria from 8.3 | Scored? |
|---|---|---|
| Stylized avatar rendering | Flutter compatibility, lip-sync, app size, battery | Decided without a spike: still frames in Flutter (no extra runtime, small app, low battery). Lip-sync is mouth shapes timed to speech, not audio visemes |
| Avatar image method | `avatar-vendor-scorecard.md` (likeness, consistency, frame consistency, speed, cost, data terms) | **Not yet**: needs the ComfyUI server deployed to measure speed and likeness |
| Voice / clone | Latency < 300 ms to first byte, clone quality, consent tooling, watermarking, deletion API, data terms | **Not yet**: needs vendor keys (T-VOC-01) |
| Liveness / face match | Self-only consent, spoof resistance, deletion, licence | **Not yet** |

## Consequences

- Phase 1 runs with **no paid avatar or voice vendor**: ready-made coaches, interim phone voices and on-device STT.
- **Build my own and Adjust** become available when the Media Service and ComfyUI are deployed and an image safety check is chosen; until then their tabs are hidden, never shown as "Coming soon".
- **From my photo** stays off until a commercial face-match/liveness option passes legal review (T-CMP-02).
- The coach's previews and its spoken voice differ until T-VOC-01.
- Every adapter (`AvatarStylizer`, `ImageInspector`, `AvatarMakerApi`, the coach speaker) lets a vendor be swapped later without app changes.

## Needs human review

- Legal: Gemini terms for the ready-made portraits; ComfyUI GPL-3.0 as a server; ML Kit commercial terms; Kokoro voices.
- Design lead: the inclusive option set (`content/avatar/options.json`, FR-AVT-02 acceptance).
- Owner: budget and choice for the image safety check, the face-match/liveness vendor and the production voice vendor.
