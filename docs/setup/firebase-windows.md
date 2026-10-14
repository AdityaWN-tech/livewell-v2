# Firebase + FlutterFire setup on Windows (PowerShell)

Dev project: `my-livewell`. Paths have a space, so always quote them.

## 1. Install the Firebase CLI
Node 24 and npm are already installed, and npm's global folder (`%APPDATA%\npm`) is already on PATH.
```powershell
npm install -g firebase-tools
firebase --version
```

## 2. Log in (opens the browser)
```powershell
firebase login
firebase projects:list   # my-livewell must be listed
```
In Claude Code you can type `! firebase login` so it runs in the session.

## 3. Install the FlutterFire CLI
```powershell
dart pub global activate flutterfire_cli
```

## 4. Fix PATH for FlutterFire (once)
`dart pub global` installs tools in `%LOCALAPPDATA%\Pub\Cache\bin`, which is not on PATH yet on this PC.
```powershell
$bin = "$env:LOCALAPPDATA\Pub\Cache\bin"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$bin", 'User')
}
```
Close **all** terminals (and restart VS Code / Claude Code) so they pick up the new PATH, then check:
```powershell
flutterfire --version
```

## 5. Configure the dev flavor (instead of the plain command Firebase showed)
The plain `flutterfire configure --project=my-livewell` writes one config for one app. With flavors, each environment needs its own app ids and files:
```powershell
cd "D:\Adii voult\Adii\LiveWell\apps\mobile"
flutterfire configure `
  --project=my-livewell `
  --platforms=android,ios `
  --android-package-name=net.conciergeconnectedcare.livewell.dev `
  --ios-bundle-id=net.conciergeconnectedcare.livewell.dev `
  --out="lib/firebase/firebase_options_dev.dart" `
  --android-out="android/app/src/dev/google-services.json" `
  --yes
```
This registers the Android and iOS dev apps in Firebase and writes the Dart options plus the Android file. The iOS `GoogleService-Info.plist` placement step edits the Xcode project, which needs a Mac (see `ios-without-mac.md`); on Windows it can be skipped or may fail without harm.

**Done for dev (2026-10-13):** Android app `1:623153208660:android:40b0bdefc8ad3a227ffcc1`, iOS app `1:623153208660:ios:ccdfebe26e2d05ac7ffcc1`. The iOS plist was not written (needs a Mac).

**Windows build note:** the pub cache (C:) and the project (D:) are on different drives, which corrupts Kotlin incremental caches ("Storage … is already registered"). `android/gradle.properties` therefore sets `kotlin.incremental=false`.

## 6. Android fingerprints (needed for Google sign-in and phone OTP)
```powershell
cd "D:\Adii voult\Adii\LiveWell\apps\mobile\android"
.\gradlew signingReport
```
Copy the **SHA-1** and **SHA-256** of the `devDebug` variant into Firebase console → Project settings → the `.dev` Android app → Add fingerprint. Release keys are added later.
Done for dev with the CLI: `firebase apps:android:sha:create <appId> <sha> --project my-livewell` (debug SHA-1 and SHA-256).
After turning on Google sign-in (step 7), re-run step 5 so `google-services.json` picks up the OAuth client.

## 7. Turn on sign-in methods (Firebase console → Authentication → Sign-in method)
- Email/Password: on.
- Google: on (set the support email).
- Phone: on. Add **test phone numbers** (e.g. +91 99999 00001 / code 123456) for development so no real SMS is sent. Real SMS volume needs the pay-as-you-go **Blaze** plan; check the console's current terms before beta.
- Apple: needs an Apple Developer account (Services ID + key). Can wait until the iOS work.

## 8. Create the Firestore database
Edition **Standard** (not Enterprise), database ID **`(default)`** exactly (with brackets), location **nam5 (United States)** (D-14, permanent), **production mode** (locked rules; our own rules come in T-FND-06).
CLI equivalent: `firebase firestore:databases:create "(default)" --location nam5 --edition standard --delete-protection ENABLED --project <id>` (works on the free plan only when no other database holds the project's free tier).
Check from a device: `flutter test integration_test/firestore_smoke_test.dart --flavor dev -d <device>` must print `FIRESTORE_SMOKE permission-denied` (connected, rules locked). See D-16.

## When to create staging and prod
Spec T-FND-02 expects dev, staging and prod deployable by the end of Phase 0. Create them **after** the dev flavor works end to end (sign-in on a device) and **before** T-FND-02 is closed. Create them in the client organisation's Google account if possible (moving projects later is painful). Then repeat step 5 with `staging` / `.stg` and `prod` / no suffix, and fill in `firebaseProjectId` in `lib/core/config/flavor.dart`.
