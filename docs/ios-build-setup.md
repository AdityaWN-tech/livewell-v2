# iOS builds: setup, step by step

This machine is Windows, so iPhone builds are made in the cloud (D-10):

- **Codemagic** builds and signs the three apps (`codemagic.yaml`) and sends **staging** to **TestFlight**, so you can install it on your iPhone.
- **GitHub Actions** checks that the iOS app still compiles (no signing) on every pull request that changes iOS code (`.github/workflows/ios.yml`).

**Certificates, keys and profiles are never put in the repo.** They are uploaded to Codemagic and Firebase only, and both builds fail if one is ever committed.

## The three apps

| Flavour | Bundle ID | App Group | Name on the phone | Built by |
|---|---|---|---|---|
| dev | `net.conciergeconnectedcare.livewell.dev` | `group.net.conciergeconnectedcare.livewell.dev` | Live Well Dev | Codemagic `ios-dev`, when started by hand |
| staging | `net.conciergeconnectedcare.livewell.stg` | `group.net.conciergeconnectedcare.livewell.stg` | Live Well Staging | Codemagic `ios-staging`, on every push to `main` → TestFlight |
| prod | `net.conciergeconnectedcare.livewell` | `group.net.conciergeconnectedcare.livewell` | Live Well | Codemagic `ios-prod`, when started by hand (the file is kept, not uploaded) |

The bundle IDs come from D-06 and are **permanent once an app is published**, so check them with the client before step 2. The App Group lets the app share data with the home-screen widget (AVT-08g). Each app uses Push Notifications, Sign in with Apple and its App Group (`ios/Runner/Runner-*.entitlements`).

---

## 1. The Apple Developer account

1. Decide **whose account** it is. The bundle IDs use the client's domain, so the app should be published by **the client's company**. Use an **Organization** account, not a personal one: the store then shows the company's name.
2. The company needs a **D-U-N-S number** (free from Dun & Bradstreet; it can take a few days). Look it up first at developer.apple.com/enroll/duns-lookup.
3. Enrol at **developer.apple.com/programs/enroll** with an Apple ID that has two-factor authentication turned on. The fee is **US$99 a year**. Approval for organizations takes from a day to about a week.
4. Once approved, the account holder invites you: **App Store Connect > Users and Access > +**, with the **Admin** role (or App Manager plus access to Certificates, Identifiers & Profiles).
5. Write down the **Team ID**: developer.apple.com > Account > Membership details.

## 2. Bundle IDs and App Groups (one of each per flavour)

On **developer.apple.com > Certificates, Identifiers & Profiles**:

**App Groups first:**
1. Identifiers > **+** > **App Groups** > Continue.
2. Description `Live Well Dev group`, identifier `group.net.conciergeconnectedcare.livewell.dev` > Register.
3. Do the same for `group.net.conciergeconnectedcare.livewell.stg` and `group.net.conciergeconnectedcare.livewell`.

**Then the App IDs:**
1. Identifiers > **+** > **App IDs** > **App** > Continue.
2. Description `Live Well Dev`, **Explicit** bundle ID `net.conciergeconnectedcare.livewell.dev`.
3. Under Capabilities, tick:
   - **App Groups** → Configure → pick the dev group;
   - **Push Notifications**;
   - **Sign In with Apple** → "Enable as a primary App ID".
4. Continue > Register. Do the same for staging (`.stg`, staging group) and prod (no suffix, prod group).

**The home-screen widget (AVT-08g-b)** is its own small app inside Live Well, so it needs its own App ID per flavour too:
1. Identifiers > **+** > App IDs > App.
2. Description `Live Well Dev widget`, explicit bundle ID `net.conciergeconnectedcare.livewell.dev.widget`.
3. Tick **App Groups** only, and pick the **same** dev group as the app.
4. Do the same for staging (`...livewell.stg.widget`, staging group) and prod (`...livewell.widget`, prod group).

## 3. Sign in with Apple

The app's code is ready (D-27). It needs:

1. **The capability on each App ID:** done in step 2.
2. **For Android and the web sign-in flow** (D-27), a **Services ID**:
   - Identifiers > **+** > **Services IDs**, for example `net.conciergeconnectedcare.livewell.signin`.
   - Tick Sign In with Apple > Configure: the primary App ID is the prod one.
   - Domains: `<firebase-project-id>.firebaseapp.com`.
   - Return URL: `https://<firebase-project-id>.firebaseapp.com/__/auth/handler`. Do this per Firebase project.
