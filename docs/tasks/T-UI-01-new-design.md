# T-UI-01: Apply the new "Live Well Companion" design to all 5 tabs

| Field | Value |
|---|---|
| ID | T-UI-01 (split into PRs UI-01a to UI-01f below) |
| Title | New visual design: Home, Plan, Track, Learn, Care |
| Depends on | T-FND-04 (hide dev UI), T-DLY-02 (mood-first check-in) |
| Tag | needs human review (design + safety copy) |
| Design reference | `docs/design/screen.png` (the 5-screen mockup) |
| Spec refs | §4.1 principles, §14.1–14.3, FR-DLY-02/03/07, FR-GOL-01, FR-CNV-03/04, FR-VOC-08, §13.3–13.4, NFR-06/07 |

Read `AGENTS.md` and the Live Well v2 spec first. Save the mockup image into `docs/design/` and use it as the visual reference. **One PR per section below, stacked in order.** If the mockup and the spec disagree, the spec wins; follow the "Spec corrections" notes and flag anything else as a `needs-product` question.

---

## Global rules for every PR

1. **No fake data in staging/prod.** Every number, name and text in the mockup (Priya, Coach Maya, Day 9, 14-day streak, 7.5 hrs, 7/9 habits…) must come from real user data. If the data doesn't exist yet, show a friendly empty state. Sample data is allowed **only in the dev flavour**.
2. **Features not built yet** (avatar, AI chat, briefing audio, Health import, portal catalog) get the new UI shell with a clear empty or "coming soon" state, behind a Remote Config flag where the spec has one. Do not build the backend for them in this task.
3. **Reuse the design system.** Change tokens in one place (PR UI-01a); screens must use tokens, never hard-coded colours or sizes.
4. **Light and dark mode** for every screen. Golden tests for both.
5. **Accessibility (NFR-06):** WCAG 2.2 AA contrast, text labels for all icons/emoji, 44 pt tap targets, large text, screen reader.
6. **Copy:** about 8th-grade reading level, kind, never shaming (spec §4.1, NFR-07).
7. **Privacy:** no health values in analytics or logs (see AGENTS.md).

---

## PR UI-01a: Design tokens and theme

- New palette:
  - Terracotta `#D97457` (accent / primary action)
  - Forest Slate `#1E3834` (primary / dark surfaces)
  - Sage-Mint `#E1ECEB` (tints / light surfaces)
- Derive the full set: background, surface, text primary/secondary, tints, success, caution, emergency, plus dark-mode versions.
- **Contrast fix required:** `#D97457` with white text, or as small text on white, is below AA (about 3:1). Create an accessible darker terracotta (e.g. `accentStrong`) for text and button labels, and check every pair. Put a contrast table in the PR.
- **Emergency colour must stay clearly different from terracotta** (a true red, not orange), so safety cards never look like normal buttons.
- Keep Poppins unless the mockup font is confirmed otherwise (`needs-product`).
- Update the dev-only Design tokens screen to show the new tokens.
- Logo: keep the current logo until the client approves a change (`needs-product`).

## PR UI-01b: Home (Screen 1)

- Header: "LIVE WELL / Home", Day N pill (days since start, from real data).
- Coach card: avatar circle, "Coach {name} is online", "Hi, {first name}", Briefing button with duration.
  - **Spec correction:** the avatar image in the mockup is broken (shows random letters). Until Avatar Studio exists, show a default illustrated avatar or initials. Coach name comes from settings, default "Coach".
  - Briefing button hidden (or "coming soon") until briefings exist (flag).
- "Today's one step" card: driver label, title, short reason, **Done** (primary) and **Make it 5 min** (secondary).
- "Quick check-in · Takes 30s" row: opens the mood-first check-in from T-DLY-02. Hide it once today's check-in is done; show a small summary instead.
- Companion milestone card: phase progress and "habits kept" from real data.
- Also show the "Your Why" card (FR-ONB-05) in a compact form.
- **Spec correction (FR-DLY-03):** Home has at most 1 primary and 2 secondary actions. Done is primary; Make it 5 min and Quick check-in are secondary; Briefing counts as media, not an action. List the count in the PR.
- If today is a `gentle_day` (T-DLY-02), the step card uses the gentle message and smaller step.

