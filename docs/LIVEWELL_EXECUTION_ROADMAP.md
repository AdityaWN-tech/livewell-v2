# LiveWell V2 — Unified Execution Roadmap

One roadmap for the existing spec tasks and the new Superadmin / Admin / User requirements. Task detail: [master tracker](LIVEWELL_MASTER_TASK_TRACKER.md). Order follows real dependencies, not the order requirements arrived in.

**Working rules:** one task per branch off `main`; push only to `AdityaWN-tech/livewell-v2`; merge only after the owner's phone review and explicit approval; tracker and progress report updated after every task.

## Phase 0 — Audit and reconciliation (now)

| Task | Status | Exit |
|---|---|---|
| T-PLN-00 This reconciliation (6 docs, D-97) | NEEDS REVIEW | Owner approves this roadmap |
| T-IAM-00 Tenancy decision + spec addendum (ADR-004) | BLOCKED on owner + client | Options in the technical audit §4 decided |

**Change from the suggested order:** the tenancy *decision* moves into Phase 0. Every later hierarchy task depends on it, and deciding late risks a second data migration. Building still waits for Phase 3.

## Phase 1 — Unblock and finish the existing app

1. **Owner reviews the 24 open PRs** (#81–#103, #105). Suggested order: safety/consent/security first (#83, #88, #97, #98, #102, #95, #94), then the rest. #105 should merge before IAM-01.
2. **T-AGT-04 Coach Agent** (READY, P0, XL). Unblocks DLY-01/03/05, CNV-01/02, AGT-05/06/07.
3. Then T-AGT-05 Memory, T-AGT-06 Insights, T-AGT-07 Portal Agent; DLY-03 server jobs; FND-08 remaining collections.
4. Blocked items that need people, not code: ASM-01 clinical bank, CMP-01 lawyer, CMP-02 counsel, VOC-01 voice vendor, PRT-01 TagMango, LRN-01 lessons, Blaze plan, API credit. These are tracked, not worked around.

## Phase 2 — Mobile integration and regression

REL-01 VoiceOver/TalkBack on device; FND-10 crash reporting live; end-to-end check of every tab on a real phone (dev flavour) after Phase 1 merges; golden and integration tests green on CI. TCH-04..06 watch apps can run in parallel (P3).

## Phase 3 — Architecture, data and auth for the hierarchy (after D-97)

T-IAM-01 roles/claims → T-IAM-02 org model + migration → T-IAM-03 rules isolation → T-IAM-04 API guard → T-IAM-05 Superadmin provisioning.
**May start in parallel with late Phase 1**: it touches Core API, rules and data model, not the agents.

## Phase 4 — Superadmin

T-SAD-01 org + Admin console → T-SAD-04 audit viewer → T-SAD-02 global config → T-SAD-03 monitoring.

## Phase 5 — Admin and organization

T-ORG-01 org settings (region drives emergency numbers) → T-ORG-02 user management (no health data).

## Phase 6 — Invitations and allowlist

T-INV-01 secure invites → T-INV-02 allowlist at sign-up (needs Blaze + Identity Platform) → T-INV-03 mobile join flow (changes ONB-01).

## Phase 7 — Permissions and feature visibility

T-PRM-01 permission catalog + protected list → T-PRM-02 mobile gating.

## Phase 8 — Authorization everywhere

T-PRM-03 agents, Core API and rules enforce org + permission; authz matrix tests.

## Phase 9 — Security and production readiness

T-SEC-01 isolation/escalation suites in CI → T-CMP-04 pen test → T-REL-02 store release (invite-only review notes).

## Running work

No task is mid-implementation. Open PRs and how the hierarchy affects them:

| PR | Task | Affected? | Transition |
|---|---|---|---|
| #105 | PRT-02 admin catalog | Yes: staff role `admin` naming | Merge as is after review; IAM-01 renames with a compatibility alias. No rework of #105. |
| #97 | FND-09 audit log | Extended | Merge as is; SAD-04/IAM-05 add action names. |
| #85 | FND-11 flags | Extended | Merge as is; PRM-01 adds org layer. |
| #94 | FND-10 monitoring | Extended | Merge as is. |
| #96 | FND-07 migration | Coordinate | Merge or close (D-01); IAM-02 reuses the tool. |
| #88, #95, #92 | Consent revoke, data export, delete avatar | Constraint only | Merge as is; these stay user rights an Admin can never hide. |
| others | — | No | Continue unchanged. |

Owner of all open work: the repository owner (AdityaWN-tech). No other developer's branch is touched.

## Next ready task after approval

**T-AGT-04 Coach Agent** (Phase 1). The hierarchy stream starts once D-97 is decided.
