# Phase 0: Foundation (spec Section 18, Epic FND)

Goal: a safe base. Exit criteria (spec 18): CI and environments live; vendor ADRs approved; safety critical set at 100% on the agent skeleton.
Greenfield adjustments are in `decisions.md` (D-01).

## Step-by-step order
| # | Task | Done when | Status |
|---|---|---|---|
| S-1 | Monorepo per 17.2, AGENTS.md, decisions log | Folders exist; decisions D-01..D-12 recorded | Done 2026-10-12 |
| S-2 | Flutter app with dev/staging/prod flavors | `flutter analyze` clean, `flutter test` green, dev APK installs as `…livewell.dev` | Done 2026-10-12 |
| S-3 | Firebase CLI, login, FlutterFire, PATH (owner, `setup/firebase-windows.md` steps 1–4) | `firebase projects:list` shows my-livewell; `flutterfire --version` works | Done 2026-10-13 |
| S-4 | FlutterFire configure dev, Firebase init in `bootstrap.dart`, fingerprints, sign-in methods enabled | Dev app starts with Firebase on an Android device | Partly done 2026-10-13: configure, init and fingerprints done, verified on emulator. Left: sign-in methods + Firestore nam5 (console), iOS plist (Mac) |
| S-5 | New private GitHub repo + first push | `git remote -v` shows the new repo | Done 2026-10-12: AdityaWN-tech/livewell-v2 (private) |
| S-6 | Brand: original logo, design tokens (colors, text, spacing, radius) | Logo in `assets/brand/`, `docs/brand.md`, tokens used everywhere | Logo redrawn (D-15, `docs/brand.md`); tokens next |
| S-7 | Splash: flutter_native_splash + logo reveal (≤ budget in NFR-01) | Cold start to Home < 2.0 s on a mid-range device | Chosen: "Three words" (D-13); ready to build |
| T-FND-01 | Requirements check (greenfield form, D-01) | `docs/audit.md`: every 10.4 "keep/refactor" item mapped to a v2 task | To do |
| T-FND-02 | CI (GitHub Actions: lint + tests), staging + prod Firebase projects, Terraform skeleton | CI green on an empty PR; dev, staging, prod deployable | To do |
| T-FND-03 | Vendor + framework spike (LangGraph vs ADK, TTS/clone, avatar, STT, LLM), ADRs | ADRs with 8.3 scorecards; morning-briefing prototype end to end | To do (needs vendor keys) |
| T-FND-04 | go_router 5-tab shell (Home, Plan, Track, Learn, Care), Riverpod, design system components | All screens reachable; golden tests for core components | To do |
| T-FND-05 | Consent service (append-only) + Settings UI | Grant/revoke every consent type; emulator tests; audit entries | To do (human review) |
| T-FND-06 | Firestore security rules + emulator tests (all Section 11 collections) | 100% rule coverage | To do (human review) |
| T-FND-07 | Migration of old prototype data | Dropped (D-01) | N/A |
| T-FND-08 | Drift + SQLCipher local DB + offline sync queue with idempotency keys | Offline log → reconnect syncs exactly once | To do |
| T-FND-09 | Audit log service (append-only) | Write-only service account; tamper test fails as expected | To do (human review) |
| T-FND-10 | Crashlytics with PHI scrubbing, agent tracing, cost dashboard | Test crash shows no PHI; sample trace visible | To do |
| T-FND-11 | Remote Config flags and kill switches | Each 10.2 flag toggles behaviour in staging | To do |
| T-ASM-02 / T-AGT-02 | Red-flag rules + safety pre/post with fixed templates | 15.3 critical cases 100% | To do (India + US sets, D-03) |

## Accounts to start now (slow to approve)
Apple Developer (organisation), Google Play Console, Anthropic API, a TTS vendor sandbox, TagMango API key and a test course (Q3). Prefer the client organisation's name as owner.
