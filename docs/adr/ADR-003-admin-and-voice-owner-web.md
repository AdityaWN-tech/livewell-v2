# ADR-003: Admin / CMS and the voice-owner web page: Flutter Web or Next.js (T-FND-03, web part)

| | |
|---|---|
| Status | **Accepted (owner, 2026-11-19): split.** Admin / CMS in **Flutter Web**; voice-owner page in **Next.js (static export)** (D-90). Nothing is built yet. |
| Date | 2026-11-19 |
| Task | T-FND-03 (spec 10.2 and AGENTS.md: "Admin, voice-owner page: Flutter Web or Next.js (chosen in T-FND-03)") |
| Related | D-03 (India + US), D-17 (Spark plan), D-18 / D-85 (audit log), ADR-001 (voice vendor not chosen), ADR-002 (agents), D-90 |

## Context

Two web apps, with very different users:

- **Admin / CMS** (`apps/admin/`): a handful of internal staff (content editor, clinical reviewer, safety reviewer, admin) on desktop browsers. Spec 10.2: "content items and review status, prompt registry, portal catalog, feature flags, safety review queue", with Firebase Auth and admin roles.
- **Voice-owner page** (`apps/voice-owner-web/`): a **member of the public** (a loved one, any age 18+, possibly an older adult, in India or the US, on a phone browser over mobile data) who opens a link once, verifies, consents, records their voice and later may come back to revoke. Spec 10.1 calls it "lightweight web".

What exists: the Flutter app (`apps/mobile`, design tokens in `lib/core/design/`, lesson reader, portal card), the TypeScript Core API (`services/core-api`, Cloud Functions 2nd gen, Node 22, Firebase Admin), the Firestore rules (clients read only active + approved `portal_offers` and `content_items`; `voice_consents`, `safety_events`, `audit_log` closed to clients), and draft legal texts in `content/legal/` (no `voice-consent-1.0.md` yet).

### Requirements drawn from the spec

