# LiveWell V2 — Progress Report

Combined progress of the existing spec and the new hierarchy requirements. Update after every task (newest entry first in the log).

## Snapshot (2026-11-21)

| Scope | Tasks | Completed (merged) | Needs review | In progress / ready | Blocked | Not started | Merged | Built (merged + in review) |
|---|---|---|---|---|---|---|---|---|
| Existing spec | 71 | 15 | 22 | 4 | 21 | 9 | 21% | 52% |
| New hierarchy | 20 | 0 | 1 (T-PLN-00) | 0 | 1 (T-IAM-00) | 18 | 0% | 5% |
| **Combined** | **91** | **15** | **23** | **4** | **22** | **27** | **16%** | **42%** |

The live progress page shows about 56% for the spec because it also counts partly done tasks as half. The most honest single number is "built": 52% of spec tasks have finished code, but only 21% are merged, because 22 finished PRs are waiting for review. Effort is uneven: agents, portal and hierarchy tasks are the largest.

## Biggest blockers

1. **D-97 tenancy decision** (owner + client): blocks all 18 hierarchy build tasks.
2. **24 open PRs waiting for review.**
3. **People/vendors:** clinical content (ASM-01, lessons, prompts), lawyer (CMP-01), counsel (CMP-02), voice vendor, TagMango API, Blaze plan + Identity Platform, Anthropic API credit.

## Log

| Date | Task | Change | Tests | Branch / PR | Review | Merge |
|---|---|---|---|---|---|---|
| 2026-11-21 | T-ONB-01b | Phone sign-in any country: searchable country picker, per-country validation (D-99, reverses D-66); safety region rule unchanged | mobile 1188 (non-golden) | PR #112 | Needs review | No |
| 2026-11-21 | T-AGT-04 | Coach Agent: 5 modes, new endpoints, crisis rule fix (D-98) | agents 2397, harness 676 PASS, CI green | PR #111 | Approved | Done |
| 2026-11-21 | T-PLN-00 | Unified tracker, roadmap, audit, dependency map, status, this report; D-97 recorded | n/a (docs) | PR #110 | Approved | Done |
| 2026-11-21 | T-AGT-02b | 35 of 36 eval safety gaps closed (PR #109) | agents 2050, mobile 1168, CI green | merged | Approved | Done |
| 2026-11-21 | T-AGT-02/03/08 | Classifier, content pipeline, eval harness (PRs #107, #106, #108) | CI green on `main` | merged | Approved | Done |
| 2026-11-21 | T-AGT-01 | Agent service (PR #104) | 351 tests, CI green | merged | Approved | Done |
