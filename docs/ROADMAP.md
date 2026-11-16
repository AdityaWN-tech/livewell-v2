# Roadmap

The work in progress and what comes next, as a checklist. Each item is one PR on a short branch off `main`, merged when CI is green and the owner has reviewed it (D-67; until 2026-11-03 PRs were stacked on the one before). Agreed changes in [decisions.md](decisions.md).

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
  - [ ] **08g-c** Android widgets (Glance), Done on Android 12+
  - [ ] **08g-d** Look and feel, "Add the widget" card
  - [ ] **08g-e** Hide details on lock screen, sign-out, analytics
- [ ] **AVT-08h** Settings and deletion (Delete my avatar) (PR #92, D-78; merge after #88; needs human review: privacy)
- [ ] **T-DLY-03e** Daily plan settings (PR #93, D-79)
- [ ] **T-FND-10** Crashlytics with consent gating and no PHI; server logging and alerts (PR #94, D-80; agent tracing waits for the agents)
- [ ] **T-CMP-03** Download my data (PR #95, D-82; needs privacy and legal review; deploy needs Blaze)
- [x] **T-GOL-03** My Daily Routine (its reminders use the 3D avatar) (T-GOL-03a to 03e on main)

## Finishing partly done tasks (2026-11-15/16)

Each is one PR off `main`, waiting for review; none merged yet.

- [ ] **T-DLY-04** One daily cap of 4 across plan and routine reminders (PR #84, D-71)
- [ ] **T-FND-11** Feature flags from Remote Config, safe defaults per flavour (PR #85)
- [ ] **T-GOL-02** Manual weight, blood pressure, glucose and meals; 7/30/90-day charts (PR #86)
- [ ] **T-PRT-03** Portal card at the end of a lesson (PR #87, D-74, needs product sign-off)
- [ ] **T-FND-05** Server-side handling when a consent is revoked (PR #88, needs human review: consent)
- [ ] **T-VOC-02** "How this voice is made" in voice settings (PR #89)
- [ ] **T-TCH-01** FCM device registration and a capped, consent-checked server push (PR #90, D-77)

#92, #93, #94 and #95 all change the Profile screen: whichever merges second needs a rebase and new Profile goldens. Expected merge conflicts: #90 with #84 (`reminders.dart`, test fakes) and with #88 (rules, `index.ts`, `decisions.md`). After #84 and #90 merge, the app should report its scheduled reminders per day so the server stops assuming the worst case (D-77). After #88 and #90 merge, revoking the notifications consent should also delete `users/{uid}/devices` (D-77).

## Blocked

- **"Make me from my photo" in prod:** needs commercially licensed face-similarity and age checks (options in `docs/design/asset-licences.md`, none chosen), counsel review (T-CMP-02) and the `avatar_from_photo` flag. Build my own and the ready-made coaches don't depend on it.
- **Deploying the ComfyUI server and the Media Service:** needs the Blaze plan (billing for Cloud Run GPUs, D-17), then `docs/media/comfyui-setup.md`.
- **Push on real devices:** the code is in PR #90; the owner steps (enable FCM, upload the APNs key, Push capability on each App ID, deploy rules and functions) are in `docs/setup/push-notifications.md`. Personalised push copy ("Priya, …", FR-TCH-02) conflicts with "nothing personal on the lock screen" and needs the client (D-77).
- **Lessons:** the reader works but has no approved lessons; waiting on clinical content.
- **Assessment (T-ASM-01, then T-ASM-03 scoring and the Live Well Map):** not built. `content/assessment/` is empty. Needs the Blueprint 7.3 bank schema, the 7.5 banned-phrase list, the questions and the 8 driver names from the clinical team; the owner chose to wait for them (2026-11-16) rather than draft provisional content.