| # | Requirement | Spec |
|---|---|---|
| A1 | Admin roles: content editor, clinical reviewer, safety reviewer, admin; **MFA for admin users**; server-side authorization for sensitive writes; every admin action in the audit log. | 10.2, 16.2, NFR-09, 11 (`audit_log` "admin actions") |
| A2 | Content items with review status; only approved items are retrievable by the agents or visible in the app; lessons are short cards. | 10.2, 11, 11.1, FR-LRN-01, T-AGT-03 |
| A3 | Portal catalog: `portal_offers` CRUD with review status; editors publish, clients see active ones only; price shown as entered. | 13.2, 13.4, T-PRT-02 |
| A4 | Prompt registry: versioned prompt files in the repo plus a Remote Config pointer; changes pass review and the eval suite. | 9.6, 10.2 |
| A5 | Feature flags and kill switches (cloned voices, photo-realistic streaming, portal cards, Dr. Gokula voice, specific agents). | 10.2, 15.4, T-FND-11 |
| A6 | Safety review queue and dashboard: safety events (category, rule ID, action, redacted excerpt), weekly review of a 1% sample plus 100% of "unsafe" flags. | FR-SAF-06, 15.4 |
| A7 | Closed-script rule: cloned voices speak only text with a valid `message_id` from the orchestrator after the safety check. Fixed texts (emergency/crisis templates, cached nudge templates, Dr. Gokula's approved educational scripts) need an approval step; the spec does not say where. **Assumed here: the Admin's content review**, flagged as an owner question. | FR-VOC-04/05, 7.3, 9.4, 9.7 |
| V1 | Invite link with a signed token (48 h, single use), owner verification by one-time code (email or phone), 18+ confirmation. | 7.4 (1–2), T-VOC-04 card (17.3) |
| V2 | Plain-language consent (what the voice is and is not used for, how long it is kept, how to revoke); checkbox **and typed name**; copy from `content/legal/voice-consent-1.0.md`. | 7.4 (3), T-VOC-04 |
| V3 | **Live** consent recording of a random-code sentence and 1–3 minutes of samples; **uploaded files are not accepted**; speaker match on the server. | 7.4 (4–5), T-VOC-05 |
| V4 | Owner dashboard: where the voice is used and a Revoke button; vendor model deleted within 24 h. | 7.4 (7–8), FR-VOC-03, T-VOC-06 |
| W1 | WCAG 2.2 AA (screen readers, dynamic type, contrast, reduced motion, 44 pt targets). | NFR-06, 16.1 (ADA) |
| W2 | Security: TLS, App Check, no secrets in the client, rate limiting, penetration test focused on the closed-script rule. | NFR-09, 16.2 |
| W3 | No PHI or free text in logs or analytics. | NFR-10, AGENTS.md |
| W4 | Environments dev / staging / prod, Terraform, GitHub Actions CI. | 10.3 |

## Options

Facts checked on 2026-11-19 (Sources at the end).

| | **A. Flutter Web** | **B. Next.js** |
|---|---|---|
| Version, licence | Flutter 3.50.0 stable (11 Nov 2026), BSD-3-Clause. Repo CI uses 3.47.7. | Next.js 16.4.6 (16.x is Active LTS; 15.x security fixes to 31 Jan 2027), MIT. |
| How it renders | Draws the UI on a canvas (CanvasKit / Skwasm, WebGL/WebGPU); JS or WebAssembly (`--wasm`). | Real HTML (React); static export, or a Node server for Server Components and Server Actions. |
| Accessibility | A semantics tree is mirrored into an HTML DOM, but "for performance reasons, Flutter's web accessibility is not on by default": the user presses a hidden "Enable accessibility" button, or the app calls `SemanticsBinding.instance.ensureSemantics()`. | Native HTML semantics; accessibility depends on our markup and components. |
| Hosting | Static files: Firebase Hosting (works on the free Spark plan). | Static export: Firebase Hosting (Spark). Server features: Firebase App Hosting (Cloud Build + Cloud Run + Cloud CDN), which **needs Blaze**. |
| Firebase Auth + MFA | `firebase_auth` (FlutterFire); SMS MFA documented (Windows excluded). | Firebase JS SDK; SMS MFA documented for web. Both need the project upgraded to **Firebase Authentication with Identity Platform**; Firebase itself advises avoiding SMS-based MFA where possible. |

### Comparison

●●● strong fit, ●● workable, ● weak. "Neutral" means it is decided by the Core API, not the web framework.

| Criterion | A. Flutter Web: Admin | A. Flutter Web: voice-owner | B. Next.js: Admin | B. Next.js: voice-owner |
|---|---|---|---|---|
| **Fit with safety-first routing and the closed-script rule** (A7, W2) | Neutral: all writes go through Core API callables that check role claims and write the audit log; the web app never issues a `message_id`. | Neutral: the page only calls Core API endpoints; no vendor keys in the browser (16.2). | Neutral, same. | Neutral, same. Static export avoids a Node server, so no Server Actions attack surface. |
| **Structured I/O / schemas** | ●●● Reuses the app's Dart models for `content_items`, `portal_offers`, lesson cards. | ●● Small Dart client for a few endpoints. | ●● zod schemas can be shared with `services/core-api`. | ●●● Same zod schemas as the Core API endpoints it calls. |
| **WYSIWYG preview for approval** (A2, A3, A7) | ●●● Can render the **same widgets** as the app (lesson reader cards, portal card, coach message) so reviewers approve exactly what users will see. | n/a | ● Previews must be rebuilt in React and will drift from the app. | n/a |
| **Accessibility** (W1) | ●● Internal users; call `ensureSemantics()` at start and audit. | ● A public, one-time, possibly older or screen-reader user must not depend on a hidden "enable accessibility" button; canvas text and browser zoom/reader modes are weaker. Needs a careful audit to reach AA. | ●●● Native HTML. | ●●● Native HTML, browser zoom, reader tools, translation tools. |
| **Load on a phone over mobile data** (V1–V4) | n/a (desktop, internal) | ● Multi-megabyte engine download before the first screen; slow on weak 4G in India. | n/a | ●●● Static HTML + small JS; first screen loads fast. |
| **Live microphone recording, no uploads** (V3) | n/a | ●● Through a plugin wrapping the browser's `MediaRecorder`; one more layer to debug across Safari/Chrome. | n/a | ●●● Browser `getUserMedia` + `MediaRecorder` directly; no `<input type=file>` anywhere. |
| **Auth with Firebase, MFA, roles** (A1) | ●●● FlutterFire, same as the app; custom claims for roles; MFA via Identity Platform. | ●● Owner does not need a Firebase account: signed token + OTP handled by the Core API (T-VOC-04). | ●●● Firebase JS SDK; same claims and MFA. | ●●● Same as A. |
| **Team skills** (Flutter + TS + Python) | ●●● The team's strongest stack; design tokens and components reused. | ●● Same skills, wrong tool for this page. | ●● TypeScript known from the Core API; React/Next.js is new to this codebase. | ●● Same; the page is small (about six screens). |
| **Hosting / cost** | ●●● Static on Firebase Hosting, free tier, works on Spark today (D-17). | ●●● Same. | ●●● if static export; ●● if server features (Blaze, Cloud Run per request). | ●●● Static export on Firebase Hosting. |
| **Security surface** (W2) | ●●● Static SPA; all authority in Core API + Firestore rules. | ●●● Same. | ●● if server mode: Next.js 15/16 had a CVSS 10.0 unauthenticated RCE in React Server Components (CVE-2025-66478 / CVE-2025-55182, Dec 2025); static export removes that class. | ●●● Static export. |
| **Vendor lock-in** | Low (BSD, Google-led). | Low. | Low (MIT); higher only if Vercel-specific features are used (we would not). | Low. |
| **Maturity** | ●●● Flutter Web stable; admin-style widgets (tables, forms) are fewer than in React. | ●● Mature, but canvas rendering is a poor match for a document-like public page. | ●●● Very mature; LTS policy published. | ●●● Same. |

## Recommendation

**Split by audience:**

1. **Admin / CMS: Flutter Web**, built as a static app on Firebase Hosting (separate site per environment), reading Firestore through the app's existing data layer and making every write through Core API callables that check role claims (content editor, clinical reviewer, safety reviewer, admin), require MFA, and write the audit log.
2. **Voice-owner page: Next.js with static export (`output: 'export'`)**, no Node server, on Firebase Hosting, calling Core API endpoints for the token, OTP, consent record, recording uploads and revoke.

Top reasons, Admin on Flutter Web:
1. **Reviewers approve exactly what users see.** The approval screens can render the app's own lesson cards, portal card and coach message widgets, which matters for clinical sign-off and the "price as entered" rule (13.4).
2. **The team's strongest stack and existing code** (design tokens, Dart models, Firebase setup); no second UI system to learn for the biggest web app.
3. **Free and simple to host now:** static files on Firebase Hosting work on Spark (D-17); internal desktop users don't mind the engine download, and `ensureSemantics()` covers screen readers.

Top reasons, voice-owner page on Next.js (static):
1. **Accessibility for a stranger on a phone (WCAG 2.2 AA):** real HTML works with screen readers, zoom and browser tools without a hidden "enable accessibility" button; this page carries legal consent, so it must be readable by everyone.
2. **Fast first load on mobile data in India and the US**, and direct use of the browser's microphone APIs for live-only recording (no file upload control exists in the page).
3. **Small, safe surface:** static export means no server code in the web app (avoids the RSC/Server Actions RCE class), and zod schemas are shared with the TypeScript Core API that does all the real work.

### What would change the recommendation

- **The owner wants one web stack only.** Then pick **Next.js (static) for both**, because the public page's accessibility and load requirements are harder to meet in Flutter Web than the Admin's preview needs are in React; accept rebuilt previews (or screenshot-based previews from the Flutter golden tests).
- A React/Next.js developer joins the team, or Admin needs rich text editing and complex data tables that Flutter Web packages don't handle well: move Admin to Next.js.
- Flutter Web turns semantics on by default and its first-load size drops a lot: Flutter Web for both becomes reasonable.
- The voice-owner flow moves into the Live Well app instead of the web (spec 7.4 allows "on their own device or in person"): then only Admin remains and Flutter Web is the clear choice.

## Risks

| Risk | Mitigation |
|---|---|
| Two web stacks to maintain. | The voice-owner page is small (about six screens) and static; all logic is in the Core API. |
| Flutter Web accessibility gaps in Admin. | `ensureSemantics()` at start; keyboard navigation and a screen-reader check in the Admin acceptance tests. |
| Admin compromise publishes unsafe content or flips kill switches. | MFA (Identity Platform; prefer TOTP over SMS), role claims set only by a server script, two-person rule (editor ≠ clinical reviewer) for approval, audit log for every action, App Check. |
| Consent page legal copy drifts. | Page reads the versioned `content/legal/voice-consent-x.y.md`; the version is stored in the consent record (`consent_text_version`, spec 11). |
| Recording quality differs by browser. | Contract test against the chosen voice vendor's sample requirements (ADR-001, T-VOC-01); browser matrix (iOS Safari, Android Chrome) in T-VOC-05. |
| Identity Platform upgrade has cost and needs Blaze. | Only admin accounts use MFA; decided with Blaze (D-17). |

## Owner decisions needed

1. Admin: **Flutter Web (recommended)** or Next.js.
2. Voice-owner page: **Next.js static export (recommended)** or Flutter Web; or confirm "one web stack only" (then Next.js for both).
3. Where fixed texts get approved for the closed-script rule (emergency/crisis templates, cached nudge templates, Dr. Gokula scripts): the Admin's content review (assumed) or the prompt registry in the repo (spec 9.6)?
4. MFA method for admin users (TOTP preferred over SMS) and turning on Identity Platform when Blaze is enabled.
5. Who holds each admin role (spec 20 Q6: who staffs safety and content review).

## Sources (checked 2026-11-19)

- Flutter releases (3.50.0 stable): https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json ; repo (BSD-3-Clause): https://github.com/flutter/flutter
- Flutter web renderers: https://docs.flutter.dev/platform-integration/web/renderers
- Flutter web accessibility ("not on by default", `ensureSemantics`): https://docs.flutter.dev/ui/accessibility/web-accessibility
- Next.js latest (16.4.6): https://registry.npmjs.org/next/latest ; repo (MIT): https://github.com/vercel/next.js ; support policy: https://nextjs.org/support-policy
- Next.js advisory CVE-2025-66478 (React CVE-2025-55182): https://nextjs.org/blog/CVE-2025-66478
- Firebase App Hosting (Next.js, Blaze, Cloud Run + CDN): https://firebase.google.com/docs/app-hosting
- Firebase MFA on web and Flutter (Identity Platform; "Avoid the use of SMS-based MFA"): https://firebase.google.com/docs/auth/web/multi-factor , https://firebase.google.com/docs/auth/flutter/multi-factor
