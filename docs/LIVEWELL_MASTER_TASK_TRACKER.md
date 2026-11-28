# LiveWell V2 — Master Task Tracker

The single task list for the whole project: the 71 spec tasks (section 17), the new hierarchy requirements (Superadmin / Admin / User) and the free-plan owner tasks (D-112 to D-118).
Status as of 2026-11-28, checked against `main`, the open PRs and CI. Update this file whenever a task changes state.

**Statuses:** NOT STARTED · READY · IN PROGRESS · BLOCKED · NEEDS REVIEW · TESTING · VERIFIED · COMPLETED. COMPLETED = merged to `main` with CI green. NEEDS REVIEW = built, in an open PR, waiting for the owner. Acceptance criteria for spec tasks are the spec's "Done when" (section 17); tests follow spec 15.1 plus AGENTS.md rule 3.

**Priority:** P0 release/safety critical · P1 needed for beta · P2 needed for launch · P3 later. **Complexity:** S < 2 days · M ≤ 1 week · L 1–2 weeks · XL > 2 weeks.

## Summary

| Status | Existing tasks (71 spec + T-ONB-01b) | New tasks | Free-plan tasks | Total |
|---|---|---|---|---|
| COMPLETED | 40 | 1 | 7 | 48 |
| NEEDS REVIEW | 1 | 0 | 1 | 2 |
| IN PROGRESS | 4 | 0 | 0 | 4 |
| BLOCKED | 21 | 1 | 0 | 22 |
| READY | 0 | 0 | 0 | 0 |
| NOT STARTED | 6 | 18 | 1 | 25 |
| **Total** | **72** | **20** | **9** | **101** |

Several BLOCKED content tasks (ASM-01, ASM-03, LRN-01, LRN-02) now have their tools built (section C); what remains is Admins writing the content and a clinical reviewer approving it.

## A. New tasks (hierarchy requirements and reconciliation)

