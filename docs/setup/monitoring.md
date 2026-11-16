# Crash reporting and monitoring: owner steps (T-FND-10, D-80)

What the code already does:

- **App (Crashlytics).** `lib/core/monitoring/crash_reporting.dart`. Flutter errors and uncaught async errors go to Crashlytics as the **error type and stack trace only**. Messages are never sent, because a message can quote a mood, a note or a reflection. Breadcrumbs and custom keys come from fixed lists. No user id is set. Collection is **off** until the user grants the analytics consent (Profile > Privacy). It turns off again on revoke or sign-out, and cached reports are then deleted. In dev it also needs `--dart-define=LW_CRASH_REPORTS=true`. Android and iOS ship with collection off (manifest / Info.plist).
- **Core API (Cloud Functions).** `services/core-api/src/observability/log.ts`. Each function logs `fn.ok` / `fn.error` with `fn`, `code`, `duration_ms` and nothing else. Error messages are never logged. A callable that fails unexpectedly returns `internal` with a fixed message.
- **Media Service.** `services/media` logs only job ids, workflow names, status codes and durations (checked for D-80). Keep it that way: no prompts, image data, names or free text in `log.*` calls.
- **Alerts and dashboard as code.** `infra/terraform/monitoring` sets up an email channel, a log-based metric `core_api_fn_errors`, and three alerts: Core API function errors, 5xx responses on any Cloud Run / Functions service, and p95 latency over 2 s for 10 minutes. It also creates a "Live Well: Core API" dashboard.

Commands are PowerShell. Quote every path because the repo path has a space.

## 1. Turn on Crashlytics in each Firebase project

Do this for `my-livewell` (dev) now, and for staging and prod once those projects exist (D-63).

1. Firebase console > the project > **Release & Monitor > Crashlytics** > **Enable Crashlytics**, for the Android app and the iOS app.
2. Firebase console > Project settings > **Alerts** (or Crashlytics > the bell icon). Turn on email for *new fatal issue*, *regressed issue* and *velocity alert*. Send them to the same team inbox as the Terraform alerts.

No new config files are needed: `firebase_options.dart`, `google-services.json` and `GoogleService-Info.plist` stay as they are.

## 2. iOS symbol files (dSYM)

Without dSYMs, Dart frames still show correctly, but native iOS frames are not symbolicated. CI cannot build iOS with this step locally, so it is a manual step on the iOS build machine (Codemagic or a Mac).

- Simplest: run `flutterfire configure` once more for each flavour from `apps/mobile` (as in `docs/setup/firebase-windows.md`). With `firebase_crashlytics` in `pubspec.yaml`, FlutterFire offers to add the **"FlutterFire: flutterfire upload-crashlytics-symbols"** build phase to the Runner target. Answer yes, then commit the `project.pbxproj` change.
- Or by hand in Xcode: Runner target > Build Phases > **+ New Run Script Phase**, set the script to `"${PODS_ROOT}/FirebaseCrashlytics/run"`, and add the input files `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}` and `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`. Release must use *Debug Information Format = DWARF with dSYM File* (the Xcode default).

## 3. Android symbols (optional for now)

Dart stack traces don't need a mapping file. The Crashlytics Gradle plugin, which uploads the R8 mapping for Java/Kotlin frames, is **not** added yet. Its compatibility with AGP 9.1 can't be checked without an Android build here. If Java/Kotlin frames look obfuscated in the console, add `id("com.google.firebase.crashlytics")` to `android/settings.gradle.kts` (with a version) and `android/app/build.gradle.kts`, then build once.

If release builds ever use `--obfuscate --split-debug-info=build/symbols`, upload the Dart symbols too:
```powershell
firebase crashlytics:symbols:upload --app=<FIREBASE_APP_ID> "build/symbols"
```

## 4. Check that a test crash shows no PHI ("Done when", dev)

```powershell
cd "D:\Adii voult\Adii\LiveWell\apps\mobile"
flutter run --flavor dev -t lib/main_dev.dart --dart-define=LW_CRASH_REPORTS=true
```
1. Sign in, then **Profile > Privacy > turn on "Help improve the app"** (the analytics consent).
2. **Profile > Developer > Crash reporting** must say "Collection is ON".
3. Tap **Send a test error**, then **Throw an uncaught error**. Close the app fully and open it again, because reports are sent on the next start.
4. Within about 5 minutes, Crashlytics shows a `StateError` issue (reason `devTestError` / `uncaughtAsync`) with **no message**. In the issue, the logs and the keys there must be **no** `mood=2`, `sleep=4h` or `I feel awful today`: only the breadcrumb `devTestError` and the key `flavor = dev`. Take a screenshot for the PR.
5. Turn the analytics consent off, tap Send a test error again, and restart. No new event may arrive.

## 5. Alerts and dashboard (Terraform)

Install Terraform 1.6 or later (`winget install Hashicorp.Terraform`). Install the gcloud CLI and run `gcloud auth application-default login` with an account that can edit Monitoring and Logging on the project.

```powershell
cd "D:\Adii voult\Adii\LiveWell\infra\terraform\monitoring"
Copy-Item example.tfvars.example dev.tfvars   # then set alert_email (a team inbox)
terraform init
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```
- Expected: `Apply complete! Resources: 8 added` (2 APIs, channel, metric, 3 alert policies, dashboard).
- Google sends a **verification email** to the alert inbox. Click it, or the channel stays unverified.
- Repeat with `staging.tfvars` / `prod.tfvars` once those projects exist. State is local for now (`*.tfstate` is git-ignored). Keep the folder backed up, or move state to a GCS bucket when infra is set up properly.
- Console check: Monitoring > Alerting shows the three policies, and Monitoring > Dashboards shows "Live Well: Core API".

## Not done yet (see D-80)

- **Agent tracing** and **cost dashboard** (the rest of T-FND-10). `services/agents` has no code yet, and the framework is chosen in T-FND-03. When it lands, traces need inputs redacted and 30-day restricted retention (NFR-10, spec 9.1 rule 5). Cost per DAU needs the Cloud Billing export to BigQuery plus per-run token cost from the agent traces.
- An SLO object for NFR-04 (Core API 99.5% monthly). For now, the 5xx alert covers it.