3. **A key:** Keys > **+** > tick **Sign in with Apple** > Configure (prod App ID) > Register.
   - Download the `.p8` file (**you can only download it once**; keep it in a password manager, never in the repo).
   - Note the **Key ID**.
4. **In Firebase:** Console > Authentication > Sign-in method > **Apple** > Enable. Enter:
   - the Services ID;
   - the Team ID;
   - the Key ID;
   - the contents of the `.p8` file.

   Do this for each Firebase project (dev now; staging and prod when they exist).

## 4. Push notification key (APNs)

One key works for every app in the team.

1. Keys > **+** > tick **Apple Push Notifications service (APNs)** > Register.
2. Download the `.p8` file (**only once**; keep it safe, never in the repo). Note the **Key ID**.
3. **In Firebase** (each project): Project settings > **Cloud Messaging** > Apple app configuration > APNs Authentication Key > **Upload**, with the Key ID and Team ID.

Push in the app itself (FCM registration) comes later. The key just needs to be in place.

## 5. Certificates and provisioning profiles (kept in Codemagic)

You need two certificates and six profiles (the app and its widget, for each flavour). Codemagic can make the certificates for you, so no Mac is needed.

1. Do step 6.2 (the App Store Connect API key) first.
2. In Codemagic, go to **Team settings > codemagic.yaml settings > Code signing identities > iOS certificates**. Choose **Generate certificate** with the API key, once for each type:

   | Type | Reference name (must match `codemagic.yaml`) |
   |---|---|
   | Apple Development | `livewell_apple_development` |
   | Apple Distribution | `livewell_apple_distribution` |

   Codemagic keeps the private key; you never download it. If you made certificates another way, upload the `.p12` with its password there instead.
3. **Register your iPhone** for dev builds (the dev profile only installs on listed devices): developer.apple.com > Devices > **+**, with the iPhone's UDID. To find it, connect the phone to a computer with Finder or iTunes and click the serial number.
4. **Make the profiles** at developer.apple.com > Profiles > **+**:

   | Profile type | App ID | Certificate | Devices | Reference name in Codemagic |
   |---|---|---|---|---|
   | iOS App Development | `...livewell.dev` | the development one | your iPhone(s) | `livewell_dev_development` |
   | App Store Connect | `...livewell.stg` | the distribution one | — | `livewell_staging_appstore` |
   | App Store Connect | `...livewell` | the distribution one | — | `livewell_prod_appstore` |
   | iOS App Development | `...livewell.dev.widget` | the development one | your iPhone(s) | `livewell_dev_widget_development` |
   | App Store Connect | `...livewell.stg.widget` | the distribution one | — | `livewell_staging_widget_appstore` |
   | App Store Connect | `...livewell.widget` | the distribution one | — | `livewell_prod_widget_appstore` |

5. In Codemagic > Code signing identities > **iOS provisioning profiles**, choose **Fetch profiles** (with the API key) or upload each `.mobileprovision`. Give each one the reference name above.

After adding a device, make the dev profile again and fetch it again.

## 6. Connect Codemagic to GitHub and App Store Connect

**6.1 GitHub**
1. Sign up at **codemagic.io** with **GitHub**.
2. Add application > GitHub > allow the Codemagic GitHub App access to **AdityaWN-tech/livewell-v2** only.
3. Project type: Flutter. Choose **codemagic.yaml** as the configuration (it is at the repo root). The three workflows `ios-dev`, `ios-staging` and `ios-prod` appear.

**6.2 App Store Connect API key** (used to upload to TestFlight and to manage signing)
1. App Store Connect > **Users and Access > Integrations > App Store Connect API** > Team Keys > **+**. Name `Codemagic`, access **App Manager**.
2. Download the `.p8` file (**only once**). Note the **Issuer ID** and the **Key ID**.
3. Codemagic > **Team settings > Team integrations > Developer Portal > Manage keys > Add key**. Name it exactly **`LiveWell App Store Connect`** (the name `codemagic.yaml` uses), then add the Issuer ID, Key ID and `.p8`.

