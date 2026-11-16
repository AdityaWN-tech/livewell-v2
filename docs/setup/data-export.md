# Download my data: owner steps (T-CMP-03, D-82)

What it is: Profile > Privacy & data > "Request a copy of my data" asks the
core-api to build a zip (data.json, summary.pdf, README.txt) of everything the
person has in Firestore, kept 7 days in Cloud Storage and downloaded through a
15-minute signed link. Code: `services/core-api/src/account/data-export.ts`.

Needs the **Blaze plan** (Cloud Functions and Cloud Storage). Do these once per
project (dev `my-livewell`, then staging, then prod). PowerShell, from the repo
root; quote paths (the repo path has a space). Replace `PROJECT` with the
project id.

## 1. Turn on Cloud Storage
Firebase console > Build > Storage > Get started > production mode, location
**US (multi-region)** (next to the nam5 database). The default bucket is then
`PROJECT.firebasestorage.app` (older projects: `PROJECT.appspot.com`):
```powershell
gcloud storage buckets list --project PROJECT --format="value(name)"
```

## 2. Storage rules (no client access)
```powershell
firebase deploy --only storage --project PROJECT
```
Expected: `storage: released rules firebase/storage.rules`. From now on a plain
`firebase deploy` also deploys these rules, so step 1 must come first.

## 3. Delete exports after 7 days (lifecycle rule)
```powershell
gcloud storage buckets update gs://BUCKET --lifecycle-file="firebase/storage-lifecycle.json"
gcloud storage buckets describe gs://BUCKET --format="default(lifecycle_config)"
```
Expected: one rule, action `Delete`, condition `age: 7`, `matchesPrefix: exports/`.
Google deletes matching files within about a day after they turn 7 days old;
the app and `getDataExportLink` stop offering the file at `expires_at`
(exactly 7 days) either way.

## 4. Let the functions sign download links
The functions run as the default compute service account. It needs to sign
for itself (V4 signed URLs without a key file):
```powershell
gcloud services enable iamcredentials.googleapis.com --project PROJECT
$num = gcloud projects describe PROJECT --format="value(projectNumber)"
$sa = "$num-compute@developer.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding $sa --member="serviceAccount:$sa" --role="roles/iam.serviceAccountTokenCreator" --project PROJECT
```

## 5. Deploy the Firestore rules and the functions
```powershell
firebase deploy --only firestore:rules --project PROJECT
firebase deploy --only functions:core-api --project PROJECT
```
Expected new functions: `requestDataExport`, `onDataExportRequested`,
`getDataExportLink` (us-central1).

## 6. Staging check ("Done when": FR-SET-02 SLAs met in a staging test)
1. On a staging build, sign in with a **test** account that has check-ins, a
   plan and a few messages (never a real person's account).
2. Profile > Privacy & data > Request a copy of my data > Prepare my file.
   Note the time. It should turn "ready" within minutes (the SLA is 72 hours).
3. Download, open the zip: `data.json` has the profile and the test data,
   `summary.pdf` opens and lists counts, nothing from another account.
4. Firestore console: `audit_log` has `data_export.requested`, `.ready` and
   `.link_issued` for the test uid, with counts only.
5. Tap Prepare again: "once a day" message.
6. Record the times and screenshots in the PR or `docs/evidence/`.

If an export fails, the job shows "failed" and the person can try again; Cloud
Logging has `data_export: build failed` with the job id and error name only.
