# Push notifications (FCM / APNs): owner setup

T-TCH-01, D-77. The code is in place (app registration, `sendPush`, the `onPushRequest` trigger, rules). **Real devices get nothing until these steps are done** in each Firebase project (dev `my-livewell`, then staging and prod). Paths have a space, so quote them (PowerShell).

## What needs the owner

| # | Step | Where | Why |
|---|---|---|---|
| 1 | Blaze plan on the project (already needed for Cloud Functions) | Firebase console > Usage and billing | `onPushRequest` is a Cloud Function |
| 2 | Turn on the **Firebase Cloud Messaging API (V1)** | Firebase console > Project settings > Cloud Messaging (or Google Cloud console > APIs > "Firebase Cloud Messaging API") | The Admin SDK sends through it |
| 3 | Create an **APNs authentication key** (.p8): Certificates, Identifiers & Profiles > Keys > "+" > Apple Push Notifications service. Note the **Key ID** and your **Team ID**. Keep the .p8 in the password manager, never in the repo | developer.apple.com | Apple only delivers pushes that FCM signs with this key |
| 4 | Upload the .p8 with Key ID and Team ID under **Apple app configuration > APNs authentication key**, for every iOS app (dev, staging, prod bundle ids) | Firebase console > Project settings > Cloud Messaging | One key works for development and production |
| 5 | Each iOS App ID (dev/stg/prod) has the **Push Notifications** capability; regenerate the provisioning profiles after turning it on. The entitlements already set `aps-environment` (development for Debug, production for Release) | developer.apple.com > Identifiers | Without it `getToken()` never returns on iPhone |
| 6 | Deploy rules and functions: `firebase deploy --only "firestore:rules,functions:core-api" --project my-livewell` | Terminal at the repo root | Rules allow `users/{uid}/devices`; the trigger sends |
| 7 | TTL policy on `push_outbox`, field `expire_at`: `gcloud firestore fields ttls update expire_at --collection-group=push_outbox --enable-ttl --project my-livewell` | Terminal (gcloud) or Google Cloud console > Firestore > TTL | Processed requests are removed after 7 days |
| 8 | Media Service: with `MEDIA_FIREBASE_PROJECT` set it now writes `push_outbox/coach_{jobId}` when a coach is made; its service account needs **Cloud Datastore User** (already needed for the avatar doc) | Cloud Run / IAM | "Your coach is ready" for a closed app |

Android needs nothing extra: `google-services.json` already carries the sender, and Android 13+ asks for the notification permission in the app (the plan's reminder dialog).

## Check it on a phone (dev)

1. Install the dev build, sign in, finish the plan and tap **Allow** on the reminder dialog (that grants the notifications consent and the OS permission).
2. In the Firestore console, `users/{uid}/devices/{installId}` appears with `token`, `platform`, `time_zone` only.
3. Close the app. In the Firestore console add a document to `push_outbox` with `uid` = your uid, `category` = `coach_ready`, `ref_id` = `test1`. Within seconds the document gets `result: {status: "sent", sent: 1}` and the phone shows "Your coach is ready". Outside quiet hours (default 22:00–07:00 on the phone's time zone) and while today's cap allows; otherwise `result.reason` says why (`quiet_hours`, `daily_cap`, `no_consent`, `category_off`, `no_devices`).
4. Profile > Consents: turn **Notifications** off; the device document disappears. Log out: same.

## Not possible in this repo's CI

No Android SDK or Xcode in the Linux job: the manifest and Info.plist changes are text edits, checked by the Android/iOS CI builds and on a device. Tests replace only the FCM send (`FakeTransport` in `services/core-api/test/push.test.ts`); no test reaches FCM or APNs.
