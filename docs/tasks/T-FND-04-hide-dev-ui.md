# T-FND-04 follow-up: Hide developer-only UI from Home

| Field | Value |
|---|---|
| ID | T-FND-04 (follow-up) |
| Title | Hide developer-only UI from Home |
| Branch | `task/T-FND-04-hide-dev-ui` |
| Depends on | Latest merged/stacked PR |
| Tag | — |
| Spec refs | §17.1 (working agreement), FR-DLY-03 (Home shows max 1 primary + 2 secondary actions) |

Read `AGENTS.md` and the Live Well v2 spec before starting. Follow the working agreement in spec §17.1.

## Context

Real users must never see developer tools. The "Design tokens" button on Home and the Design tokens screen are for developers only.

## Build

1. Show the "Design tokens" button and route **only in the dev flavour** (same approach used for the "Preview the app" button in PR #9). In staging and prod builds:
   - the button is not rendered on Home;
   - the route is not registered in go_router (opening it by deep link must not work).
2. Move the Design tokens entry point out of Home into a **Developer** section at the bottom of Settings (dev flavour only), so Home stays clean.
3. Check the whole app for any other developer-only UI (debug buttons, test screens, sample data) and put them behind the same dev-only check. List what you found in the PR description.
4. After this change, Home shows only:
   - the "Your Why" card;
   - the "Your day starts here" empty state (replaced later by T-DLY-02).

## Tests

- Widget test: Home in prod/staging config has no "Design tokens" button.
- Widget test: in dev config the entry point appears in Settings > Developer.
- Router test: the design-tokens route is unreachable in prod config.

## Done when

- All tests pass.
- The PR description includes screenshots of Home in dev and prod builds, plus the list of other dev-only UI found and hidden.

## Out of scope

- Mood check-in (T-DLY-02).
- Any visual change to the design system itself.
