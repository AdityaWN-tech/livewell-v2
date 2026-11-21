# LiveWell V2 — Master Task Tracker

The single task list for the whole project: the 71 spec tasks (section 17) and the new hierarchy requirements (Superadmin / Admin / User).
Status as of 2026-11-21, checked against `main`, the open PRs and CI. Update this file whenever a task changes state.

**Statuses:** NOT STARTED · READY · IN PROGRESS · BLOCKED · NEEDS REVIEW · TESTING · VERIFIED · COMPLETED. COMPLETED = merged to `main` with CI green. NEEDS REVIEW = built, in an open PR, waiting for the owner. Acceptance criteria for spec tasks are the spec's "Done when" (section 17); tests follow spec 15.1 plus AGENTS.md rule 3.

**Priority:** P0 release/safety critical · P1 needed for beta · P2 needed for launch · P3 later. **Complexity:** S < 2 days · M ≤ 1 week · L 1–2 weeks · XL > 2 weeks.

## Summary

| Status | Existing tasks | New tasks | Total |
|---|---|---|---|
| COMPLETED | 15 | 0 | 15 |
| NEEDS REVIEW | 23 | 1 | 24 |
| IN PROGRESS | 3 | 0 | 3 |
| BLOCKED | 21 | 1 | 22 |
| NOT STARTED | 9 | 18 | 27 |
| **Total** | **71** | **20** | **91** |

## A. New tasks (hierarchy requirements and reconciliation)

| ID | Task | Source | Module | Status | Comparison | Required changes | Depends on | Pri | Size | Acceptance | Tests | Risks | Phase |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T-PLN-00 | Task reconciliation and unified roadmap | Reconciliation | Docs | NEEDS REVIEW (roadmap approved by owner 2026-11-21) | COMPLETELY NEW | These six docs; D-97 recorded | - | P0 | S | Owner approves roadmap | n/a (docs) | Stale if not kept up to date | 0 |
| T-IAM-00 | Decide tenancy model and change the spec (ADR-004, D-97) | New sir requirement | Architecture | BLOCKED | NEEDS DECISION + CONFLICTING | ADR-004: single-tenant per buyer vs multi-tenant orgs; invite-only vs open sign-up; what Admin can see; content/offers global or per org | - | P0 | M | ADR-004 approved by owner and client; AGENTS.md and spec addendum updated | Review only | Wrong choice forces data migration later | 0 |
| T-IAM-01 | Role model: superadmin / org_admin / member + platform staff roles | New sir requirement | Auth, Core API | NOT STARTED | EXISTING BUT NEEDS MODIFICATION (PRT-02 staff_roles) | Custom claims {role, org_id, staff_roles, perms_v}; rename PRT-02 'admin' to platform role; claims only set server-side | T-IAM-00, PRT-02 merged | P0 | M | Claims set only via Admin SDK; client cannot change role; token refresh after change | Core API unit + emulator tests; escalation attempts | Claim drift between token and DB | 3 |
| T-IAM-02 | Organization data model + migration (default org for existing users) | New sir requirement | Data model | NOT STARTED | COMPLETELY NEW | organizations/{orgId}, org_members, users.org_id; data-model.md; dry-run migration to a default org | T-IAM-00, FND-07 | P0 | L | Every user has exactly one org; migration dry-run + rollback documented | Migration tests on emulator | Breaks existing user paths if done ad hoc | 3 |
| T-IAM-03 | Firestore rules: org isolation and role checks | New sir requirement | firebase/ | NOT STARTED | EXISTING BUT NEEDS MODIFICATION (FND-06) | Add org/role predicates; Admin never reads health sub-collections; keep 100% coverage | T-IAM-01, T-IAM-02 | P0 | L | Cross-org read/write denied for every collection; coverage gate 100% | Emulator rules tests incl. cross-org and escalation | Rule mistakes leak health data | 3 |
| T-IAM-04 | Core API authorization middleware (role + org + permission) | New sir requirement | services/core-api | NOT STARTED | EXISTING BUT INCOMPLETE (staff.ts) | One zod-validated guard for every callable; deny by default; audit every admin action | T-IAM-01 | P0 | M | Every endpoint declares required role/permission; unknown = denied | Unit + emulator tests per endpoint | Missed endpoint | 3 |
| T-IAM-05 | Secure Superadmin provisioning | New sir requirement | Ops, Core API | NOT STARTED | EXISTING BUT INCOMPLETE (set-staff-claims script) | Superadmin only via owner-run Admin SDK script with MFA; no API can create a superadmin; break-glass procedure; audit | T-IAM-01, FND-09 | P0 | S | No client/API path grants superadmin; MFA required | Escalation tests | Lost superadmin access; insider risk | 3 |
| T-SAD-01 | Superadmin console: organizations and Admin accounts | New sir requirement | apps/admin | NOT STARTED | EXISTING BUT INCOMPLETE (Admin web from PRT-02) | Create/suspend orgs; invite/remove org Admins; Flutter Web admin app | T-IAM-04, T-IAM-05 | P1 | L | Superadmin can create org and first Admin; actions audited | Widget + API + emulator tests | Over-powerful console | 4 |
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

