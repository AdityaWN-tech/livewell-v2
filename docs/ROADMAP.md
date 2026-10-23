# Roadmap

The work in progress and what comes next, as a checklist. Each item is one PR, stacked on the one before and reviewed by the owner before the next starts. The overall build order and status of every task is in [progress.md](progress.md); agreed changes in [decisions.md](decisions.md).

## Now: the 3D coach (T-AVT-08) and builds

- [x] **AVT-08a** Clean-up and frame-set engine (PR #46)
- [x] **AVT-08b** Ready-made coaches and the Avatar Studio (PR #47)
- [x] **AVT-08c** Media Service: avatar generation behind adapters (PR #48)
- [x] **AVT-08d** Media Service: the 14-frame set (PR #49)
- [x] **AVT-08e** "Make me from my photo": consent, live capture, deletion (flag off in prod) (PR #50)
- [x] **ComfyUI stylizer** (PR #51) for AVT-08c/d: our own ComfyUI on a Cloud Run GPU, models from Hugging Face, licences checked; "We'll let you know" and a notification (deploy needs Blaze)
- [x] **iOS builds in the cloud** (PR #52): Codemagic (dev, staging, prod; TestFlight for staging) and a GitHub Actions iOS build check; Apple account setup in `docs/ios-build-setup.md`

## Next

- [x] **AVT-08f** Everything the avatar does in the app: first hello, check-in reaction, streak milestones, calm after safety (new lines pending clinical review; routine items wait for T-GOL-03, lesson narration for the lesson reader)
- [ ] **AVT-08g** The widget with the 3D avatar (replaces T-TCH-02's widget)
- [ ] **AVT-08h** Settings and deletion (Delete my avatar)
- [ ] **T-DLY-03e** Daily plan settings
- [ ] **T-GOL-03** My Daily Routine (its reminders use the 3D avatar)

## Blocked

- **"Make me from my photo" in prod:** needs commercially licensed face-similarity and age checks (options in `docs/design/asset-licences.md`, none chosen), counsel review (T-CMP-02) and the `avatar_from_photo` flag. Build my own and the ready-made coaches don't depend on it.
- **Deploying the ComfyUI server and the Media Service:** needs the Blaze plan (billing for Cloud Run GPUs, D-17), then `docs/media/comfyui-setup.md`.
- **Push for a closed app:** the server's `JobNotifier` needs FCM and device registration in the app (deploy).
