# Roadmap

The work in progress and what comes next, as a checklist. Each item is one PR on a short branch off `main`, merged when CI is green and the owner has reviewed it (D-67; until 2026-11-03 PRs were stacked on the one before). Agreed changes are in [decisions.md](decisions.md); the latest spec audit is in [audit/](audit/) and release steps in [release/checklist.md](release/checklist.md).

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
- [ ] **AVT-08g** The widget with the 3D avatar (replaces T-TCH-02's widget), in five PRs:
  - [x] **08g-a** Shared widget data: the snapshot and its timeline (no native widget yet)
  - [x] **08g-b** iOS widgets (WidgetKit, SwiftUI), Done with App Intents on iOS 17+ (PR #55; builds on Codemagic, not yet seen on an iPhone)
  - [x] **08g-c** Android widgets, Done without opening the app (classic RemoteViews, not Glance; D-61)
  - [ ] **08g-d** Look and feel, "Add the widget" card
  - [ ] **08g-e** Hide details on lock screen, sign-out, analytics
    - [x] part 1: the Hide details setting, sign-out, step reminder off after Done (D-68)
    - [ ] part 2: `widget_interaction {action, size, slot}` (needs the size from the native widgets)
- [ ] **AVT-08h** Settings and deletion (Delete my avatar)
- [ ] **T-DLY-03e** Daily plan settings
- [x] **T-GOL-03** My Daily Routine (D-44 to D-48)

## Blocked

- **"Make me from my photo" in prod:** needs commercially licensed face-similarity and age checks (options in `docs/design/asset-licences.md`, none chosen), counsel review (T-CMP-02) and the `avatar_from_photo` flag. Build my own and the ready-made coaches don't depend on it.
- **Deploying the ComfyUI server and the Media Service:** needs the Blaze plan (billing for Cloud Run GPUs, D-17), then `docs/media/comfyui-setup.md`.
- **Push for a closed app:** the server's `JobNotifier` needs FCM and device registration in the app (deploy).