## B. Existing spec tasks (IDs preserved)

Source for all rows: existing project (spec v1.0 section 17). "Hierarchy impact" is the comparison with the new requirements.


### Foundation

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-FND-01 | Audit of the prototype code | COMPLETED | - | Unaffected | - | P1 | S | Audit doc merged and reviewed by the tech lead | - | 0 |
| T-FND-02 | Monorepo and CI | COMPLETED | Mobile, media, API, rules, safety and iOS checks run on every PR | Unaffected | - | P0 | M | CI green on an empty PR; dev, staging and prod deployable | - | 0 |
| T-FND-03 | Vendor and framework choices | NEEDS REVIEW | PR #101. LangGraph, Claude, Flutter Web admin and Next.js voice-owner page chosen (PR #101); morning-briefing prototype merged (PR #104) but not yet run against real Claude (the API account needs credit) | Unaffected | - | P0 | M | ADRs merged with scorecards against the Section 8.3 criteria; morning-briefing prototype runs end to end | - | 1 |
| T-FND-04 | App shell with 5 tabs | COMPLETED | - | NEEDS MODIFICATION: tabs/routes must hide unauthorised features (T-PRM-02) | - | P0 | M | All prototype screens reachable; golden tests for core components | - | 0 |
| T-FND-05 | Consent service | NEEDS REVIEW | PR #88. Server deletes data after a revoke in PR #88; needs human review | Unaffected; consent stays per user and can never be hidden by permissions | FND-06 | P0 | M | Grant and revoke for every consent type; emulator tests; audit entries | - | 1 |
| T-FND-06 | Firestore security rules and tests | COMPLETED | - | NEEDS MODIFICATION: org isolation and role checks (T-IAM-03) | - | P0 | L | 100% rule coverage tests pass | - | 0 |
| T-FND-07 | Moving data from the old app | NEEDS REVIEW | PR #96. Dry-run-first tool in PR #96; staging dry run needs the owner; dropped in D-01 unless old data turns up | Coordinate: org_id backfill is a second migration (T-IAM-02) | FND-06 | P2 | M | Dry run on a staging copy; reversible; counts reconcile Done when | Close if no prototype data (D-01) | 1 |
| T-FND-08 | Encrypted on-phone database | NEEDS REVIEW | PR #98. Encrypted database and offline queue for check-ins in PR #98; habits, routines, goals and reflections still to move | Unaffected (on-device data) | - | P1 | L | Offline log, then reconnect, syncs exactly once (integration test) | - | 1 |
| T-FND-09 | Audit log | NEEDS REVIEW | PR #97. Append-only, tamper-evident log with a write-only account in PR #97; needs security review; Terraform not applied | EXISTING BUT INCOMPLETE: reuse for admin/superadmin audit (T-SAD-04) | - | P0 | M | Write-only service account; tamper test fails as expected | - | 1 |
| T-FND-10 | Crash reporting and monitoring | NEEDS REVIEW | PR #94. Crashlytics without health data, server logging and alerts in PR #94; agent tracing waits for the agents | EXISTING BUT INCOMPLETE: base for system monitoring (T-SAD-03) | - | P1 | M | Test crash shows no PHI; trace visible for a sample agent run | - | 2 |
| T-FND-11 | Feature flags | NEEDS REVIEW | PR #85. Remote Config with safe defaults in PR #85 | EXISTING BUT INCOMPLETE: global flags; org-level visibility added in T-PRM-01 | - | P1 | M | Each flag in Section 10.2 toggles behavior in staging Done when | - | 1 |

