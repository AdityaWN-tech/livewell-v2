# Phase 0: Foundation (spec Section 18, Epic FND)

Goal: a safe base. Exit criteria (spec 18): CI and environments live; vendor ADRs approved; safety critical set at 100% on the agent skeleton.
Greenfield adjustments are in `decisions.md` (D-01).

## Step-by-step order
| # | Task | Done when | Status |
|---|---|---|---|
| S-1 | Monorepo per 17.2, AGENTS.md, decisions log | Folders exist; decisions D-01..D-12 recorded | Done 2026-10-12 |
| S-2 | Flutter app with dev/staging/prod flavors | `flutter analyze` clean, `flutter test` green, dev APK installs as `…livewell.dev` | Done 2026-10-12 |
| S-3 | Firebase CLI, login, FlutterFire, PATH (owner, `setup/firebase-windows.md` steps 1–4) | `firebase projects:list` shows my-livewell; `flutterfire --version` works | Done 2026-10-13 |
| S-4 | FlutterFire configure dev, Firebase init in `bootstrap.dart`, fingerprints, sign-in methods enabled | Dev app starts with Firebase on an Android device | Partly done 2026-10-13: configure, init and fingerprints done, verified on emulator. Google sign-in on; Firestore `(default)` Standard nam5 created and reached from the device (D-16). Left: confirm Email + Phone sign-in in the app, iOS plist (Mac) |
| S-5 | New private GitHub repo + first push | `git remote -v` shows the new repo | Done 2026-10-12: AdityaWN-tech/livewell-v2 (private) |
| S-6 | Brand: original logo, design tokens (colors, text, spacing, radius) | Logo in `assets/brand/`, `docs/brand.md`, tokens used everywhere | Done 2026-10-13: logo (D-15), tokens + theme, AA contrast tests, dev gallery |
| S-7 | Splash: flutter_native_splash + logo reveal (≤ budget in NFR-01) | Cold start to Home < 2.0 s on a mid-range device | Built 2026-10-13 (branch task/S-7-splash): native splash, reveal, Welcome/Home routing, tests. **Not yet verified:** look and NFR-01 timing on a real mid-range phone (the emulator is too slow to show or time it) |
| T-FND-01 | Requirements check (greenfield form, D-01) | `docs/audit.md`: every 10.4 "keep/refactor" item mapped to a v2 task | To do |
| T-FND-02 | CI (GitHub Actions: lint + tests), staging + prod Firebase projects, Terraform skeleton | CI green on an empty PR; dev, staging, prod deployable | To do |
| T-FND-03 | Vendor + framework spike (LangGraph vs ADK, TTS/clone, avatar, STT, LLM), ADRs | ADRs with 8.3 scorecards; morning-briefing prototype end to end | In progress: ADR-001 avatar, voice and liveness written 2026-10-28 (`docs/adr/`), scorecards still need vendor keys and the deployed Media Service; agent framework, LLM, cloud STT and vector search ADRs to do |
| T-FND-04 | go_router 5-tab shell (Home, Plan, Track, Learn, Care), Riverpod, design system components | All screens reachable; golden tests for core components | Done 2026-10-13: 5-tab shell (StatefulShellRoute), core components (LwScreen, LwSectionHeader, LwCard, LwTag, LwEmptyState), tab placeholders, goldens light + dark. Greenfield form of "prototype screens" = the 5 spec 14.2 tabs (D-01) |
| T-FND-05 | Consent service (append-only) + Settings UI | Grant/revoke every consent type; emulator tests; audit entries | Done 2026-10-13 (**awaiting human review**): 12 consent types (4 legal + 8 granular), append-only repository, Privacy and consents in Settings, audit trigger in services/core-api (interim store, D-18). Tests: unit/widget, functions emulator (5), on-device end to end through the real rules. Draft wording until T-CMP-01. Real-project use waits for the rules deploy (T-FND-06 review) and Blaze for the trigger |
| T-FND-06 | Firestore security rules + emulator tests (all Section 11 collections) | 100% rule coverage | Done 2026-10-13 (**awaiting human review**): rules for every Section 11 collection, 42 emulator tests, coverage gate 35/35 conditional allows + 20 constant denies asserted, mutation check passed, CI job. Not deployed: my-livewell keeps locked production rules until review |
| T-FND-07 | Migration of old prototype data | Dropped (D-01) | N/A |
| T-FND-08 | Drift + SQLCipher local DB + offline sync queue with idempotency keys | Offline log → reconnect syncs exactly once | To do |
| T-FND-09 | Audit log service (append-only) | Write-only service account; tamper test fails as expected | To do (human review) |
| T-FND-10 | Crashlytics with PHI scrubbing, agent tracing, cost dashboard | Test crash shows no PHI; sample trace visible | To do |
| T-FND-11 | Remote Config flags and kill switches | Each 10.2 flag toggles behaviour in staging | To do |
| T-ASM-02 / T-AGT-02 | Red-flag rules + safety pre/post with fixed templates | 15.3 critical cases 100% | T-ASM-02 done 2026-10-13 (**awaiting clinical review**): shared rules + 69 cases (critical 100%) in packages/safety-rules, Dart + Python engines, emergency/crisis cards with region numbers, notices, applied to the Why. Not yet: event logging (D-22), classifier and agent post-check (T-AGT-02) |

## Accounts to start now (slow to approve)
Apple Developer (organisation), Google Play Console, Anthropic API, a TTS vendor sandbox, TagMango API key and a test course (Q3). Prefer the client organisation's name as owner.

## Started early from Phase 1
| Task | Status |
|---|---|
| T-DLY-02 Daily check-in, mood first (FR-DLY-02) | Built 2026-10-14 (**awaiting human review: safety wording, response copy**): once-per-day bottom sheet, 6 steps (mood required), gentle-day rule (also enforced by the rules), red-flag check on the note (D-24), Home response from content/copy/checkin_responses.md, consent-gated analytics (D-23), offline via Firestore persistence (TODO T-FND-08). Check-in measured at 19-24 s on the emulator |
| T-ONB-02 Personal Why (FR-ONB-05) | Built 2026-10-13: typed, suggestions, voice typing behind the microphone consent (on-device recognizer), saved to the profile (rules: string, max 280), shown on Home; reopening at this step resumes there. Free text not yet safety-screened (D-21) |
| T-ONB-01 Onboarding + sign-in (FR-ONB-01..06) | Built 2026-10-13 (**awaiting human review**: legal copy, consent). Part 1: about, 18+ gate before sign-in (D-19), legal acceptance, resume at step. Part 2: phone OTP (+91/+1), email (sign in, create, reset), Google (Firebase provider flow), Apple (iPhone only, needs Apple Developer account); profile + 4 legal consents created after sign-in; under-18 after sign-in deletes the account. Tests: 101 app tests, device end to end on emulators (email, wrong password, +91 OTP). **Not yet:** biometric unlock toggle (FR-ONB-01), real-project use needs the T-FND-06 rules deployed |
