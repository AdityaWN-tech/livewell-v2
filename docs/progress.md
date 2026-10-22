# Progress

Where the build is, and what comes next. Task prompts live in `docs/tasks/`; agreed changes in [decisions.md](decisions.md).

## Build order (updated 2026-10-22)

Set by the owner. Work goes in this order, one task at a time, one PR per section, each stacked on the last and reviewed before the next starts.

| # | Task | What | Status (2026-10-22) |
|---|---|---|---|
| 1 | **T-UI-02** | Illustrated "Live Well v2" design (`docs/tasks/T-UI-02-illustrated-design.md`), PRs UI-02a to UI-02i | Built, PRs #29 to #35, #37, #38 open for review. **Its avatar parts (the layered cartoon creator, UI-02h) are replaced by T-AVT-08.** |
| 2 | **T-ONB-03** | New onboarding flow and Profile (`docs/tasks/T-ONB-03-new-onboarding-flow-and-profile.md`) | Built, PRs #23 to #28 and #39 open for review |
| 3 | **T-DLY-03** | Avatar Moments (`docs/tasks/T-DLY-03-avatar-daily-moments.md`) | DLY-03a to DLY-03d built (PRs #40 to #43); DLY-03e (settings) waits. **Now uses the T-AVT-08 avatar.** |
| 4 | ~~T-AVT-06~~ | ~~Anime-style avatar faces~~ (`docs/tasks/T-AVT-06-anime-avatar-style.md`) | **Cancelled (2026-10-22).** PRs #44 and #45 closed unmerged; the style-neutral engine (blink, lip shapes, expression mapping) moved into T-AVT-08 |
| 5 | **T-AVT-07** | 3D avatar | **Merged into T-AVT-08** |
| 6 | **T-AVT-08** | 3D adult avatar coach, everything the avatar does, and the widget (`docs/tasks/T-AVT-08-3d-avatar-coach-and-widget.md`), PRs AVT-08a to AVT-08h | **In progress.** AVT-08a (clean-up and frame-set engine) open for review |
| 7 | **T-GOL-03** | "My Daily Routine", customized per day (`docs/tasks/T-GOL-03-my-daily-routine.md`) | Not started. **Its reminders use the T-AVT-08 avatar.** |
| 8 | **T-TCH-02** | Home-screen widget (`docs/tasks/T-TCH-02-daily-routine-widget.md`) | Not started. **Its widget is built as AVT-08g with the 3D avatar.** |

## Already merged to main

PRs #1 to #14: the foundations (Firebase dev project, logo and splash, design tokens, the 5-tab shell, CI, Firestore rules, consents, onboarding and sign-in, the Why, the red-flag rules) and the AGENTS.md rules. Everything after that is open in one stack, #15 (the mood-first check-in) onwards, each PR based on the one before.
