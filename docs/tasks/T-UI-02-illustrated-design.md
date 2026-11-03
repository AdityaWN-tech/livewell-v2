# T-UI-02: Illustrated "Live Well v2" design (replaces T-UI-01)

| Field | Value |
|---|---|
| ID | T-UI-02 (split into PRs UI-02a to UI-02i below) |
| Replaces | **T-UI-01** (terracotta design). Do not build T-UI-01. If any UI-01 PR exists, close it and reuse what fits. |
| Depends on | T-FND-04 (hide dev UI), T-DLY-02 (mood check-in) |
| Works with | T-ONB-03 (new onboarding): its avatar and voice screens must use the Avatar & Voice Studio design from UI-02h |
| Tag | needs human review (design, safety copy, licensing of art) |
| Design reference | `docs/design/live-well-v2-illustrated.png` (6 screens + feature strip) |
| Spec refs | §4.1, §7, §14.1–14.3, FR-DLY-02/03/07, FR-GOL-01/05, FR-CNV-01/04/07, FR-VOC-01..08, FR-LRN-01..04, §13.4, NFR-06/07 |

Read `AGENTS.md` and the Live Well v2 spec first. Save the design image to `docs/design/`. **One PR per section, stacked in order.** Match the reference as closely as possible in layout, style, colours, illustrations and characters. If the design and the spec disagree, the spec wins: apply the "Spec corrections" notes and flag anything else as `needs-product`.

---

## Look and feel (applies everywhere)

- **Mood:** friendly, bright, calm, hopeful. Tagline: "Small steps. Brighter days."
- **Background:** very light mint-to-sky wash on screens; white rounded cards on top.
- **Cards:** large radius (about 20–24), soft fill colours per category, generous padding, no heavy borders, very soft shadows only.
- **Illustrations everywhere:** flat, hand-drawn style, soft pastel colours, gentle outlines, leafy plants as decoration (see asset list in UI-02b).
- **Character:** the user's coach avatar (default: friendly cartoon person in a green hoodie) appears on Home, Care and the Studio with speech bubbles.
- **Icons:** rounded, friendly outline icons with small coloured fills (mood face, lightning, moon, lotus, flame, leaf).
- **Charts:** rounded pastel bars, highlighted current day with a value bubble.
- **Chips and tabs:** pill shaped; selected = solid green with white text, others = light grey/tinted.
- **Typography:** rounded geometric sans. Keep Poppins unless the product owner chooses another (`needs-product`). Big friendly headings, short body text.
- **Bottom navigation:** Home, Plan, Track, Learn, Care with outline icons; the active tab is filled and coloured.
- **Profile:** a small round profile picture button in the top-right header of every tab (from T-ONB-03f, Option A). On Home it sits next to search and the bell.

---

## PR UI-02a: Design tokens and theme

Create tokens from the reference (pick exact hex values from the image, then tune for contrast):

| Token group | Use |
|---|---|
| `primary` (fresh green) | selected chips, active tab, main buttons, progress |
| `primaryDark` (deep green) | text on green tints, icons |
| `mint`, `lime`, `lavender`, `peach`, `sky`, `butter`, `rose` tints | category card fills (steps = mint, sleep = lavender, mood = butter, stress = sky, etc.) |
| `background`, `surface`, `surfaceMuted` | screen wash, white cards, grey chips |
| `textPrimary`, `textSecondary` | near-black navy, muted grey |
| `success`, `caution`, `emergency` | status; **emergency must stay a clear red**, never a pastel |

Rules:
- Text on any pastel must use a dark shade (WCAG 2.2 AA, 4.5:1 for body text). Add a contrast table to the PR.
- Full dark-mode versions (deep green-navy background, muted pastels, light text).
- Radius tokens (card 24, chip 999, button 16), spacing tokens, soft-shadow token.
- Update the dev-only Design tokens screen.
- Logo: the reference shows a new leaf logo. Keep the current logo until the client approves (`needs-product`).

## PR UI-02b: Illustration and character asset system

The coding agent must **not** copy pixels out of the mockup (it is low resolution). Build the system and placeholders; final art comes from a designer or an approved image tool.