**6.3 The apps in App Store Connect** (TestFlight needs an app record)
1. App Store Connect > **Apps > + > New App**: iOS, a name (it must be unique on the whole store, for example **"Live Well Staging"**), language, bundle ID `net.conciergeconnectedcare.livewell.stg`, SKU `livewell-staging`.
2. Make the prod record the same way (bundle ID without suffix, name "Live Well", or the client's chosen name) when you are ready. It isn't needed for TestFlight staging.

**6.4 Before the first staging build is useful**
- The staging Firebase project must exist (D-05). Until `firebase_options_staging.dart` is added with `flutterfire configure`, the staging app opens with "We couldn't start Live Well". The build and TestFlight steps work anyway, so you can test the pipeline first.
- Codemagic's free plan includes a limited number of macOS build minutes a month; check the current amount on codemagic.io/pricing. Each build takes about 15–25 minutes.

## 7. Run a build

- **Staging:** merge anything that changes `apps/mobile/` into `main`, or press **Start new build > ios-staging** in Codemagic. The build signs the app and uploads it to TestFlight.
- **Dev / prod:** Codemagic > **Start new build** > choose `ios-dev` or `ios-prod`. The `.ipa` appears under the build's **Artifacts**.

If a build fails at "Use the provisioning profiles", a certificate or profile reference name doesn't match, or the profile is missing a capability from step 2.

## 8. Install on an iPhone with TestFlight

1. App Store Connect > your staging app > **TestFlight**.
   - The build appears after Apple processes it (10–30 minutes after upload).
   - The first time, answer the **export compliance** question: the app uses only standard HTTPS encryption, so the usual answer is "None of the algorithms mentioned above". This is a legal declaration, so confirm it with the client.
2. **Internal Testing > +** to create a group (for example "Team"). Add yourself and others who are App Store Connect users (up to 100). Add the build to the group.
3. On the iPhone, install **TestFlight** from the App Store and sign in with the same Apple ID.
4. Open the invitation email (or TestFlight itself) > **Install**. The app appears as **Live Well Staging**, next to any other flavour, because each has its own bundle ID.
5. New staging builds show up in TestFlight automatically. Builds expire after 90 days.

**Dev builds on an iPhone** (not through TestFlight): download the dev `.ipa` from Codemagic's artifacts and install it on a registered device. The easiest ways are Codemagic's install link on the phone's browser, or Apple Configurator on a Mac.

## 9. The GitHub iOS check

`.github/workflows/ios.yml` runs on a macOS runner for pull requests that change `apps/mobile/ios/**` (the app, and later the WidgetKit extension and App Intents), `pubspec.yaml`/`pubspec.lock` (plugins), `codemagic.yaml` or the workflow itself. It:

1. fails if a signing file is in the repo;
2. lists the targets and schemes;
3. sets up the dev and prod flavours;
4. builds **staging in release mode without signing** (every embedded target compiles, so a broken widget or App Intent fails here);
5. checks the staging bundle ID, name and App Group.

**Cost:** macOS minutes count **10x** against the free 2,000 GitHub Actions minutes on a private repo, so one run (about 15 minutes) uses about 150. That's why it only runs on those paths and cancels older runs.

## Where things are

| What | Where |
|---|---|
| Flavour settings (bundle ID, name, App Group, entitlements) | `ios/Runner.xcodeproj/project.pbxproj`: configurations `Debug-<flavour>`, `Release-<flavour>`, `Profile-<flavour>` |
| One scheme per flavour (Flutter uses it for `--flavor`) | `ios/Runner.xcodeproj/xcshareddata/xcschemes/{dev,staging,prod}.xcscheme` |
| Capabilities | `ios/Runner/Runner-Debug.entitlements` (push: development), `Runner-Release.entitlements` (push: production) |
| The home-screen widget | `ios/LiveWellWidget/` (SwiftUI, WidgetKit; target `LiveWellWidgetExtension`, iOS 16+; Done from the widget on iOS 17+) |
| Cloud builds | `codemagic.yaml` |
| PR check | `.github/workflows/ios.yml` |

Locally on a Mac (if you ever have one): `flutter run --flavor dev -t lib/main_dev.dart`.
