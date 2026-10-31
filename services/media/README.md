# Media Service

Avatar generation jobs for the 3D coach (T-AVT-08c; spec 10.2, 12.1). Python,
FastAPI, Cloud Run.

| Endpoint | What it does |
|---|---|
| `POST /v1/avatar` | Starts a job: `source` `selfie` (From my photo), `built` (Build my own) or `adjust`. Returns `202 {job_id, status}`. |
| `GET /v1/avatar/jobs/{id}` | The job's status, owner only. |

Every call needs a Firebase ID token (`Authorization: Bearer`) and App Check
(`X-Firebase-AppCheck`). `Idempotency-Key` makes `POST` safe to repeat.

**What a job does:** fills the prompt from `docs/design/avatar-prompts.md` with
fixed choices from `content/avatar/options.json` (never free text) → the
`AvatarStylizer` makes the portrait (HTTPS to approved hosts only; public demo
servers are always refused) → the image safety check (adults only, no nudity,
violence, text or logos; a selfie avatar must look like the person) → one retry,
then a kind message (`avatar_not_made`). Each generation's cost is recorded. At
most 3 generations per person per day (Remote Config `avatar_daily_generations`).
From my photo also needs the `avatar_from_photo` flag and the camera and
biometric consents, checked here.

**Then the frame set (T-AVT-08d):** from the approved portrait, the neutral
frame, then every other frame as an edit of the neutral one (Appendix B prompts;
mouth frames keep the eyes and head). Each frame is cut out (`BackgroundRemover`)
and aligned so the face sits in one place on a 1024 px canvas (`FaceLocator`); a
quality check (`FrameChecker`: same face, same position) makes a failed frame
again once, else it shows the neutral face. Exported as WebP at 2x and 3x plus a
`thumb`, six PNG expression thumbnails (192 px) for notifications and the
widget, and `avatar_frames.json` (schema in `packages/schemas`), stored under
`avatars/{uid}/{version}/` (`FrameStore`). The job's `frames_version` is written
to `users/{uid}/avatar/current` (`AvatarDocWriter`); Adjust makes a new version
and keeps the source.

**The images come from our own ComfyUI server** (`src/media/comfyui.py`): the
`ComfyUIStylizer` uploads the input image, sends a workflow from `workflows/`
(`avatar_portrait.json`: selfie, Build my own, Adjust; `avatar_frames.json`: each
frame) to the ComfyUI API, waits, downloads the result and has ComfyUI delete
the images and the job (`comfyui/livewell_forget`). Models are open
(Apache-2.0) and downloaded from Hugging Face (`comfyui/download_models.py`);
the server runs privately on a Cloud Run L4 GPU: **[docs/media/comfyui-setup.md](../../docs/media/comfyui-setup.md)**.
It is used only when `MEDIA_COMFYUI_URL` is set (Secret Manager) and its host
is in `MEDIA_APPROVED_HOSTS`; otherwise every job is refused kindly and
nothing is sent anywhere. Calls carry a Google ID token (main) or an API-key
header (fallback). When a job ends, `JobNotifier` tells the person (FCM at
deploy). The checking model, background removal and face location are still
to be chosen (`docs/design/avatar-vendor-scorecard.md`); Firebase Admin, the
consent store, Firestore job storage and Cloud Storage are wired at deploy
behind the same interfaces.

```
python -m venv .venv
.venv/Scripts/python -m pip install -e ".[dev]"   # Windows
.venv/Scripts/python -m pytest
.venv/Scripts/python -m ruff check src tests
.venv/Scripts/python -m mypy
```

## Run locally with Gemini (dev only, D-64)

Without a ComfyUI server, the service can make images with Google Gemini on the
developer's computer. It runs under PM2 as `livewell-media-dev` on
`127.0.0.1:6799` (entry in the developer's PM2 ecosystem file).

| Env var | What it does |
|---|---|
| `MEDIA_GEMINI_API_KEY_FILE` | File holding a **billing-enabled** Gemini API key (never in the repo). Turns on `GeminiStylizer`, `GeminiInspector`, `GeminiFaceLocator`. |
| `MEDIA_APPROVED_HOSTS` | Must include `generativelanguage.googleapis.com`. |
| `MEDIA_FIREBASE_PROJECT` + `GOOGLE_APPLICATION_CREDENTIALS` | Firebase Admin (dev project's service account): ID tokens, consents, `users/{uid}/avatar/current`. |
| `MEDIA_REQUIRE_APP_CHECK=0` | Dev only: the app has no App Check yet. |
| `MEDIA_FROM_PHOTO=1` | Allows `source: selfie`. |
| `MEDIA_FRAMES_DIR` | Keeps frame sets on disk, served by `GET /v1/avatar/frames/{version}` (owner only) as signed links to `GET /v1/avatar/files/...` that expire after 15 minutes. |

```
pm2 start <ecosystem.config.js> --only livewell-media-dev; pm2 save
adb reverse tcp:6799 tcp:6799        # again after every reconnect
flutter run --flavor dev -t lib/main_dev.dart --dart-define=LW_MEDIA_URL=http://127.0.0.1:6799
```

The app only uses `LW_MEDIA_URL` in a dev debug build (plain HTTP only to
127.0.0.1/localhost). Jobs live in memory, so a restart loses running jobs.
