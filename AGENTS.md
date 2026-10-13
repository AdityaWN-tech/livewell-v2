# AGENTS.md: rules for anyone (human or AI) writing code in this repo

Live Well v2 "Companion" for Dr. Murthy Gokula. Read this before every task (spec 17.1).

## Sources of truth, in order
1. `docs/decisions.md`: agreed changes to the spec. Rows marked *needs client* are not final until signed off.
2. `docs/spec/LiveWell_v2_Specification.pdf`: the product and technical spec (v1.0 draft, 2026-09-30).
3. `docs/data-model.md` and `docs/api/openapi.yaml` once they exist.

If a request conflicts with the spec, say so and stop before writing code.

## Fixed stack (changes need the owner's approval, recorded in docs/decisions.md)
| Part | Stack |
|---|---|
| Mobile (iOS + Android) | Flutter, Riverpod, go_router, Drift + SQLCipher (encrypted local DB) |
| Auth, data, push | Firebase Auth (email, Google, Apple, phone OTP), Firestore, FCM/APNs, App Check, Remote Config |
| Core API | TypeScript (strict, zod) on Cloud Functions 2nd gen or Cloud Run |
| Agents | Python (ruff, mypy, pydantic I/O), LangGraph or Google ADK (chosen in T-FND-03), Cloud Run |
| Watch | Native watchOS (SwiftUI) and Wear OS (Kotlin + Compose) |
| Widgets | iOS WidgetKit, Android Jetpack Glance |
| Admin, voice-owner page | Flutter Web or Next.js (chosen in T-FND-03) |
| Infra | Terraform; three Firebase/GCP projects (dev, staging, prod); GitHub Actions |

## Working agreement
1. One task per branch: `task/<TASK-ID>-short-name` (e.g. `task/T-FND-04-app-shell`). The PR quotes the task's "Done when" and shows evidence.
2. Read first: this file, the spec sections for the task, and existing code. Don't duplicate.
3. Tests are part of the task. Safety-related code also needs evaluation cases.
4. Never commit secrets, real user data, vendor keys or PHI. Use `.env.example` and Secret Manager references. Firebase *client* config files are allowed.
5. **Never weaken a safety rule, consent check, frequency cap or the closed-script voice rule to make a test pass.** Stop and flag it.
6. Ambiguous requirement: implement the most conservative option and record the question in docs/decisions.md.
7. Conventions: Dart (effective_dart, Riverpod, feature-first folders); TypeScript (strict, zod); Python (ruff, mypy, pydantic).
8. API change: update `docs/api/openapi.yaml`. Data change: update `docs/data-model.md` and add a migration.
9. Human review is required for safety, consent, security, payments and legal-copy tasks.

## Design rules (mobile)
- Use only the design tokens in `apps/mobile/lib/core/design/` (colors, text styles, spacing, radius). No raw colors or sizes in feature code.
- Look at `apps/mobile/assets/design-reference/` before building a screen. If an image can't be seen, ask the owner to upload it; never guess.
- Feel (spec 14.1): warm, hopeful, calm, premium, inclusive. Never fear-based or overly clinical.
- One primary action per screen (spec 4.1).

## Data rules (mobile)
- Get Firestore only from `firestoreProvider` (`lib/core/data/firestore.dart`), never `FirebaseFirestore.instance` (D-16; a test enforces this).

## Safety rules that can never be removed
- Markets are India and US (D-03). Emergency (IN 112 / US 911) and crisis (IN Tele-MANAS 14416 / US 988) routing is plain code, runs before any AI, uses fixed templates and the neutral voice.
- Never guess a user's region silently: a wrong guess shows the wrong emergency number.
- No medication or dose-change advice. No cure or reversal promises. No portal content in, or within 72 h of, a safety event.
- Cloned voices only speak text with an approved `message_id` (closed-script rule).

## Layout (spec 17.2)
```
apps/mobile/            Flutter app (lib/core, lib/features/<feature>/), widgets, iOS watch app
apps/wear/              Wear OS app
apps/admin/             Admin / CMS web
apps/voice-owner-web/   Loved-one voice consent web flow
services/core-api/      TypeScript API
services/agents/        Python agents (prompts/, evals/)
services/media/         TTS and avatar adapters and jobs
services/portal-bridge/ TagMango webhooks and deep links
packages/schemas/       Shared JSON Schemas (CoachMessage, ...)
content/                Lessons, assessment bank, legal texts (versioned)
firebase/               Firestore rules, indexes and their emulator tests
infra/terraform/        Cloud resources
docs/                   Spec, decisions, setup guides, API, data model, ADRs
```

## Commands (PowerShell; quote every path, the repo path has a space)
| What | Command |
|---|---|
| Mobile analyze + tests | `cd "D:\Adii voult\Adii\LiveWell\apps\mobile"; flutter analyze; flutter test` |
| Golden images only / update them | `flutter test --tags golden` / `flutter test --update-goldens --tags golden` |
| Firestore smoke test on a device | `flutter test integration_test/firestore_smoke_test.dart --flavor dev -d DEVICE` |
| Firestore rules tests (emulator + coverage gate) | `cd firebase; $env:JAVA_HOME="D:\android\jbr"; npm test` (JAVA_HOME = the `jbr` folder inside your Android Studio / Android SDK install) |
| Core API / functions tests (Firestore + Functions emulators) | `cd services/core-api; npm test` (needs JAVA_HOME as above) |
| Consent end to end on a device (emulators) | from repo root: `firebase emulators:exec --only auth,firestore,functions --project my-livewell "cd apps/mobile && flutter test integration_test/consent_emulator_test.dart --flavor dev -d DEVICE"` |
| CI (GitHub Actions) | `.github/workflows/mobile.yml`: Linux runs everything except goldens; Windows runs goldens |
| Run dev flavor | `flutter run --flavor dev -t lib/main_dev.dart` |
| Build dev APK | `flutter build apk --debug --flavor dev -t lib/main_dev.dart` |
| Staging / prod | same with `staging` / `prod` and `lib/main_staging.dart` / `lib/main_prod.dart` |

## Developer-only UI

- Any developer tool, debug button, test screen or sample data must appear ONLY in the dev flavour. It must not render, and its route must not be registered, in staging or prod builds.
- Developer entry points live in Settings > Developer (dev flavour only), never on Home.
- Every dev-only feature needs a widget test proving it is hidden in prod.

## Sensitive values in logs and analytics

- Never send mood, energy, sleep, stress, health metrics or any free text (Why, barrier notes, reflections, chat) to analytics, Crashlytics or logs. Log only event names, IDs, counts and durations.
- Nothing personal or health-related appears in notifications or on the lock screen.

## Task files

- Task prompts live in `docs/tasks/<TASK-ID>-short-name.md`.
- When asked to "do the task in docs/tasks/...", follow that file plus this AGENTS.md. If they conflict, this AGENTS.md wins; flag the conflict in the PR.
