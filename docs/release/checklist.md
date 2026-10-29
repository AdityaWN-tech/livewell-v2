# Release checklist: closed beta (Step 7, D-63)

What is ready in code, and the steps only the owner can do (accounts, keys, uploads). Do them in order. Each step says what you should see.

> **Hard to undo:** the app id `net.conciergeconnectedcare.livewell` is permanent once uploaded (D-06, still "needs client"). The upload key must never be lost. Confirm both before step 3.

## 0. Before anything: what must be signed off

| Item | Status (2026-10-29) | Blocks |
|---|---|---|
| T-CMP-01 lawyer review of Terms, Privacy, Medical Disclaimer, AI Disclosure | Not done (drafts `content/legal/*-0.1-draft.md`) | Beta (users accept these) |
| T-CMP-02 counsel review: photo avatar, voice clone | Not done; both are flagged **off** | Only those features |
| Safety critical set at 100% (§15.3) | Passing in CI (`packages/safety-rules`, `safety_rules_test.dart`) | Beta |
| T-CMP-04 penetration test | Not done | Public launch (beta: owner's call) |
| T-REL-01 accessibility audit (WCAG 2.2 AA) | Not done; automated checks pass (tap targets, labels, contrast in tests) | Public launch |
| Clinical review: coach scripts, routine lines, breathing timings, lessons | Pending (`content/*/REVIEW.md`); prod uses **approved only** | What prod users see |
| Client: logo file (D-15), app id (D-06), support/privacy email (D-56) | Waiting on client | Store listing |

## 1. Create the production Firebase project (owner)

1. https://console.firebase.google.com → Add project → name **livewell-prod** → Analytics on (collection stays off until consent, FR-ONB-03).
2. Upgrade to **Blaze** (needed for Functions later; set a budget alert).
3. Authentication → Sign-in method: enable **Email/Password, Phone, Google, Apple**.
4. Firestore → Create database, **Standard**, location **nam5** (D-16).
5. Project settings → **Play Integrity** API enabled in Google Cloud for the project (phone sign-in, D-58).

Then connect the app (PowerShell):

```powershell
cd "D:\Adii voult\Adii\LiveWell\apps\mobile"
firebase login --reauth
flutterfire configure `
  --project=livewell-prod `
  --platforms=android,ios `
  --android-package-name=net.conciergeconnectedcare.livewell `
  --ios-bundle-id=net.conciergeconnectedcare.livewell `
  --out="lib/firebase/firebase_options_prod.dart" `
  --android-out="android/app/src/prod/google-services.json" `
  --yes
```
Expected: the prod apps are registered and both files are written (same as dev, `docs/setup/firebase-windows.md` §5). Then tell Claude to wire it: `lib/firebase/firebase_options.dart` returns `null` for prod until then (`Flavor.prod => prod.DefaultFirebaseOptions.currentPlatform`), so a prod build stops at launch on purpose.

Deploy the rules and indexes to prod:
```powershell
cd "D:\Adii voult\Adii\LiveWell\firebase"
firebase deploy --only firestore:rules,firestore:indexes --project livewell-prod
```
Expected: `Deploy complete!`

## 2. Make the upload key (owner, once, keep it safe)

```powershell
& "D:\android\jbr\bin\keytool.exe" -genkeypair -v -keystore "D:\Adii voult\Keys\livewell-upload.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Choose a strong password. **Back up the `.jks` file and the password in two places** (for example a password manager and an encrypted USB drive). If it's lost, Play App Signing can reset the upload key, but it takes days.

Create `apps\mobile\android\key.properties` (ignored by git, never commit it):
```
storeFile=D:\\Adii voult\\Keys\\livewell-upload.jks
storePassword=<your password>
keyAlias=upload
keyPassword=<your password>
```
The release build now signs with it (`android/app/build.gradle.kts`); without the file it falls back to the debug key, which Play rejects.

Fingerprints for Firebase:
```powershell
& "D:\android\jbr\bin\keytool.exe" -list -v -keystore "D:\Adii voult\Keys\livewell-upload.jks" -alias upload
```
Add the **SHA-1 and SHA-256** to livewell-prod → Project settings → Android app. After the first Play upload, also add the **Play App Signing** key's SHA-1 and SHA-256 (Play Console → Test and release → App integrity). Without them Google sign-in fails and phone codes fall back to the broken browser check (D-58).

## 3. Build the release

```powershell
cd "D:\Adii voult\Adii\LiveWell\apps\mobile"
flutter test
flutter build appbundle --release --flavor prod -t lib/main_prod.dart
```
Expected: `√ Built build\app\outputs\bundle\prodRelease\app-prod-release.aab`. Bump `version:` in `pubspec.yaml` for every upload.

## 4. Google Play (owner)

1. Play Console → Create app "Live Well", free, app.
2. **App content:** privacy policy URL (needs the reviewed policy hosted), ads: none, **data safety** (see below), health apps declaration, target audience **18+**.
3. **Health Connect** declaration: steps + sleep, read only, why: "shows the person's own steps and sleep in Track" (D-59).
4. Test and release → **Closed testing** → create track, add testers (email list, 50–100), upload the `.aab`.
5. Expected: review in a few days; testers get an opt-in link.

**Data safety answers (from the code):** collected: email, name, phone (optional), app activity (check-ins, habits, reflections, routine), health and fitness (check-in mood/sleep/stress answers; steps and sleep from Health Connect are **read on the phone and not collected**), voice: none stored. Encrypted in transit; users can request deletion (account deletion in Profile). Not shared with third parties for ads. Analytics only after consent.

## 5. iPhone: TestFlight (owner + Codemagic)

1. Apple Developer → App IDs for prod with **Push, Sign in with Apple, App Groups, HealthKit** (`docs/ios-build-setup.md`), and the widget App ID.
2. App Store Connect → new app, bundle id `net.conciergeconnectedcare.livewell`.
3. Build and upload through Codemagic (memory: GitHub Actions is blocked on billing).
4. TestFlight → internal testers first, then an external group (needs Beta App Review).

## 6. What to tell beta testers is not in this build

Coach chat and voice conversation, voice cloning, photo avatar, recorded audio sessions, server push notifications, Remote Config (flags are fixed per build), the Live Well portal card for real accounts (needs D-22 safety events), manual weight/BP/glucose entry, and 30/90-day charts. Lessons appear only once clinically approved.
