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

**Not chosen yet:** the image vendor and the checking model (see
`docs/design/avatar-vendor-scorecard.md`), so by default every call is refused
and nothing is sent anywhere. Firebase Admin, the consent store, Firestore job
storage and Cloud Storage portraits are wired at deploy time behind the same
interfaces.

```
python -m venv .venv
.venv/Scripts/python -m pip install -e ".[dev]"   # Windows
.venv/Scripts/python -m pytest
.venv/Scripts/python -m ruff check src tests
.venv/Scripts/python -m mypy
```
