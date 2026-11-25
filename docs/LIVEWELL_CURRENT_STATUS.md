# LiveWell V2 — Current Status

As of 2026-11-21. Single source for task-level detail: [LIVEWELL_MASTER_TASK_TRACKER.md](LIVEWELL_MASTER_TASK_TRACKER.md).

## How status was verified

- `main` on `AdityaWN-tech/livewell-v2` at `bbb3f1f` (after PR #109). CI green on `main` for agents, safety-rules and mobile.
- 24 open PRs (#81–#103, #105), each with CI green when last checked, none merged.
- Spec v1.0 section 17 (71 tasks), `docs/decisions.md`, `docs/ROADMAP.md`, `docs/tasks/`, 32 TODO/FIXME comments in code (all reference an existing task ID; none is an untracked task).
- A task is COMPLETED only if it is merged to `main` with CI green. Built-but-unmerged work is NEEDS REVIEW.

## Existing project (71 spec tasks)

| Status | Count | Meaning here |
|---|---|---|
| COMPLETED | 15 | Merged, CI green (some still need a real-device or clinical check, noted per task) |
| NEEDS REVIEW | 22 | Built in an open PR, waiting for owner review |
| IN PROGRESS | 3 | DLY-01, DLY-05, DLY-07: app side built, AI part waits for the Coach Agent |
| READY | 1 | T-AGT-04 Coach Agent: all dependencies merged |
| BLOCKED | 21 | Waiting on people or vendors (clinical content, lawyer, voice vendor, TagMango, Blaze plan, API credit) |
| NOT STARTED | 9 | Mostly depend on AGT-04, plus watch apps and the pen test |

Completion: 15 of 71 spec tasks merged (21%); 37 of 71 have finished code merged or in review (52%). The live progress page shows about 56% because it also counts partly done tasks as half. Agents, portal and watch work are the largest remaining items.

## New requirements from sir (Superadmin / Admin / User)

| Req | Summary | Status today |
|---|---|---|
| A Superadmin | Internal team, global admin, manage Admin accounts, global config, monitoring, admin audit logs | **Partly reusable, not built.** Platform staff roles exist in PR #105 (content editor, clinical reviewer, safety reviewer, admin) with MFA rule; audit log in PR #97; monitoring base in PR #94; flags in PR #85. No org or Admin-account management. |
| B Admin (buyer) | Own org, invite/manage users, allowlist, permissions, feature visibility, org settings | **Not built.** No organization concept exists anywhere in code, rules or data model. |
| C Users | Invite-only join, allowlist check, org membership, permissions, see only allowed features | **Conflicts with current design.** Today anyone 18+ can sign up (FR-ONB-01); all users are equal. |
| D Security | Backend RBAC, org isolation, permission checks, secure invites, no escalation, secure Superadmin provisioning | **Partly reusable.** Firestore rules are per-user with 100% emulator coverage; Core API has a staff-role guard (PR #105). No org isolation or permission model. |

**Key finding:** spec v1.0 is a single consumer (B2C) app for Dr. Gokula. An "employer variant" is listed only under Phase 4 "Scale … per future spec". The new hierarchy is therefore a **spec change** (AGENTS.md: conflicts are stopped and recorded). It is recorded as D-97 (*needs client*) and task T-IAM-00. No hierarchy code will be written before that decision.

## Running work

No agent or developer is mid-task. The 24 open PRs are finished work waiting for review; see [LIVEWELL_EXECUTION_ROADMAP.md](LIVEWELL_EXECUTION_ROADMAP.md#running-work) for which ones the hierarchy affects.