### Onboarding

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-ONB-01 | Onboarding, 18+ check, sign-in | COMPLETED | Apple sign-in not yet tried on a device; fingerprint or face lock added | CONFLICTING: open sign-up vs invitation + allowlist (T-INV-03, D-97) | FND-04 | P0 | L | FR-ONB-01..06 acceptance criteria pass | - | 0 |
| T-ONB-02 | Personal Why | COMPLETED | - | Unaffected | ONB-01 | P1 | S | Saved and displayed on Home | - | 0 |

### Assessment & safety

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-ASM-01 | Question bank | BLOCKED | Not built: no questions, schema or assessment screens yet; needs clinical content | Unaffected | - | P1 | L | Bank v1.0 loads; schema validation in CI | Clinical content (questions, driver names) | 1 |
| T-ASM-02 | Red-flag safety rules | COMPLETED | Critical safety set passes at 100%; needs clinical review | Unaffected; safety can never be hidden by permissions | - | P0 | M | All red-flag rule tests pass | Clinical review | 0 |
| T-ASM-03 | Scoring and Live Well Map | BLOCKED | Waits for the question bank (ASM-01); the map shows habit progress for now | Unaffected | ASM-01 | P1 | M | FR-ASM-03 copy review; snapshot tests Done when | Waits for ASM-01 | 1 |

### Avatar

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-AVT-01 | Avatar renderer | COMPLETED | Built as the 3D coach | Unaffected | - | P1 | L | Renders at 60 fps on a mid-range device; 5 expressions; lip-sync demo | - | 0 |
| T-AVT-02 | Avatar creator | COMPLETED | 8 ready-made coaches and the Avatar Studio | Feature-visibility candidate | AVT-01 | P1 | L | FR-AVT-02 checklist met Done when | - | 0 |
| T-AVT-03 | Avatar from a selfie | BLOCKED | Built, switched off: needs counsel review and the server deployed | Feature-visibility candidate | AVT-02, CMP-02 | P2 | L | Spoof tests fail as expected; job status polling works; raw media TTL enforced | Counsel review; server deploy | 1 |
| T-AVT-04 | Avatar fallback and reduced motion | COMPLETED | - | Unaffected | AVT-01 | P1 | S | FR-AVT-05/06 tests pass offline | - | 0 |
| T-AVT-05 | Delete my avatar | NEEDS REVIEW | PR #92. In PR #92; vendor confirmation waits for an avatar vendor | Unaffected (user right; never hidden) | FND-05 | P0 | M | Vendor API confirms; audit entry; UI updates Done when | - | 1 |