1. Folder `apps/mobile/assets/illustrations/` with a manifest `illustrations.json` (id, file, alt text, light/dark variant, licence/source, status `placeholder | final`).
2. An `Illustration` widget that loads by id, shows alt text for screen readers, and falls back to a soft coloured shape if missing.
3. A `CoachAvatar` widget that draws the user's avatar (from `users/{uid}/avatar/current`) with an **expression** (`happy`, `waving`, `talking`, `listening`, `calm`, `celebrating`) and an optional **speech bubble**. Until real avatar art exists, use placeholders.
4. Write `docs/design/asset-brief.md` listing every asset needed, in one consistent style:
   - **Default avatars (at least 4, diverse):** e.g. young man in green hoodie, woman with long hair, man with glasses, woman with curly hair; plus more skin tones, ages, head coverings and a wheelchair user (FR-AVT-02). Each in all 6 expressions.
   - **Scenes:** Home hero (plants, soft sun), Care hero, Studio background options.
   - **Lesson art:** breathe and reset, reduce stress, better sleep, move your body, mindful eating, deep breathing (lotus), plus one per driver.
   - **Icons:** mood face, energy bolt, sleep moon, stress lotus, streak flame, shoe/steps, water drop, target goal, reflection notebook.
   - **8-driver wheel icons** (one per driver, names from content, see UI-02d).
   - **Empty states:** no data yet, offline, coming soon.
   - **Feature art** (for onboarding tutorial and store screenshots): notifications phone, travel suitcase, reflection notebook, portal laptop, smartwatch.
5. All final art must be original or properly licensed for commercial use, recorded in the manifest. No copyrighted characters.

## PR UI-02c: Home

From top to bottom:
1. Header: "Good morning/afternoon/evening, {first name}!" with a small sun/moon icon, subtitle "Ready for a healthier, happier you?", search, bell (with dot if unread), profile picture.
2. **Hero card:** `CoachAvatar` waving on a leafy background with a speech bubble greeting (from approved templates), and the **Your Morning Briefing** player row (play button, duration, waveform) at the bottom. Hide the player if no briefing exists (flag); show a gentle line instead.
3. **Today's Next Step:** green card with illustration, title ("Take a 10 min walk"), short line ("Move a little, feel better!"), tap opens the step with **Done** and **Make it smaller**.
4. **Quick Check-in:** 4 tiles (Mood, Energy, Sleep, Stress) with icons. Tapping any tile opens the mood-first check-in from T-DLY-02. After check-in, tiles show today's answers.
5. **Streak card:** flame, "N Day Streak", "Keep going!", plant decoration.

Spec corrections:
- Real data only in staging/prod; sample data only in the dev flavour.
- FR-DLY-03: one primary action (the step). List the action count in the PR.
- On a `gentle_day`, the speech bubble and step use gentle templates.
- Streak uses grace and restart wording; never a red/alarm look for missed days.

## PR UI-02d: Plan

1. Header "Plan" + calendar button.
2. **Your Live Well Map:** colourful 8-segment wheel with icon + label per driver, "Live Well" in the centre; tap a segment to see that driver. Segment fill = 30-day completion (FR-GAM-02).
   - **Spec correction:** the driver names in the mockup (Mind & Mood, Sleep & Restore, Move & Fitness, Nutrition, Purpose & Growth, Relationships, Environment, Financial Wellness) are samples. Load the **8 drivers from Dr. Gokula's content files** and use their exact names and order (`needs-product` if the content file is missing).
   - Before the assessment is taken, show the wheel in soft grey with "Take your 10-minute check to fill your map."
3. **Your 30-Day Goal:** target icon, goal title, Edit, progress bar with "Day X of 30" and %.
4. **Daily Microhabits:** checklist rows with round checkboxes and a "…" menu. Max 1 daily microhabit + 2 supporting habits (FR-GOL-01).
5. MY GOAL DO IT tabs from the prototype stay reachable (FR-GOL-06), e.g. a "MY GOAL DO IT" row at the bottom.

## PR UI-02e: Track

1. Header "Track" + period dropdown (This Week / This Month / 90 days).
2. **2×2 metric cards** with mini bar charts: Steps (of goal), Sleep (hours + label), Mood (average /5 + word), Stress (average /5 + word). Each card has its pastel tint and icon.
   - Steps and sleep hours only with Apple Health / Health Connect consent; otherwise show the check-in rating or a "Connect Health" prompt.
   - Words must be kind and plain ("Good", "Positive", "Low"), never clinical or alarming.
3. **Progress:** chips (Steps, Sleep, Mood, Habits) and a bar chart Mon–Sun with the selected day highlighted and a value bubble. Charts colour-safe and screen-reader labelled (FR-GOL-05).
4. **Weekly Reflection** card: "How was your week?" → opens the weekly review/reflection.

## PR UI-02f: Learn