## PR UI-01c: Plan (Screen 2)

- Header "SCHEDULE / Plan", "+ New Habit" button, "MY GOAL DO IT Framework · 8 Drivers" chip.
- Habit cards: driver tag, status (Done / In progress / Scheduled), title, target time, microstep, duration; completed items shown with strikethrough + Done badge.
- Affirmation card at the bottom.
- **Spec corrections:**
  - FR-GOL-01: max 1 daily microhabit + 2 supporting habits. "+ New Habit" must enforce this with a kind message when full.
  - Driver names must match Dr. Gokula's 8 drivers exactly (from the content files), not the mockup's sample names ("Rest Driver", "Hydration Driver"). `needs-product` if unsure.
  - Existing MY GOAL DO IT tabs stay reachable from Plan (FR-GOL-06).

## PR UI-01d: Track (Screen 3)

- Header "PROGRESSION / Track", "Weekly Wins" button.
- Streak card: N-day streak, Personal Best badge, Mon–Sun row.
  - **Spec correction (§4.1, FR-DLY-07):** a missed day must **not** show as a red/alarm dot. Use a neutral "rest" or "restart" style, and apply the 1-day weekly grace.
- "30-second daily check-in" grid: Energy, Sleep, Stress, Mood from today's check-in (T-DLY-02). Tap to log opens the check-in.
  - **Spec corrections:** use the 1–5 scale words, not percentages like "+15% vs yesterday" unless computed from real data. Replace clinical wording such as "Optimal baseline" with plain, kind words. Sleep hours and "Deep sleep" only when Health import exists; otherwise show the 1–5 sleep rating.
- Evening reflection card: "What went well today?" text field with mic (mic needs microphone consent). Save to `users/{uid}/reflections` and run text through the red-flag rules.

## PR UI-01e: Learn (Screen 4)

- Header "Learn / Approved knowledge".
- Portal card ("From the Live Well Portal", Paid course label, title, description, **View course** and **Not now**).
  - **Spec corrections (§13.3–13.4):** card only appears if portal consent is granted, not a `gentle_day`, no safety event in 72 h, within caps, and Not now is equally visible (it is). Content comes from the `portal_offers` catalog, never hard-coded; if the catalog is empty, show no card. Replace "post-prandial" and similar terms with plain words; no health-outcome claims. Behind the portal-cards flag.
- Curated library list: category label, title, subtitle, read time, "View all N". Empty state until lessons are loaded.

## PR UI-01f: Care (Screen 5)

- Header "DIRECT SUPPORT / Talk to your coach", status pill.
- Chat bubbles (user and coach), Sources chip under coach answers (FR-CNV-04), disclaimer line "Educational companion · Does not prescribe or change medication", **Hold to talk** button.
- **Spec corrections:**
  - The AI coach isn't built yet: show the UI with a friendly "Your coach is coming soon" state. No fake answers in staging/prod.
  - "Avatar Voice Active" pill → must show the **"AI voice"** label (FR-VOC-08) when voice is on.
  - Hold to talk requires microphone consent; text input must also be available (FR-CNV-07).
  - Anything the user types still goes through the red-flag safety rules (emergency/crisis cards from PR #13).
  - Add an always-visible "Get help now" link to safety resources (spec §14.2 Care tab).

---

## Tests (each PR)

- Golden tests: light + dark, normal + large text.
- Widget tests for each state: empty, with data, gentle day, safety block (where relevant).
- Accessibility test for labels and tap targets.
- Contrast table in UI-01a.

## Done when

- All 6 PRs pass tests.
- Each PR description has side-by-side screenshots: mockup vs app (light and dark), and the list of spec corrections applied.
- Open `needs-product` questions are listed in one place (UI-01a PR description).

## Out of scope

- Building the avatar, voice, AI chat backend, briefing generation, Health import or portal backend.