### Voice

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-VOC-01 | Voice engine | BLOCKED | Coach uses the phone's own speech for now | Unaffected | - | P1 | L | Contract tests pass against the vendor sandbox | Voice vendor | 1 |
| T-VOC-02 | Voice library | NEEDS REVIEW | PR #89. 6 of the 12 voices; "How this voice is made" in PR #89 | Feature-visibility candidate | VOC-01 | P2 | M | FR-VOC-01 met | 6 of 12 voices | 1 |
| T-VOC-03 | Clone your own voice | BLOCKED | Needs a voice vendor | Feature-visibility candidate | VOC-01, CMP-02 | P2 | L | E2E test; consent record matches Section 11 example | Voice vendor | 1 |
| T-VOC-04 | Invite a loved one's voice | BLOCKED | Phase 2 | Separate from org invitations (different purpose); reuse signed-link pattern | VOC-01 | P3 | L | See the card in 17.3 | Phase 2 of spec | 1 |
| T-VOC-05 | Loved one's consent recording | BLOCKED | - | Unaffected | VOC-04 | P3 | M | Uploaded files rejected; speaker match enforced | Phase 2 of spec | 1 |
| T-VOC-06 | Voice owner's dashboard | BLOCKED | - | Unaffected | VOC-05 | P3 | M | Revoke deletes the vendor model within 24 h (job test); account | Phase 2 of spec | 1 |
| T-VOC-07 | Closed-script voice gateway | NEEDS REVIEW | PR #102. Server gateway with 48 safety and pen-test cases in PR #102; needs a human safety review; no voice vendor connected yet | Unaffected; closed-script rule never configurable by Admin | - | P0 | M | Pen-test script cannot get arbitrary text spoken; safety categories use a neutral voice | - | 1 |
| T-VOC-08 | Dr. Gokula's voice | BLOCKED | Switched off; needs a licence | Unaffected | VOC-07 | P2 | M | Flag off by default; label visible legal sign- Done when | Licence | 1 |