1. Header "Learn" + search.
2. Filter chips: All, Lessons, Audio, Programs. "Programs" shows portal courses.
3. **Pick up where you left off:** wide card with illustration, title, type and length, play button.
4. **Featured Lessons:** 2-column grid of illustrated cards (title, subtitle, minutes).
5. **Popular Audio Sessions:** list rows with illustration and play button (offline after download, FR-LRN-03).

Spec corrections:
- Only **approved** content appears (`review_status = approved`); empty state otherwise.
- Portal items carry the "From the Live Well Portal" label and price/"Paid course"; follow all portal rules (§13.3–13.4): consent, caps, no portal items on a `gentle_day` or within 72 h of a safety event. Behind the portal flag.

## PR UI-02g: Care

1. Header "Care" + history button.
2. Tabs: Chat, Voice, Saved, Safety.
3. **Hero:** `CoachAvatar` (listening/happy) with speech bubble "I'm here for you. What would you like to talk about today?"
4. **Quick prompt chips:** "I feel stressed", "I need motivation", "Help me sleep better", "Plan my day".
5. **Tap to speak:** big green mic button with animated waveform; **Type a message** field with send button (text always available, FR-CNV-07).
6. **Helpful resources:** cards with source ("From Live Well Book, Chapter 3") and open icon.
7. **Safety tab:** emergency and crisis resources (region-aware, from PR #13), "Talk to a clinician" info, "Get help now".

Spec corrections:
- The AI coach is not built yet: chips and messages show a friendly "Your coach is coming soon" reply in staging/prod. No fake answers.
- Everything typed or spoken still goes through the red-flag safety rules first. Safety replies use the neutral system voice and the calm expression.
- Show the "AI voice" label on first playback (FR-VOC-08) and the line "Educational companion. Does not prescribe or change medication."
- Mic needs microphone consent; waveform respects reduced motion.

## PR UI-02h: Avatar & Voice Studio

Used both in onboarding (T-ONB-03b/c) and from Profile.

1. Header with back arrow: "Avatar & Voice Studio". Tabs: Avatar, Voice, Background.
2. **Avatar tab:** large preview of the avatar on its background with left/right arrows and page dots; row of avatar thumbnails to pick (default characters from UI-02b); "Customize" opens the cartoon creator; "Use my selfie" per T-ONB-03b.
3. **Voice tab / Choose Your Voice list:** each row with icon, name, status pill and radio button:
   - library voices (e.g. "Calm & Friendly", "Energetic") with preview;
   - "My Voice (Cloned)" and "Add a Loved One's Voice" **only when the clone flag is on**; otherwise "Coming soon";
   - "Dr. Gokula (Licensed)" **only when the Dr. Gokula flag is on** (licence signed), always labelled as AI voice.
4. **Voice Consent banner** (green, shield-check): "Voice consent active. You can delete your voice data anytime from settings." Show only when a cloned voice with valid consent exists.
5. **Background tab:** choose avatar backgrounds (some unlockable by streaks, FR-GAM-03).

Spec corrections: cloning must follow spec §7.4 exactly when built; previews use only approved text (closed-script rule FR-VOC-05).

## PR UI-02i: Shared components, onboarding and polish

- Shared widgets: `PastelCard`, `MetricCard`, `PillChips`, `SectionHeader` ("Title" + "See all >"), `AudioRow`, `LessonCard`, `SpeechBubble`, `StreakCard`, `CheckinTile`, `WaveformPlayer`.
- Restyle onboarding (welcome, legal, sign-in with Google/Apple icons, Why, check-in, 7-day plan) in the same illustrated style, using the feature art from UI-02b for the 3–4 tutorial screens (Smart notifications, Travel mode, Weekly reflection, Portal courses, Works on your watch).
- Notifications screen (bell): list of today's reminders in the same style.
- Micro-animations: avatar gentle bounce on greeting, check-in tile tap, streak flame flicker, celebration on Done. All respect reduced motion.

---

## Tests (every PR)

- Golden tests: light + dark, normal + large text, small (iPhone SE size) + large phones.
- Widget tests for each state: empty, with data, gentle day, flag off/on, safety block where relevant.
- Accessibility: labels for every icon and illustration, 44 pt tap targets, contrast.
- No sample data in prod builds (test).

## Done when

- All 9 PRs pass tests.
- Each PR has side-by-side screenshots: design reference vs app (light and dark).
- `docs/design/asset-brief.md` and `illustrations.json` exist, with every asset marked `placeholder` or `final`.
- Open `needs-product` questions listed in the UI-02a PR description (logo, font, driver names, art source).

## Out of scope

- Creating final illustration artwork (designer or approved image tool).
- AI coach backend, real voice cloning, photo-realistic avatars, Health import, portal backend.