| ID | Task | Source | Module | Status | Comparison | Required changes | Depends on | Pri | Size | Acceptance | Tests | Risks | Phase |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T-PLN-00 | Task reconciliation and unified roadmap | Reconciliation | Docs | COMPLETED | COMPLETELY NEW | These six docs; D-97 recorded | - | P0 | S | Owner approves roadmap | n/a (docs) | Stale if not kept up to date | 0 |
| T-IAM-00 | Decide tenancy model and change the spec (ADR-004, D-97) | New sir requirement | Architecture | BLOCKED | NEEDS DECISION + CONFLICTING | ADR-004: single-tenant per buyer vs multi-tenant orgs; invite-only vs open sign-up; what Admin can see; content/offers global or per org | - | P0 | M | ADR-004 approved by owner and client; AGENTS.md and spec addendum updated | Review only | Wrong choice forces data migration later | 0 |
| T-IAM-01 | Role model: superadmin / org_admin / member + platform staff roles | New sir requirement | Auth, Core API | NOT STARTED | EXISTING BUT NEEDS MODIFICATION (PRT-02 staff_roles) | Custom claims {role, org_id, staff_roles, perms_v}; rename PRT-02 'admin' to platform role; claims only set server-side | T-IAM-00, PRT-02 merged | P0 | M | Claims set only via Admin SDK; client cannot change role; token refresh after change | Core API unit + emulator tests; escalation attempts | Claim drift between token and DB | 3 |
| T-IAM-02 | Organization data model + migration (default org for existing users) | New sir requirement | Data model | NOT STARTED | COMPLETELY NEW | organizations/{orgId}, org_members, users.org_id; data-model.md; dry-run migration to a default org | T-IAM-00, FND-07 | P0 | L | Every user has exactly one org; migration dry-run + rollback documented | Migration tests on emulator | Breaks existing user paths if done ad hoc | 3 |
| T-IAM-03 | Firestore rules: org isolation and role checks | New sir requirement | firebase/ | NOT STARTED | EXISTING BUT NEEDS MODIFICATION (FND-06) | Add org/role predicates; Admin never reads health sub-collections; keep 100% coverage | T-IAM-01, T-IAM-02 | P0 | L | Cross-org read/write denied for every collection; coverage gate 100% | Emulator rules tests incl. cross-org and escalation | Rule mistakes leak health data | 3 |
| T-IAM-04 | Core API authorization middleware (role + org + permission) | New sir requirement | services/core-api | NOT STARTED | EXISTING BUT INCOMPLETE (staff.ts) | One zod-validated guard for every callable; deny by default; audit every admin action | T-IAM-01 | P0 | M | Every endpoint declares required role/permission; unknown = denied | Unit + emulator tests per endpoint | Missed endpoint | 3 |
| T-IAM-05 | Secure Superadmin provisioning | New sir requirement | Ops, Core API | NOT STARTED | EXISTING BUT INCOMPLETE (set-staff-claims script) | Superadmin only via owner-run Admin SDK script with MFA; no API can create a superadmin; break-glass procedure; audit | T-IAM-01, FND-09 | P0 | S | No client/API path grants superadmin; MFA required | Escalation tests | Lost superadmin access; insider risk | 3 |
| T-SAD-01 | Superadmin console: organizations and Admin accounts | New sir requirement | apps/admin | NOT STARTED | EXISTING BUT INCOMPLETE (Admin web from PRT-02; staff Superadmin portal from T-IAM-10/11 to extend) | Create/suspend orgs; invite/remove org Admins; Flutter Web admin app | T-IAM-04, T-IAM-05 | P1 | L | Superadmin can create org and first Admin; actions audited | Widget + API + emulator tests | Over-powerful console | 4 |
| T-SAD-02 | Global configuration | New sir requirement | Remote Config, Core API | NOT STARTED | EXISTING BUT INCOMPLETE (FND-11) | Global defaults + per-org overrides; safety settings not overridable | FND-11, T-IAM-04 | P1 | M | Org override applies only to that org; safety keys rejected | Unit tests; rule tests | Config disables safety | 4 |
| T-SAD-03 | System monitoring for Superadmin | New sir requirement | Observability | NOT STARTED | EXISTING BUT INCOMPLETE (FND-10) | Dashboards/alerts per org (counts only, no PHI) | FND-10 | P2 | M | Dashboard shows health, errors, usage counts; no PHI | Log-scrubbing tests | PHI in logs | 4 |
| T-SAD-04 | Administrative audit log viewer | New sir requirement | apps/admin, audit | NOT STARTED | EXISTING BUT INCOMPLETE (FND-09) | Read-only viewer; Admin sees own org, Superadmin all; new action names allow-listed | FND-09, T-IAM-04 | P1 | M | Every admin action visible; log append-only | API + emulator tests | Audit log tampering | 4 |
| T-ORG-01 | Admin: organization settings | New sir requirement | apps/admin, Core API | NOT STARTED | COMPLETELY NEW | Org profile, region (IN/US, D-03), branding limits, contact | T-IAM-04 | P1 | M | Admin edits only own org; region drives emergency numbers | API + widget tests | Wrong region = wrong emergency number | 5 |
| T-ORG-02 | Admin: user management (no health data) | New sir requirement | apps/admin, Core API | NOT STARTED | COMPLETELY NEW | List/suspend/remove members, assign permission sets; Admin never sees health data, chats or memories | T-IAM-03, T-IAM-04 | P0 | L | Admin manages members of own org only; zero PHI fields returned | API + rules tests; PHI field tests | Privacy/legal exposure | 5 |
| T-INV-01 | Secure invitations | New sir requirement | Core API, email/SMS | NOT STARTED | COMPLETELY NEW (reuses VOC-04 signed-link pattern) | Single-use, expiring, signed tokens bound to email/phone and org; revoke; rate limits | T-IAM-02, T-IAM-04 | P0 | M | Token reuse, expiry, wrong identity all refused | Unit + emulator e2e | Token leakage | 6 |
| T-INV-02 | Allowlist enforced at sign-up | New sir requirement | Auth blocking function | NOT STARTED | COMPLETELY NEW | Allowlist (email, domain, phone) per org; enforced server-side in beforeUserCreated/beforeSignIn | T-INV-01, Blaze + Identity Platform | P0 | M | Non-allowlisted identity cannot create an account or join an org | Emulator tests | Needs Blaze/Identity Platform | 6 |
| T-INV-03 | Mobile join flow: invite link, sign-in, org assignment | New sir requirement | apps/mobile onboarding | NOT STARTED | EXISTING BUT NEEDS MODIFICATION (ONB-01) | Deep link -> sign-in -> server assigns org; region from org, never guessed | T-INV-01, T-INV-02, ONB-01 | P0 | M | Invited user lands in correct org with permissions; uninvited sees a clear message | Widget + integration (emulator) tests | Store review for invite-only apps | 6 |
| T-PRM-01 | Permission catalog and feature visibility | New sir requirement | Core API, Remote Config | NOT STARTED | EXISTING BUT INCOMPLETE (FND-11 flags) | Feature registry -> permission keys; org-level + per-user grants; protected list (safety, consent, export, delete, legal) can never be hidden | T-IAM-04, FND-11 | P0 | M | Each feature maps to a key; protected keys rejected | Unit tests incl. protected list | Hiding safety features | 7 |
| T-PRM-02 | Mobile permission gating | New sir requirement | apps/mobile router/shell | NOT STARTED | EXISTING BUT NEEDS MODIFICATION (FND-04) | go_router redirects, tab visibility, deep-link guards from server permissions; offline cache | T-PRM-01 | P0 | M | Unauthorised screens unreachable incl. deep links; safety always reachable | Widget tests per gated route | Client-only checks (must mirror server) | 7 |
| T-PRM-03 | Authorization across agents, APIs and database | New sir requirement | services/* | NOT STARTED | EXISTING BUT NEEDS MODIFICATION | Agents + Core API + rules all check org and permission; consistent error | T-PRM-01, T-IAM-03 | P0 | L | Every server path enforces permission; matrix test green | Authz matrix tests | Inconsistent enforcement | 8 |
| T-SEC-01 | Security, isolation and escalation test suite | New sir requirement | All | NOT STARTED | EXISTING BUT INCOMPLETE (CMP-04) | Automated cross-org, escalation, invite-abuse suites in CI; feeds the pen test | T-PRM-03 | P0 | L | No cross-org access; no escalation path; CI blocks regressions | CI suites + pen test | Late discovery | 9 |

## C. Free-plan owner tasks (D-112 to D-118)

Owner decisions of 2026-11-27 (D-112 to D-116, Firebase Spark plan) and the work built on them. Staff Admin / Superadmin here means internal content staff only; the buyer-organization hierarchy (section A, D-97) stays open.

| ID | Task | Status | Evidence / notes | Depends on | Pri | Size | Acceptance | Blocker |
|---|---|---|---|---|---|---|---|---|
| T-PLN-01 | Free-plan decisions D-112 to D-116 | COMPLETED | Merged (PR #125): staff portals, own courses, admins write content, layered avatar, free-plan mode | - | P0 | S | Owner decisions recorded | Client to confirm D-112, D-113 |
| T-IAM-10 | Staff access: request → Superadmin approves (D-112) | COMPLETED | Merged (PR #126): Google sign-in, Request admin access, Superadmin portal (Requests / Admins / Activity), rules-only on Spark, admins never read health data. Rules 145, admin 56 tests | - | P0 | M | Only a Superadmin decides; no self-promotion; append-only activity log | - |
| T-IAM-11 | Superadmin polish and the clinical reviewer role (D-118) | NEEDS REVIEW | PR #133: staff roles (content editor, clinical reviewer, safety reviewer); only an active clinical reviewer who is not the author approves content (rules); search, confirm dialogs, Content tab with waiting counts, readable Activity. Rules 155 (85/85), admin 71 tests. Needs human security review | T-IAM-10 | P0 | M | Non-reviewers can't approve (rules tests); 100% rule coverage | Security review; after deploy a Superadmin must give someone Clinical reviewer |
| T-LRN-10 | Admins write lessons, breathing sessions and courses, 2-person approval (D-113, D-114) | COMPLETED | Merged (PR #127): editor, automatic content check (medication/dose, cure, fear words), author + different admin approve, edit as next version, retire. Rules 151, admin 63 tests | T-IAM-10 | P1 | L | Only approved items reach the app; rules enforce 2 people | - |
| T-LRN-11 | Courses in the app's Learn tab (D-113) | COMPLETED | Merged (PRs #128, #129): approved courses with progress and "continue where you left off"; for everyone or chosen emails | T-LRN-10 | P1 | M | Approved courses show with progress | - |
| T-ASM-10 | Admins write the Live Well Map; the 10-minute check in the app (D-114, ASM-01) | COMPLETED | Merged (PR #130): driver names and check questions in Admin with 2-person approval; 1–5 check in the app, results fill the map; `ff_assessment` on in dev only. Rules 153 (85/85), admin 66 tests | T-LRN-10 | P1 | L | Approved names replace "Driver 1–8"; check saves to the user's assessments | Clinical review of questions and provisional scoring before prod |
| T-AVT-11 | 15 more ready-made 3D coaches | COMPLETED | Merged (PR #131): 23 coaches in all; `braids` not made, `hearing_aid` shipped as `pixie_cut` | T-AVT-02 | P2 | M | Frames and Studio entries for each coach | - |
| T-AVT-12 | Ready-made coaches are final (D-117) | COMPLETED | Merged (PR #132): owner approved commercial use of the Gemini portraits; staging and prod show the 3D coaches | T-AVT-11 | P2 | S | Coaches show in all builds | - |
| T-AVT-13 | Customise my coach: layered avatar (D-115) | NOT STARTED | Decided: pieces stacked on the phone, free commercial-use art set first, no face photo | T-AVT-02 | P2 | L | Each piece swappable; expressions swap eyes and mouth only | Art set choice |

## B. Existing spec tasks (IDs preserved)

Source for all rows: existing project (spec v1.0 section 17). "Hierarchy impact" is the comparison with the new requirements.


### Foundation

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-FND-01 | Audit of the prototype code | COMPLETED | - | Unaffected | - | P1 | S | Audit doc merged and reviewed by the tech lead | - | 0 |
| T-FND-02 | Monorepo and CI | COMPLETED | Mobile, media, API, rules, safety and iOS checks run on every PR | Unaffected | - | P0 | M | CI green on an empty PR; dev, staging and prod deployable | - | 0 |
| T-FND-03 | Vendor and framework choices | COMPLETED | Merged (PR #101): ADR-002 LangGraph + Claude, ADR-003 Flutter Web admin and Next.js voice-owner page (D-90). Morning-briefing prototype merged (PR #104); not yet run against real Claude (needs API credit) | Unaffected | - | P0 | M | ADRs merged with scorecards against the Section 8.3 criteria; morning-briefing prototype runs end to end | - | 1 |
| T-FND-04 | App shell with 5 tabs | COMPLETED | - | NEEDS MODIFICATION: tabs/routes must hide unauthorised features (T-PRM-02) | - | P0 | M | All prototype screens reachable; golden tests for core components | - | 0 |
| T-FND-05 | Consent service | COMPLETED | Merged (PR #88, owner approved): server-side 16.3 handling on revoke, hourly retry, audit. Open: D-76 client questions; memory/memory_sensitive revoke not handled yet (follow-up); hourly job needs Blaze | Unaffected; consent stays per user and can never be hidden by permissions | FND-06 | P0 | M | Grant and revoke for every consent type; emulator tests; audit entries | - | 1 |
| T-FND-06 | Firestore security rules and tests | COMPLETED | - | NEEDS MODIFICATION: org isolation and role checks (T-IAM-03) | - | P0 | L | 100% rule coverage tests pass | - | 0 |
| T-FND-07 | Moving data from the old app | COMPLETED | Merged (PR #96): dry-run-first migration of the users arrays; staging dry run needs the owner | Coordinate: org_id backfill is a second migration (T-IAM-02) | FND-06 | P2 | M | Dry run on a staging copy; reversible; counts reconcile Done when | Close if no prototype data (D-01) | 1 |
| T-FND-08 | Encrypted on-phone database | COMPLETED | Merged (PR #98, owner approved): SQLCipher Drift DB and exactly-once outbox for check-ins. Habits, routines, goals and reflections still to move; one device test of a restored backup suggested | Unaffected (on-device data) | - | P1 | L | Offline log, then reconnect, syncs exactly once (integration test) | - | 1 |
| T-FND-09 | Audit log | COMPLETED | Merged (PR #97, owner approved): create-only hash-chained audit log, fixed action list (incl. migration, portal admin, voice gateway actions), write-only audit-writer. Terraform not applied (Blaze); logWriter is project-wide (review note) | EXISTING BUT INCOMPLETE: reuse for admin/superadmin audit (T-SAD-04) | - | P0 | M | Write-only service account; tamper test fails as expected | - | 1 |
| T-FND-10 | Crash reporting and monitoring | COMPLETED | Merged (PR #94, owner approved): Crashlytics with allow-list scrubbing behind the analytics consent; turns off at sign-out even offline; server logs via monitored(). Agent tracing waits for the agents; counsel to confirm the consent wording covers crash reports | EXISTING BUT INCOMPLETE: base for system monitoring (T-SAD-03) | - | P1 | M | Test crash shows no PHI; trace visible for a sample agent run | - | 2 |
| T-FND-11 | Feature flags | COMPLETED | Merged (PR #85): Remote Config flags with safe per-flavour defaults; prod-locked flags need a build-time allow. coachMemory, rewards and driverWheel added at merge | EXISTING BUT INCOMPLETE: global flags; org-level visibility added in T-PRM-01 | - | P1 | M | Each flag in Section 10.2 toggles behavior in staging Done when | - | 1 |

### Onboarding

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-ONB-01 | Onboarding, 18+ check, sign-in | COMPLETED | Apple sign-in not yet tried on a device; fingerprint or face lock added | CONFLICTING: open sign-up vs invitation + allowlist (T-INV-03, D-97) | FND-04 | P0 | L | FR-ONB-01..06 acceptance criteria pass | - | 0 |
| T-ONB-01b | Phone sign-in any country (searchable country picker, per-country validation, E.164; reverses D-66, D-99) | COMPLETED | Merged (PR #112). Owner request 2026-11-21; `inferRegion` unchanged (D-03), new tests for +44/+61/+971/+977 | Unaffected | ONB-01 | P1 | S | Any country selectable on phone sign-in and Profile > Add a phone number; region never guessed | Owner: Firebase SMS region policy, SMS cost (Blaze) | 0 |
| T-ONB-02 | Personal Why | COMPLETED | - | Unaffected | ONB-01 | P1 | S | Saved and displayed on Home | - | 0 |

### Assessment & safety

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-ASM-01 | Question bank | BLOCKED | Tools built (T-ASM-10, PR #130): Admins write the questions, 2-person approval, check screen in the app behind `ff_assessment`. No approved questions yet | Unaffected | - | P1 | L | Bank v1.0 loads; schema validation in CI | Admins write the questions; clinical reviewer approves | 1 |
| T-ASM-02 | Red-flag safety rules | COMPLETED | Critical safety set passes at 100%; needs clinical review | Unaffected; safety can never be hidden by permissions | - | P0 | M | All red-flag rule tests pass | Clinical review | 0 |
| T-ASM-03 | Scoring and Live Well Map | BLOCKED | Provisional scoring fills the map from the 10-minute check (PR #130, dev only); needs the approved question bank and clinical review of the scoring | Unaffected | ASM-01 | P1 | M | FR-ASM-03 copy review; snapshot tests Done when | Waits for ASM-01 | 1 |

### Avatar

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-AVT-01 | Avatar renderer | COMPLETED | Built as the 3D coach | Unaffected | - | P1 | L | Renders at 60 fps on a mid-range device; 5 expressions; lip-sync demo | - | 0 |
| T-AVT-02 | Avatar creator | COMPLETED | 23 ready-made coaches (T-AVT-11, T-AVT-12, D-117) and the Avatar Studio; layered customisation is T-AVT-13 (D-115) | Feature-visibility candidate | AVT-01 | P1 | L | FR-AVT-02 checklist met Done when | - | 0 |
| T-AVT-03 | Avatar from a selfie | BLOCKED | Built, switched off: needs counsel review and the server deployed. D-115 prefers the layered avatar (no face photo) | Feature-visibility candidate | AVT-02, CMP-02 | P2 | L | Spoof tests fail as expected; job status polling works; raw media TTL enforced | Counsel review; server deploy | 1 |
| T-AVT-04 | Avatar fallback and reduced motion | COMPLETED | - | Unaffected | AVT-01 | P1 | S | FR-AVT-05/06 tests pass offline | - | 0 |
| T-AVT-05 | Delete my avatar | COMPLETED | Merged (PR #92, owner approved): Delete my avatar deletes server media (D-76 code), clears phone caches; My coach section. Vendor deletion waits for an avatar vendor | Unaffected (user right; never hidden) | FND-05 | P0 | M | Vendor API confirms; audit entry; UI updates Done when | - | 1 |

### Voice

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-VOC-01 | Voice engine | BLOCKED | Coach uses the phone's own speech for now | Unaffected | - | P1 | L | Contract tests pass against the vendor sandbox | Voice vendor | 1 |
| T-VOC-02 | Voice library | COMPLETED | Merged (PR #89): "How this voice is made" in voice settings; 6 of the 12 voices | Feature-visibility candidate | VOC-01 | P2 | M | FR-VOC-01 met | 6 of 12 voices | 1 |
| T-VOC-03 | Clone your own voice | BLOCKED | Needs a voice vendor | Feature-visibility candidate | VOC-01, CMP-02 | P2 | L | E2E test; consent record matches Section 11 example | Voice vendor | 1 |
| T-VOC-04 | Invite a loved one's voice | BLOCKED | Phase 2 | Separate from org invitations (different purpose); reuse signed-link pattern | VOC-01 | P3 | L | See the card in 17.3 | Phase 2 of spec | 1 |
| T-VOC-05 | Loved one's consent recording | BLOCKED | - | Unaffected | VOC-04 | P3 | M | Uploaded files rejected; speaker match enforced | Phase 2 of spec | 1 |
| T-VOC-06 | Voice owner's dashboard | BLOCKED | - | Unaffected | VOC-05 | P3 | M | Revoke deletes the vendor model within 24 h (job test); account | Phase 2 of spec | 1 |
| T-VOC-07 | Closed-script voice gateway | COMPLETED | Merged (PR #102, owner approved after a fix): closed-script gateway; library voices use the server catalogue only (bypass fixed at review, D-88). No voice vendor yet; external pen test still needed | Unaffected; closed-script rule never configurable by Admin | - | P0 | M | Pen-test script cannot get arbitrary text spoken; safety categories use a neutral voice | - | 1 |
| T-VOC-08 | Dr. Gokula's voice | BLOCKED | Switched off; needs a licence | Unaffected | VOC-07 | P2 | M | Flag off by default; label visible legal sign- Done when | Licence | 1 |

### AI agents

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-AGT-01 | Agent service | BLOCKED | FastAPI + LangGraph service with safety checks before and after the model, 351 tests, merged into main (PR #104); not deployed and doesn't save messages yet | NEEDS MODIFICATION: endpoints check org/role (T-PRM-03) | - | P0 | L | Hello-world turn traced end to end; invalid JSON is retried | Deploy needs Blaze + API credit | 1 |
| T-AGT-02 | Safety checks before and after AI | COMPLETED | Rules plus an AI classifier that can only make a check stricter, 805 safety cases at 100%, merged (PR #107); still needs clinical sign-off on the classifier prompts | Unaffected; never configurable by Admin | AGT-01 | P0 | L | 15.3 critical cases at 100% | Clinical sign-off (D-93/D-96) | 0 |
| T-AGT-03 | Content pipeline | BLOCKED | Approved-only pipeline, chunking and search with precision@5 of 0.86 on synthetic lessons, merged (PR #106); production search service and real lessons still to come | Decide: content global or per org (D-97) | AGT-01 | P1 | L | Unapproved item not retrievable (test); retrieval precision@5 of 0.8 or more on the eval set | Prod embedding/vector store choice (D-94) | 1 |
| T-AGT-04 | Coach Agent | COMPLETED | Merged (PR #111). Five modes on one pipeline, 2397 tests, 676 golden cases (gate PASS); offline 15.2 gates met, live tone/grounding unmeasured (no API credit) | Unaffected | AGT-02, AGT-03 | P0 | XL | Eval gates in 15.2 pass | - | 1 |
| T-AGT-05 | Memory Agent | COMPLETED | Merged (PRs #113, #114, #115); owner safety and privacy sign-off 2026-11-25. Memory screen stays dev-only in staging/prod until the agent is deployed (D-101) | Unaffected (memory is per user, never visible to Admin) | AGT-04 | P1 | L | FR-CNV-05 met; sensitive categories need opt-in | Deploy the agent; turn on `coachMemory`; clinical/privacy review | 1 |
| T-AGT-06 | Insights Agent | COMPLETED | Merged (PR #117). Built (D-104): deterministic weekly stats, `POST /v1/insights/weekly`, weekly review computes its own stats; 7 hand-worked fixtures match. Metrics not read yet (needs client). Not deployed | Unaffected | AGT-04 | P1 | M | Matches the deterministic statistics on fixtures | - | 1 |
| T-AGT-07 | Portal Agent | COMPLETED | Merged (PR #118); owner safety and product sign-off 2026-11-25. No card for real accounts until the portal catalog is live | Decide: offers global or per org (D-97) | AGT-04, PRT-02 | P2 | L | All 13.3 rules have unit tests; zero hallucinated offers in eval | - | 1 |
| T-AGT-08 | AI evaluation tests | COMPLETED | 388-case golden set and a CI gate merged (PR #108); it found 36 real safety gaps; 35 are fixed (all 28 critical, PR #109), one harmless over-block is left for a clinician | Extend with authz cases later (T-SEC-01) | AGT-02 | P0 | L | CI blocks merge on a critical failure Done when | - | 0 |

### Daily loop

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-DLY-01 | Home screen | IN PROGRESS | Spoken briefing is switched off until the Coach Agent exists | Unaffected | AGT-04 | P0 | M | FR-DLY-03 enforced in UI tests | Spoken briefing waits for AGT-04 | 1 |
| T-DLY-02 | Daily check-in | COMPLETED | Merged (PR #83, owner approved): check-in safety fixes; loading check-in counts as gentle for portal cards (Learn and lesson end). 72 h hold is phone-only until D-22 | Unaffected | ASM-02 | P0 | M | Timed usability test median under 30 s | - | 1 |
| T-DLY-03 | Daily plan and briefing | IN PROGRESS | App side merged (PR #93): Daily plan settings, moment playback, Not today. After the starter plan ends, last week's step repeats (D-109). Server briefing jobs not built | Unaffected | AGT-04 | P1 | L | NFR-03 met in a staging load test | Server jobs not built | 1 |
| T-DLY-04 | Reminder scheduling with caps | COMPLETED | Merged (PR #84): one cap of 4 a day across plan and routine reminders. Done button and opt-in task names on reminders (D-111) | Unaffected; frequency cap never configurable by Admin | - | P1 | M | FR-DLY-04, FR-TCH-01 tests Done when | - | 1 |
| T-DLY-05 | Evening reflection | IN PROGRESS | No AI reply yet | Unaffected | AGT-04 | P1 | M | FR-DLY-05 eval cases pass | AI reply waits for AGT-04 | 1 |
| T-DLY-06 | Streaks | COMPLETED | - | Unaffected | - | P2 | S | FR-DLY-07/09 unit tests | - | 0 |
| T-DLY-07 | Weekly review | IN PROGRESS | Weekly wins built; no AI-written review | Unaffected | AGT-06 | P2 | M | Generated for 100% of eligible test users | AI review waits for AGT-06 | 1 |

### Conversation

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-CNV-01 | Talk to the coach by voice | NOT STARTED | Needs the Coach Agent | Feature-visibility candidate | AGT-04, VOC-01 | P1 | L | NFR-02 latency met on a test device | - | 1 |
| T-CNV-02 | Text chat with the coach | NOT STARTED | - | Feature-visibility candidate | AGT-04 | P1 | M | FR-CNV-06/07 met Done when | - | 1 |

### Touchpoints

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-TCH-01 | Push notifications | COMPLETED | Merged (PR #90, owner approved): FCM registration with consent, server push with consent, toggle, quiet hours and cap. Owner setup (FCM API, APNs key) needed for real devices | Unaffected; no personal data in pushes | - | P1 | M | Each category toggles; no PHI on the lock screen | Owner FCM/APNs setup | 1 |
| T-TCH-02 | iPhone widgets | COMPLETED | Builds in the cloud; not yet seen on a real iPhone | Unaffected | - | P2 | M | Done logs offline and syncs; snapshot tests | Not seen on a real iPhone | 0 |
| T-TCH-03 | Android widgets | COMPLETED | Merged (PRs #81, #82): Hide details on lock screen (default on; Android fallback hidden; switch in Profile > Daily plan) and widget_interaction analytics. New design (D-110), task names (D-111); load and Open fixes (PRs #123, #124) | Unaffected | - | P2 | M | Parity checklist with iOS | - | 1 |
| T-TCH-04 | Apple Watch app | NOT STARTED | - | Unaffected | TCH-01 | P3 | L | FR-TCH-05 checklist | - | 1 |
| T-TCH-05 | Wear OS app | NOT STARTED | - | Unaffected | TCH-01 | P3 | L | FR-TCH-05 checklist | - | 1 |
| T-TCH-06 | Watch complications | NOT STARTED | - | Unaffected | TCH-04, TCH-05 | P3 | M | FR-TCH-04/06 Done when | - | 1 |

### Learn

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-LRN-01 | Lesson library | BLOCKED | Reader works; Admins can now write lessons with 2-person approval (T-LRN-10). No approved lessons yet | Feature-visibility candidate | AGT-03 | P1 | M | At least 24 approved lessons load; narration plays Done when | Admins write 24+ lessons; clinical reviewer approves | 1 |
| T-LRN-02 | Breathing and audio sessions | BLOCKED | 3 breathing exercises; Admins can write breathing items (T-LRN-10). Audio uploads need Cloud Storage (Blaze); until then a hosted link (D-114) | Feature-visibility candidate | - | P2 | M | Work offline | Recorded audio | 1 |

### Goals & tracking

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-GOL-01 | Goals and habits | COMPLETED | - | Unaffected | - | P1 | M | FR-GOL-01..06 | - | 0 |
| T-GOL-02 | Tracking | COMPLETED | Merged (PR #86, owner approved): manual weight, blood pressure, glucose and meals with 7/30/90-day charts on Track; recorded, never interpreted; included in Download my data | Feature-visibility candidate | GOL-01 | P1 | M | Source and timestamp shown on every point | - | 1 |

### Travel

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-TRV-01 | Travel Mode | NEEDS REVIEW | PR #100. Trips, streak protection, pillar content and labelled nearby places in PR #100; content needs clinical approval; in-app listings need a maps key | Feature-visibility candidate | - | P2 | M | FR-TRV-01..03 | Clinical approval; maps key | 1 |

### Rewards

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-GAM-01 | Badges and challenges | COMPLETED | Merged (PR #99): badges, challenges, unlockables and driver wheel; off in staging/prod (Remote Config ff_rewards, ff_driver_wheel) until clinical review | Feature-visibility candidate | - | P2 | M | FR-GAM-01..03; banned reward types absent Done when | Clinical review | 1 |

### Portal

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-PRT-01 | Confirm the TagMango API | BLOCKED | Waiting on TagMango details. D-113 replaces PRT-01, 04–07 with own courses (T-LRN-10/11) if the client confirms | Decide: one TagMango account or one per org (D-97) | - | P1 | M | ADR with sample payloads captured in a sandbox or test course | TagMango API details | 1 |
| T-PRT-02 | Portal catalog in Admin | COMPLETED | Merged (PR #105, owner approved): Admin catalog with two-person review. Real MFA needs Blaze + Identity Platform (waiver until then); App Check and rate limits to add. On the free plan staff access is D-112 (T-IAM-10); offers still go through the Core API (needs Blaze) | NEEDS MODIFICATION: staff role 'admin' collides with org Admin; becomes platform roles under Superadmin (T-IAM-01) | - | P1 | L | Editors can publish offers; clients see active ones only | MFA method | 1 |
| T-PRT-03 | Portal card in the app | COMPLETED | Merged (PR #87): portal card on Learn and at the lesson end, same 13.3 checks; flag off | Feature-visibility candidate | PRT-02 | P1 | M | UTM and lw_cid present; click event logged | Product sign-off | 1 |
| T-PRT-04 | TagMango webhooks | BLOCKED | Replaced by own courses (D-113) if the client confirms | Org attribution of purchases (D-97) | PRT-01 | P1 | M | Duplicate events stored once; forged requests rejected | PRT-01 | 1 |
| T-PRT-05 | Sales attribution | BLOCKED | Replaced by own courses (D-113) if the client confirms | Org attribution of purchases (D-97) | PRT-04 | P2 | M | Fixture-based attribution tests; dashboard live | PRT-01 | 1 |
| T-PRT-06 | Account linking | BLOCKED | Replaced by own courses (D-113) if the client confirms | Unaffected | PRT-04 | P2 | M | Link and unlink flows; FR-SET-04 | PRT-01 | 1 |
| T-PRT-07 | Course-aware coaching | BLOCKED | Replaced by own courses (D-113) if the client confirms | Unaffected | PRT-06, AGT-04 | P2 | M | Avatar references progress correctly in eval Done when | PRT-01 | 1 |

### Compliance

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-CMP-01 | Legal texts | BLOCKED | Drafts written; lawyer review needed | NEEDS MODIFICATION: Terms/Privacy must describe the Admin (buyer) role and what it can see | - | P0 | M | Signed off by counsel | Lawyer review | 1 |
| T-CMP-02 | Counsel review of avatar and voice | BLOCKED | - | Unaffected | - | P1 | M | Written sign-off; required changes ticketed | Counsel | 1 |
| T-CMP-03 | Data export | COMPLETED | Merged (PR #95, owner approved): Download my data (zip, 15-min link, 7-day lifecycle); new collections classified (D-82). Needs Blaze for staging; counsel to confirm exclusions | Unaffected; export stays the user's own right, never the Admin's | - | P0 | M | FR-SET-02 SLAs met in a staging test | - | 1 |
| T-CMP-04 | Penetration test | NOT STARTED | - | EXISTING BUT INCOMPLETE: scope adds privilege escalation and org isolation (T-SEC-01) | all | P0 | L | No high or critical findings open | - | 9 |

### Release

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-REL-01 | Accessibility audit | COMPLETED | Merged (PR #103): WCAG 2.2 AA sweep incl. Daily plan; fixes for the Plan map wheel and phone country field. VoiceOver/TalkBack check on a phone still to do | Unaffected | - | P1 | M | Audit report with no AA blockers complete | Owner VoiceOver/TalkBack check | 2 |
| T-REL-02 | Store listing and release | BLOCKED | Release checklist and signing ready; owner steps remain | NEEDS MODIFICATION: invite-only store review (demo account, D-97) | all | P0 | M | Beta KPIs collected for 4 weeks | Owner steps, Blaze, signing | 9 |

## Change log

| Date | Change |
|---|---|
| 2026-11-21 | Created: 71 spec tasks reconciled against `main`/PRs; 20 new tasks for the hierarchy requirements (T-PLN-00, T-IAM-*, T-SAD-*, T-ORG-*, T-INV-*, T-PRM-*, T-SEC-01). |
| 2026-11-21 | Owner approved the roadmap; T-AGT-04 started (IN PROGRESS). |
| 2026-11-21 | T-AGT-04 built, PR #111 (NEEDS REVIEW). |
| 2026-11-21 | T-AGT-04 merged (owner approved PR #111); AGT-05/06 READY. Roadmap PR #110 approved. |
| 2026-11-21 | T-ONB-01b added (owner request: phone sign-in any country, D-99); PR #112 (NEEDS REVIEW). |
| 2026-11-21 | T-ONB-01b merged (owner approved PR #112). |
| 2026-11-23 | T-AGT-05 Memory Agent built, server side (D-100); NEEDS REVIEW. Mobile list split out as T-AGT-05b. |
| 2026-11-23 | T-AGT-05 server side merged (owner approved PR #113). T-AGT-05b app screen built (D-101); NEEDS REVIEW. |
| 2026-11-23 | T-AGT-05b merged (PR #114) after a phone test; dev Firestore rules redeployed; screen-reader fix for Keep/Delete (D-102). |
| 2026-11-23 | Fix: cold start always showed "We couldn't start Live Well" (Firebase used before init); signed-in start reads the cached profile, Home in 1.3–1.9 s on the owner's phone (D-103). |
| 2026-11-23 | T-AGT-06 Insights Agent built (D-104); NEEDS REVIEW. |
| 2026-11-23 | T-AGT-06 merged (owner approved PR #117). T-AGT-07 Portal Agent built (D-105); NEEDS REVIEW. |
| 2026-11-26 | Owner review-and-merge pass (2026-11-25/26): merged PRs #81, #82, #83, #84, #85, #86, #87, #88, #89, #90, #92, #93, #94, #95, #96, #97, #98, #99, #101, #102, #103, #105, #110; #91 closed (replaced by T-PLN-00); #100 Travel Mode on hold (Plan placement, Places key, privacy line, clinical content). T-AGT-05 and T-AGT-07 signed off. Fixes at merge: voice-gateway bypass (D-88), crash reports off at sign-out (D-80), widget hidden by default on Android (D-68), export classification (D-82), accessibility fixes (T-REL-01). |
| 2026-11-28 | Section C added for the free-plan owner tasks (D-112 to D-118). Merged 2026-11-26/27: PRs #123, #124 (Android widget fixes), #125 (D-112 to D-116), #126 (T-IAM-10), #127 (T-LRN-10), #128/#129 (T-LRN-11), #130 (T-ASM-10), #131 (T-AVT-11), #132 (T-AVT-12). PR #133 (T-IAM-11, D-118) NEEDS REVIEW. T-AVT-13 (D-115) added, NOT STARTED. Summary now counts T-ONB-01b (it was left out). ASM-01/03, LRN-01/02 tools built, still BLOCKED on approved content; PRT-01, 04–07 noted as replaced by D-113 pending the client. |
