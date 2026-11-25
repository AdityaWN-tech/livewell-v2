# LiveWell V2 — Technical Audit (existing architecture vs new hierarchy)

As of 2026-11-21, `main` at `bbb3f1f` plus open PRs. Reuse this audit; re-run only the parts whose code changed.

## 1. Existing architecture (what is there)

| Layer | Today | Evidence |
|---|---|---|
| Mobile | Flutter, Riverpod, go_router, 5-tab shell; dev-only UI hidden in prod; region-aware safety cards | `apps/mobile`, D-03, FND-04 |
| Auth | Firebase Auth: email, Google, Apple, US phone OTP; optional biometric lock. **Open self sign-up, 18+.** No custom claims for app users | ONB-01, D-66 |
| Data | Firestore, everything under `users/{uid}/…` plus global `content_items`, `portal_offers`, `voice_consents`, `safety_events`, `audit_log` | `firebase/firestore.rules` |
| Rules | Owner-only access per user; 100% emulator coverage gate | FND-06 |
| Core API | TypeScript Cloud Functions; staff guard with custom claim `staff_roles` + MFA (PR #105, unmerged) | `services/core-api` |
| Agents | Python FastAPI + LangGraph; safety pre/post rules + classifier; eval gate in CI | PRs #104, #106–#109 (merged) |
| Admin web | Flutter Web, portal catalog only (PR #105) | `apps/admin` |
| Audit | Append-only, hash-chained audit log, write-only account (PR #97) | FND-09 |
| Config | Remote Config feature flags with safe defaults (PR #85) | FND-11 |
| Monitoring | Crashlytics with consent gating and PHI scrubbing (PR #94) | FND-10 |

## 2. Gaps for the new hierarchy

| # | Gap | Severity | Reuse |
|---|---|---|---|
| G1 | No organization entity, membership or `org_id` anywhere | Blocking | None; new model + migration (T-IAM-02) |
| G2 | No app-user roles; only platform staff roles, and the staff role named `admin` clashes with the org "Admin" | High | Extend PR #105's claims (T-IAM-01) |
| G3 | Rules isolate per user, not per org; no Admin read paths (and Admin must never read health data) | Blocking | Extend FND-06 rules + tests (T-IAM-03) |
| G4 | Open sign-up; no invitations or allowlist; region chosen by user | Blocking, conflicts with FR-ONB-01 | Signed-link pattern from VOC-04 design (T-INV-01..03) |
| G5 | Feature flags are global, no per-org or per-user permissions | High | Extend FND-11 (T-PRM-01) |
| G6 | Navigation not permission-aware | High | Extend FND-04 shell (T-PRM-02) |
| G7 | Agents and Core API check user identity only | High | Add org/permission guard (T-IAM-04, T-PRM-03) |
| G8 | No Superadmin provisioning path, org console, monitoring view or audit viewer | High | Reuse staff script, FND-09, FND-10 (T-IAM-05, T-SAD-*) |
| G9 | Allowlist enforcement at sign-up needs Auth blocking functions (Identity Platform, Blaze plan) | Blocking infra | Owner action (Blaze already needed for prod) |

## 3. Rules that must hold in the new model (from AGENTS.md, non-negotiable)

1. Safety routing, emergency/crisis numbers, consent, data export, account deletion, legal texts and the closed-script voice rule can **never** be hidden, disabled or configured by an Admin or a permission. They go on a protected list enforced server-side.
2. An Admin (buyer) never sees health data, check-ins, reflections, chats, memories or voice samples. Admin sees membership and usage counts only.
3. Region is never guessed: an org's region or the user's explicit choice decides emergency numbers.
4. Roles and permissions are decided on the server (custom claims + rules + API guards); the app only mirrors them for display.
5. No PHI in logs, analytics, notifications or monitoring dashboards.

## 4. Architecture options (decision D-97 / T-IAM-00)

| Option | What it means | Pros | Cons |
|---|---|---|---|
| **A. Multi-tenant orgs in one project** (recommended if several buyers) | `organizations/{orgId}`; users carry `org_id` claim; rules check it | One codebase and deploy; Superadmin sees all orgs | Rules complexity; isolation must be tested exhaustively |
| B. One Firebase project per buyer | Each buyer gets its own dev/staging/prod | Strongest isolation | Ops cost multiplies; Superadmin spans projects |
| C. Single org (Dr. Gokula) + roles only | Admin = owner; invite-only optional | Smallest change | Doesn't support a second buyer |

Also to decide: invite-only vs invite + public sign-up; whether lessons/portal offers are global or per org; TagMango account per org; who is the data controller (legal).
