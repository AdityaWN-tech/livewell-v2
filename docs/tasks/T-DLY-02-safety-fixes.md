# T-DLY-02 follow-up: check-in safety fixes (D-70)

Branch `task/T-DLY-02-safety-fixes`, from `main` at `1cd51c3` (PR #80). Tag: **needs human review (safety)**.
Built and tested on the Linux laptop on 2026-11-04. Not pushed yet.

## Problems fixed

| # | Problem on `main` | Fix |
|---|---|---|
| 1 | The check-in was saved only at the end. Choosing "Very low" and closing the sheet saved nothing, so the day wasn't gentle | Saved after mood and after each answer, one save at a time to the same daily document. The note is never saved early |
| 2 | A crisis or emergency note: nothing was saved until the card was closed, and the card waited on a network look-up of the region | Gentle day (no text) saved before the card shows. Region comes from the loaded profile, else a 2 s look-up, else both countries |
| 3 | A same-day redo with a better mood could clear a gentle day | Sticky in the app and in `firestore.rules` (update can't change `gentle_day` from true to false) |
| 4 | The safety hold was in memory only and lost on restart; no 72-hour block on the phone | Time of the last red flag kept on the phone (`SafetyEventStore`, no text). Hold survives a restart; `safetyClearProvider` blocks portal cards for 72 h |
| 5 | Portal cards treated a loading check-in as "not gentle" | `portalGentleDay`: loading or error counts as gentle |
| 6 | If the red-flag rules failed to load, the sheet stayed stuck | The note isn't saved, the day counts as gentle, other answers are saved, and the user sees a message with Try again |
| 7 | Test setup loaded `materialicons-regular.otf`, but the file is `MaterialIcons-Regular.otf` (icons were boxes on Linux; fine on Windows, which ignores case) | Real filename. Windows loads the same file, so golden masters are unaffected |

Note: real (staging/prod) accounts already got **no** portal cards on `main`, because the server safety
record doesn't exist yet (D-22). Fixes 4 and 5 make the gate stay correct once it does.

## Tests (Linux, 2026-11-04)

| Check | Result |
|---|---|
| Baseline on unchanged `main` | analyze clean; 1102 passed, 4 skipped |
| `flutter analyze` | No issues |
| `dart format --set-exit-if-changed lib test integration_test` | Clean |
| `flutter test --exclude-tags golden` | **1117 passed**, 4 skipped, 0 failed (15 new in `test/checkin/checkin_safety_fixes_test.dart`) |
| `cd firebase && npm test` (emulator, `demo-livewell`) | **94/94 passed**; rule coverage **54/54** |
| Mutation checks (each fix undone, then restored byte for byte) | Each one made its regression test fail: early save (4 tests), save before the card, sticky gentle in the app, rules-load failure, portal loading, sticky gentle in the rules |
| Android device test `integration_test/checkin_emulator_test.dart` (emulator-5554, API 37, Auth + Firestore emulators) | **3/3 passed**: offline submit then reconnect syncs exactly once; online re-submit keeps one record and its `created_at`; the rules refuse a low-mood day marked not gentle |
| Dev debug APK (`flutter build apk --debug --flavor dev -t lib/main_dev.dart`) | Built; attached to the GitHub pre-release `t-dly-02-safety-fixes-dev-apk` (SHA-256 `f06e1faf01724e3130826e0d6c41dc4793cea556586589e26b54f80c547da45f`) |
| Goldens | Not run here; recorded and compared on Windows CI (no golden images changed) |

One existing assertion changed: `checkin_flow_test.dart` "saved once" asserted exactly 1 save call.
With saving after each answer, a full check-in makes several calls to the same document. It now asserts
that only today's record exists (`days.keys == [today]`). One record per day is still checked on a real
Firestore by `integration_test/checkin_emulator_test.dart`.

## To run on the Android emulator (one emulator; close the browser first)

```bash
JAVA_TOOL_OPTIONS="-Xmx512m" firebase emulators:exec --only auth,firestore,functions --project my-livewell \
  "cd apps/mobile && flutter test integration_test/checkin_emulator_test.dart --flavor dev -d emulator-5554"
```

## Privacy and security

- New on the phone: one SharedPreferences number (time of the last red flag). No text, no category; not sent
  to analytics, logs or the server. Cleared by uninstalling the app (TODO: clear on sign-out / account deletion
  with T-FND-08).
- The note is still never saved when it holds an emergency, crisis or disordered-eating red flag, and is never
  part of an early save.
- Logs: only `LW checkin_save_failed <error type>`, no answers.
- Rules are stricter (gentle is sticky); nothing deployed.

## Known limits

- Offline, each save waits up to ~6 s (existing repository timeouts). Saves run in the background except
  the final one on Done, which can wait for one in-flight save first.
- The 72-hour block uses this phone's clock and record only; the server record (D-22) is still needed for
  real accounts and other devices.
- For the coach only, a phone record still loading at start counts as no hold for a few milliseconds.

## Resume here (status 2026-11-04, after the device test)

- Committed and pushed on branch `task/T-DLY-02-safety-fixes`; PR opened (needs human review, safety).
- Done: all fixes above; Flutter, rules, mutation and Android device tests passed on Linux; dev APK built.
- Remaining:
  1. Windows CI goldens on the PR.
  2. Human safety review of D-70, then merge.
  3. Owner decision: GitHub shows the repo as **public**, AGENTS.md and D-11 say private.
