# Progress

Where the build is, and what comes next. Task prompts live in `docs/tasks/`; agreed changes in [decisions.md](decisions.md).

## Build order (from 2026-10-16)

Set by the owner. Work goes in this order, one task at a time, one PR per section, each stacked on the last and reviewed before the next starts.

| # | Task | What | Status (2026-10-16) |
|---|---|---|---|
| 1 | **T-UI-02** | Illustrated "Live Well v2" design (`docs/tasks/T-UI-02-illustrated-design.md`), PRs UI-02a to UI-02i | **In progress.** UI-02a to UI-02g open for review (PRs #29 to #35); UI-02h next |
| 2 | **T-ONB-03** | New onboarding flow and Profile (`docs/tasks/T-ONB-03-new-onboarding-flow-and-profile.md`) | Built, PRs #23 to #28 open for review; its avatar and voice screens move to the Studio design in UI-02h |
| 3 | **T-DLY-03** | Avatar Moments and habit logs | Not started (task file to come) |
| 4 | **T-AVT-06** | Anime-style avatar faces in the avatar maker (`docs/tasks/T-AVT-06-anime-avatar-style.md`) | Not started |
| 5 | **T-GOL-03** | "My Daily Routine", customized per day (`docs/tasks/T-GOL-03-my-daily-routine.md`) | Not started |
| 6 | **T-TCH-02** | Home-screen widget | Not started (task file to come) |

## Already merged to main

PRs #1 to #14: the foundations (Firebase dev project, logo and splash, design tokens, the 5-tab shell, CI, Firestore rules, consents, onboarding and sign-in, the Why, the red-flag rules) and the AGENTS.md rules. Everything after that is open in one stack, #15 (the mood-first check-in) to #35, each PR based on the one before.
