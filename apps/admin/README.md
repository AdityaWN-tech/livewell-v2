# Live Well Admin / CMS (Flutter Web)

Internal staff console (spec 10.2; ADR-003, D-90). First feature: the
**portal catalog** (T-PRT-02, D-92). Static web app for Firebase Hosting;
nothing is deployed by this repo yet.

## How it is built

- Flutter Web, Riverpod, go_router, effective_dart (`flutter_lints`).
- **No Firestore access.** Every read and write goes through Core API
  callables (`services/core-api/src/portal/`), which check the staff role,
  the MFA gate and write the audit log. A test fails if `cloud_firestore`
  shows up here.
- Design tokens (`lib/core/design/tokens.dart`, `typography.dart`,
  `theme.dart`) are **copies** of `apps/mobile/lib/core/design/`; a test
  fails when they drift. Copy the files again after changing the app's.
  Console-only layout sizes are in `lib/core/design/admin_layout.dart`.
- The offer preview (`PortalCardPreview`) draws the app's portal card with
  the same tokens and words; keep it in step with
  `apps/mobile/lib/features/learn/presentation/portal_card.dart`.
- Accessibility: `ensureSemantics()` at start (Flutter Web leaves screen
  readers off otherwise), labelled fields and buttons, keyboard order, and
  tap-target / label / contrast checks in the widget tests.

## Roles and access

| Role (`staff_roles` claim) | Can |
|---|---|
| `content_editor` | create, edit, send for review, withdraw, **publish approved offers**, take offline, archive, restore |
| `clinical_reviewer` | approve or ask for changes; take offline |
| `safety_reviewer` | view; take offline |
| `admin` | everything above |

Nobody approves a version they edited or sent for review (two-person rule).
Any edit takes a live offer out of the app and back to draft.

**MFA.** The Core API refuses staff calls unless the sign-in used a second
factor (Identity Platform) or the owner set a time-limited waiver
(`staff_mfa_waiver_until`, at most 30 days). The method is still an owner
decision (D-90, D-92); this console signs in with email and password only.

Set roles (owner only, with your own Google credentials; the person signs
out and in again afterwards):

```
cd services/core-api
node scripts/set-staff-claims.mjs --project my-livewell --email someone@example.org --roles content_editor --mfa-waiver-days 7
node scripts/set-staff-claims.mjs --project my-livewell --email someone@example.org --roles none
```

## Run

Tests and checks (same as CI, `.github/workflows/admin.yml`):

```
cd apps/admin
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Against the local emulators (demo project, no real data). From the repo
root, start Auth, Firestore and Functions, make a staff user in the Auth
emulator and give it roles (Admin SDK with `FIREBASE_AUTH_EMULATOR_HOST`),
then:

```
firebase emulators:start --only auth,firestore,functions --project demo-livewell
cd apps/admin && flutter run -d chrome --dart-define=LW_USE_EMULATORS=true
```

Against a real project, pass the **web app's client config** (identifiers,
not secrets; register a Web app in the Firebase project first):

```
flutter build web --release \
  --dart-define=LW_FIREBASE_API_KEY=... \
  --dart-define=LW_FIREBASE_APP_ID=... \
  --dart-define=LW_FIREBASE_PROJECT_ID=my-livewell \
  --dart-define=LW_FIREBASE_SENDER_ID=... \
  --dart-define=LW_FIREBASE_AUTH_DOMAIN=my-livewell.firebaseapp.com
```

Without them the page says the build has no Firebase settings.

## Staff access: request → Superadmin approves (D-112, free plan)

No Cloud Functions are needed; the Firestore rules (`firebase/firestore.rules`, tested in `firebase/test/rules.test.ts`) are the guard.

1. Deploy the rules once: `firebase deploy --only firestore:rules --project my-livewell`.
2. Turn on **Google** as a sign-in method (Firebase console → Authentication → Sign-in method).
3. Sign in to this console with **Continue with Google** using your @whitenoiseacademy.com account.
4. Make that account a Superadmin (owner only, on your laptop, after `gcloud auth application-default login`):
   `cd services/core-api && node scripts/set-superadmin.mjs --project my-livewell --email you@whitenoiseacademy.com`
5. Sign out and in again: you land on **Superadmin** (Requests, Admins, Content, Activity).
6. On **Admins**, tap **Roles** and give at least one person **Clinical reviewer**. Until then nothing can be approved, so nothing goes live (D-118).

Anyone else who signs in sees **Request admin access**, then **Waiting for approval**, and gets the console only after a Superadmin taps **Approve**. Admins never see app users' data.

### Staff roles (D-118)

| Role | Can |
|---|---|
| Content editor | write lessons, courses, Map driver names and questions; submit them for review (new Admins start with this) |
| Clinical reviewer | approve or send back what **someone else** wrote (2-person rule) |
| Safety reviewer | label only for now; any Admin can retire a live item |

The Firestore rules check the Clinical reviewer role, not the console. Role changes show in **Activity**.