### AI agents

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-AGT-01 | Agent service | BLOCKED | FastAPI + LangGraph service with safety checks before and after the model, 351 tests, merged into main (PR #104); not deployed and doesn't save messages yet | NEEDS MODIFICATION: endpoints check org/role (T-PRM-03) | - | P0 | L | Hello-world turn traced end to end; invalid JSON is retried | Deploy needs Blaze + API credit | 1 |
| T-AGT-02 | Safety checks before and after AI | COMPLETED | Rules plus an AI classifier that can only make a check stricter, 805 safety cases at 100%, merged (PR #107); still needs clinical sign-off on the classifier prompts | Unaffected; never configurable by Admin | AGT-01 | P0 | L | 15.3 critical cases at 100% | Clinical sign-off (D-93/D-96) | 0 |
| T-AGT-03 | Content pipeline | BLOCKED | Approved-only pipeline, chunking and search with precision@5 of 0.86 on synthetic lessons, merged (PR #106); production search service and real lessons still to come | Decide: content global or per org (D-97) | AGT-01 | P1 | L | Unapproved item not retrievable (test); retrieval precision@5 of 0.8 or more on the eval set | Prod embedding/vector store choice (D-94) | 1 |
| T-AGT-04 | Coach Agent | NEEDS REVIEW | PR #111. Five modes on one pipeline, 2397 tests, 676 golden cases (gate PASS); offline 15.2 gates met, live tone/grounding unmeasured (no API credit) | Unaffected | AGT-02, AGT-03 | P0 | XL | Eval gates in 15.2 pass | - | 1 |
| T-AGT-05 | Memory Agent | NOT STARTED | - | Unaffected (memory is per user, never visible to Admin) | AGT-04 | P1 | L | FR-CNV-05 met; sensitive categories need opt-in | - | 1 |
| T-AGT-06 | Insights Agent | NOT STARTED | - | Unaffected | AGT-04 | P1 | M | Matches the deterministic statistics on fixtures | - | 1 |
| T-AGT-07 | Portal Agent | NOT STARTED | - | Decide: offers global or per org (D-97) | AGT-04, PRT-02 | P2 | L | All 13.3 rules have unit tests; zero hallucinated offers in eval | - | 1 |
| T-AGT-08 | AI evaluation tests | COMPLETED | 388-case golden set and a CI gate merged (PR #108); it found 36 real safety gaps; 35 are fixed (all 28 critical, PR #109), one harmless over-block is left for a clinician | Extend with authz cases later (T-SEC-01) | AGT-02 | P0 | L | CI blocks merge on a critical failure Done when | - | 0 |

### Daily loop

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-DLY-01 | Home screen | IN PROGRESS | Spoken briefing is switched off until the Coach Agent exists | Unaffected | AGT-04 | P0 | M | FR-DLY-03 enforced in UI tests | Spoken briefing waits for AGT-04 | 1 |
| T-DLY-02 | Daily check-in | NEEDS REVIEW | PR #83. Safety fixes waiting in PR #83 | Unaffected | ASM-02 | P0 | M | Timed usability test median under 30 s | - | 1 |
| T-DLY-03 | Daily plan and briefing | NEEDS REVIEW | PR #93. Avatar moments and their settings (PR #93) built in the app; server jobs not built | Unaffected | AGT-04 | P1 | L | NFR-03 met in a staging load test | Server jobs not built | 1 |
| T-DLY-04 | Reminder scheduling with caps | NEEDS REVIEW | PR #84. One cap of 4 a day across all reminders in PR #84 | Unaffected; frequency cap never configurable by Admin | - | P1 | M | FR-DLY-04, FR-TCH-01 tests Done when | - | 1 |
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
| T-TCH-01 | Push notifications | NEEDS REVIEW | PR #90. Server push with consent, quiet hours and the cap in PR #90; owner setup needed for real devices | Unaffected; no personal data in pushes | - | P1 | M | Each category toggles; no PHI on the lock screen | Owner FCM/APNs setup | 1 |
| T-TCH-02 | iPhone widgets | COMPLETED | Builds in the cloud; not yet seen on a real iPhone | Unaffected | - | P2 | M | Done logs offline and syncs; snapshot tests | Not seen on a real iPhone | 0 |
| T-TCH-03 | Android widgets | NEEDS REVIEW | PR #81, #82. Lock-screen privacy and analytics in PRs #81 and #82 | Unaffected | - | P2 | M | Parity checklist with iOS | - | 1 |
| T-TCH-04 | Apple Watch app | NOT STARTED | - | Unaffected | TCH-01 | P3 | L | FR-TCH-05 checklist | - | 1 |
| T-TCH-05 | Wear OS app | NOT STARTED | - | Unaffected | TCH-01 | P3 | L | FR-TCH-05 checklist | - | 1 |
| T-TCH-06 | Watch complications | NOT STARTED | - | Unaffected | TCH-04, TCH-05 | P3 | M | FR-TCH-04/06 Done when | - | 1 |

### Learn

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-LRN-01 | Lesson library | BLOCKED | Reader works; no approved lessons yet | Feature-visibility candidate | AGT-03 | P1 | M | At least 24 approved lessons load; narration plays Done when | Approved lessons (24+) | 1 |
| T-LRN-02 | Breathing and audio sessions | BLOCKED | 3 breathing exercises; no recorded audio | Feature-visibility candidate | - | P2 | M | Work offline | Recorded audio | 1 |

### Goals & tracking

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-GOL-01 | Goals and habits | COMPLETED | - | Unaffected | - | P1 | M | FR-GOL-01..06 | - | 0 |
| T-GOL-02 | Tracking | NEEDS REVIEW | PR #86. Manual weight, blood pressure, glucose and meals with charts in PR #86 | Feature-visibility candidate | GOL-01 | P1 | M | Source and timestamp shown on every point | - | 1 |

### Travel

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-TRV-01 | Travel Mode | NEEDS REVIEW | PR #100. Trips, streak protection, pillar content and labelled nearby places in PR #100; content needs clinical approval; in-app listings need a maps key | Feature-visibility candidate | - | P2 | M | FR-TRV-01..03 | Clinical approval; maps key | 1 |

### Rewards

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-GAM-01 | Badges and challenges | NEEDS REVIEW | PR #99. Badges, weekly challenges, unlockables and the driver wheel in PR #99; off outside dev until clinical review; driver names provisional | Feature-visibility candidate | - | P2 | M | FR-GAM-01..03; banned reward types absent Done when | Clinical review | 1 |

### Portal

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-PRT-01 | Confirm the TagMango API | BLOCKED | Waiting on TagMango details | Decide: one TagMango account or one per org (D-97) | - | P1 | M | ADR with sample payloads captured in a sandbox or test course | TagMango API details | 1 |
| T-PRT-02 | Portal catalog in Admin | NEEDS REVIEW | PR #105. Flutter Web Admin with draft, review, approve and publish in PR #105; the app sees active offers only; needs security review and an MFA choice | NEEDS MODIFICATION: staff role 'admin' collides with org Admin; becomes platform roles under Superadmin (T-IAM-01) | - | P1 | L | Editors can publish offers; clients see active ones only | MFA method | 1 |
| T-PRT-03 | Portal card in the app | NEEDS REVIEW | PR #87. On Learn and after a lesson (PR #87); needs product sign-off | Feature-visibility candidate | PRT-02 | P1 | M | UTM and lw_cid present; click event logged | Product sign-off | 1 |
| T-PRT-04 | TagMango webhooks | BLOCKED | - | Org attribution of purchases (D-97) | PRT-01 | P1 | M | Duplicate events stored once; forged requests rejected | PRT-01 | 1 |
| T-PRT-05 | Sales attribution | BLOCKED | - | Org attribution of purchases (D-97) | PRT-04 | P2 | M | Fixture-based attribution tests; dashboard live | PRT-01 | 1 |
| T-PRT-06 | Account linking | BLOCKED | - | Unaffected | PRT-04 | P2 | M | Link and unlink flows; FR-SET-04 | PRT-01 | 1 |
| T-PRT-07 | Course-aware coaching | BLOCKED | - | Unaffected | PRT-06, AGT-04 | P2 | M | Avatar references progress correctly in eval Done when | PRT-01 | 1 |

### Compliance

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-CMP-01 | Legal texts | BLOCKED | Drafts written; lawyer review needed | NEEDS MODIFICATION: Terms/Privacy must describe the Admin (buyer) role and what it can see | - | P0 | M | Signed off by counsel | Lawyer review | 1 |
| T-CMP-02 | Counsel review of avatar and voice | BLOCKED | - | Unaffected | - | P1 | M | Written sign-off; required changes ticketed | Counsel | 1 |
| T-CMP-03 | Data export | NEEDS REVIEW | PR #95. Download my data in PR #95; staging check needs Blaze; counsel to confirm what is left out | Unaffected; export stays the user's own right, never the Admin's | - | P0 | M | FR-SET-02 SLAs met in a staging test | - | 1 |
| T-CMP-04 | Penetration test | NOT STARTED | - | EXISTING BUT INCOMPLETE: scope adds privilege escalation and org isolation (T-SEC-01) | all | P0 | L | No high or critical findings open | - | 9 |

### Release

| ID | Task | Status | Evidence / notes | Hierarchy impact | Depends on | Pri | Size | Acceptance (spec "Done when") | Blocker | Phase |
|---|---|---|---|---|---|---|---|---|---|---|
| T-REL-01 | Accessibility audit | NEEDS REVIEW | PR #103. WCAG 2.2 AA sweep of every prod screen and fixes in PR #103; your VoiceOver and TalkBack check on a phone is still open | Unaffected | - | P1 | M | Audit report with no AA blockers complete | Owner VoiceOver/TalkBack check | 2 |
| T-REL-02 | Store listing and release | BLOCKED | Release checklist and signing ready; owner steps remain | NEEDS MODIFICATION: invite-only store review (demo account, D-97) | all | P0 | M | Beta KPIs collected for 4 weeks | Owner steps, Blaze, signing | 9 |

## Change log

| Date | Change |
|---|---|
| 2026-11-21 | Created: 71 spec tasks reconciled against `main`/PRs; 20 new tasks for the hierarchy requirements (T-PLN-00, T-IAM-*, T-SAD-*, T-ORG-*, T-INV-*, T-PRM-*, T-SEC-01). |
| 2026-11-21 | Owner approved the roadmap; T-AGT-04 started (IN PROGRESS). |
| 2026-11-21 | T-AGT-04 built, PR #111 (NEEDS REVIEW). |
