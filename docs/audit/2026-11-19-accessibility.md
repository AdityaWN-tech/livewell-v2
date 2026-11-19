# T-REL-01: accessibility audit (WCAG 2.2 AA), 2026-11-19

Spec: T-REL-01 "Accessibility audit (WCAG 2.2 AA) and fixes". **Done when: "Audit report with no AA blockers."** Requirements audited: NFR-06 (WCAG 2.2 AA: dynamic type, screen-reader labels, captions or transcripts for all avatar speech, high contrast, reduced motion, tap targets of 44 pt or more, colour-safe charts), FR-AVT-06 (reduced motion: still avatar and captions), FR-SET-01 (text size, high contrast, captions always-on), spec 4.1 (one primary action), spec 14.1 (feel).

Code: branch `task/T-REL-01-accessibility` off `main` at `1cd51c3`. Paths are under `apps/mobile/`.

**Be clear about what this is.** This is an automated audit plus a code read. It proves what Flutter's test tools can measure. It is **not** a full manual audit: nobody has used the app with VoiceOver or TalkBack on a real phone yet. The checks only a person can do are listed at the end, with a short script for the owner.

## Result

- **No WCAG 2.2 AA blockers remain that the automated checks or the code read can find.** 11 issues were found and fixed (below), each locked in by a test.
- 3 gaps are recorded that are not AA blockers (D-89): no in-app high-contrast setting, no "captions always-on" setting (captions are simply always on), and page transitions still animate with reduce motion on.
- The owner's device checks (end of this file) are still open. Until they pass, the release checklist keeps T-REL-01 open for the public launch.

## How it was checked

`test/accessibility/a11y_audit_test.dart` (172 cases, ~45 s) and `test/accessibility/a11y_fixes_test.dart`:

1. **Coverage.** The test reads the prod router and fails if a route is registered that the sweep doesn't open. All 34 prod routes are opened, signed in or out as needed, with real-looking content (the sample lessons). `/splash` is left out on purpose: it shows for a moment and moves on (its reduce-motion path has its own test, `test/splash/splash_test.dart`). Developer routes are checked to be absent in prod.
2. **Light and dark, on a Pixel-size phone, scrolled top to bottom one screen at a time:**
   - `androidTapTargetGuideline` (48 dp) and `iOSTapTargetGuideline` (44 pt);
   - `labeledTapTargetGuideline` (every tap target has a label);
   - `textContrastGuideline` (4.5:1, 3:1 for large text), on the rendered pixels;
   - every tappable node has a role (button, link, switch, checkbox, text field, slider, tab), so it isn't read as just "double tap to activate";
   - at least one heading per screen (screen-reader heading navigation).
3. **Large text on an iPhone SE (the smallest supported screen):** 200% (WCAG 1.4.4), 260% (phone at 200% times the app's own "Largest", 130%) and 310% (iOS's largest accessibility size). Any overflow fails the test, and so does any text cut off by `maxLines` or an ellipsis. See D-89 for why these three sizes.
4. **The safety screens** (crisis in India, crisis in the US, emergency with the region unknown) aren't routes, so they're opened from the Why as a user would, then checked in light and dark and at 200% and 310% text.
5. **Colour tokens**: `test/design/tokens_test.dart` (already there) checks every text/background pair in both palettes for 4.5:1, UI boundaries for 3:1, and that the 7 category tints and the emergency red can be told apart.
6. **Code read** for what tests can't see: images, decorative art, reduced motion, captions, colour-only meaning.

## Screen by screen

Key: **OK** passed; **Fixed** failed and is now fixed (number = the fix below); **n/a** doesn't apply; **Person** needs a person on a device. Tap = 48 dp / 44 pt targets; Labels = labelled tap targets and roles; Contrast = text contrast in light and dark; Head = heading; Text = 200 / 260 / 310% with no overflow or cut-off text.

| Route (prod) | Tap | Labels | Contrast | Head | Text | Notes |
|---|---|---|---|---|---|---|
| `/welcome` | OK | OK | OK | Fixed (9) | OK | Logo has a label (the app name) |
| `/onboarding/about` | OK | OK | OK | OK | OK | |
| `/onboarding/age` | OK | OK | OK | Fixed (9) | Fixed (2) | |
| `/onboarding/under-18` | OK | OK | OK | Fixed (9) | Fixed (1) | |
| `/onboarding/legal` | OK | Fixed (6) | OK | OK | OK | Document links are inline links (exempt from target size, WCAG 2.5.8) |
| `/onboarding/legal/:doc` | OK | OK | OK | OK | OK | |
| `/sign-in` | OK | OK | OK | Fixed (9) | Fixed (3) | Google/Apple logo buttons have labels |
| `/sign-in/phone` | OK | OK | OK | OK | OK | |
| `/sign-in/email` | OK | OK | OK | OK | OK | |
| `/onboarding/avatar` | OK | OK | OK | OK | OK | |
| `/onboarding/voice` | OK | OK | OK | OK | OK | Caption Fixed (10); library Fixed (11) |
| `/onboarding/why` | OK | OK | OK | OK | OK | Safety screens from here: OK (tested separately) |
| `/onboarding/checkin` (check-in sheet) | OK | OK | OK (see note) | OK | OK | Contrast tool false positive on the answer tiles, see below |
| `/onboarding/focus` | OK | OK | OK | OK | OK | |
| `/onboarding/plan` | OK | OK | OK | Fixed (9) | OK | Heading was missing in the "not ready" state |
| `/home` | OK | OK | OK | OK | OK | |
| `/plan` | OK | OK | OK | OK | OK | |
| `/plan/framework` | OK | Fixed (7) | OK | OK | OK | |
| `/plan/routine` | OK | OK | OK | OK | Fixed (4) | |
| `/track` | OK | OK | OK | OK | OK | Chart bars have their own labels (not colour alone) |
| `/track/weekly` | OK | OK | OK | OK | OK | |
| `/learn` | OK | OK | OK | OK | Fixed (5) | |
| `/learn/library` | OK | OK | OK | OK | Fixed (5) | |
| `/learn/search` | OK | OK | OK | OK | OK | |
| `/learn/item/:id` | OK | OK | OK | OK | OK | Coach reading: the lesson text on screen is the transcript |
| `/learn/breathe` | OK | OK | OK | OK | OK | Still circle with reduce motion (existing test) |
| `/care` | OK | OK | OK | OK | OK | |
| `/moment/:name` | OK | OK | OK | n/a | OK | No title by design: the coach and captions. Captions always on; still avatar with reduce motion (existing tests) |
| `/notifications` | OK | OK | OK | OK | OK | |
| `/help` | OK | OK | OK | OK | OK | Safety screen; region known in the test (never guessed) |
| `/profile` | Fixed (8) | Fixed (8) | OK | OK | OK | |
| `/profile/phone` | OK | OK | OK | OK | OK | |
| `/settings` | Fixed (8) | Fixed (8) | OK | OK | OK | Same screen as `/profile` |
| `/settings/consents` | OK | OK | OK | OK | OK | |
| Safety: crisis IN, crisis US, emergency (region unknown) | OK | OK | OK | OK | OK (200%, 310%) | Not routes; opened from the Why |

Every row also needs the person checks at the end (reading order, focus, what is actually spoken).

## Found and fixed (11)

| # | WCAG | Where | Problem | Fix | Locked in by |
|---|---|---|---|---|---|
| 1 | 1.4.4, 1.4.10 | Under-18 screen | Overflowed by 101 px at 200% text (more at 260/310%); the button went off screen | Content scrolls when it doesn't fit, and still fills the screen when it does (`age_gate_screen.dart`) | large-text sweep |
| 2 | 1.4.4, 1.4.10 | Age gate | Overflowed at 260% and 310%; the body text slid under the buttons (contrast 1.03:1 there) | Same as 1 | large-text sweep |
| 3 | 1.4.4 | Sign-in | "or continue with" row overflowed at 310% | The text wraps between the lines (`sign_in_screen.dart`) | large-text sweep |
| 4 | 1.4.4 | My Daily Routine | Title cut off in the app bar from 200% | Title moved into the page (`LwPageTitle`, as on the other screens); the menu stays in the app bar | large-text sweep |
| 5 | 1.4.4 | Learn, Library | Lesson summaries cut to 3 lines at 260%+ | No line limit when text is above 130% (cards are one column then) | large-text sweep |
| 6 | 4.1.2 | Legal | The whole agree row was an extra unlabelled tap target | The row's tap is hidden from screen readers; they use the labelled checkbox and the links | WCAG sweep (labels) |
| 7 | 4.1.2 | MY GOAL DO IT (`/plan/framework`) | 10 rows tappable with no role | Rows are buttons | WCAG sweep (roles) |
| 8 | 2.5.8 (spec: 44 pt), 4.1.2 | Profile > Daily plan | The time ("7:00 AM") was a 24 dp tap target, read only as "7:00 AM", and was merged into the on/off switch, so a screen reader could never reach it to change the time | A 48 dp button labelled "Morning greeting, 7:00 AM. Change the time", and its own labelled switch (a `ListTile` + `Switch` in place of `SwitchListTile`) | `a11y_fixes_test.dart` |
| 9 | 1.3.1, 2.4.6 | Welcome, Age gate, Under-18, Sign-in, Plan preview (not ready) | No heading for screen-reader heading navigation | The title is a heading (no visual change) | WCAG sweep (heading) |
| 10 | 1.2.1, NFR-06 | Voice (onboarding) | The greeting plays two sentences; the caption showed only the first | The second sentence is shown under it | `a11y_fixes_test.dart` |
| 11 | 1.2.1, NFR-06 | Voice library, Studio > Voice | Voice samples played with no transcript | "What you'll hear" shows the sample's words, calm or energetic (text from `docs/voices.md`) | `a11y_fixes_test.dart` |

By type: text size / reflow 5, labels and roles 3 (one also a target size fix), headings 1 (5 screens), captions 2.

All fixes use design tokens only. No safety routing, consent or voice-rule logic was changed. New copy (11, 10 and the label in 8) is in `app_en.arb` and flagged for the client in D-89.

## Checked and fine (code read)

- **Images.** The logo has a label (the app name). The Google button's artwork is hidden and the button is labelled; Apple's is painted inside a labelled button. Illustrations are hidden from screen readers unless they carry meaning (`core/design/illustration/illustration.dart`); the coach avatar has a label where it's shown.
- **Reduced motion (FR-AVT-06).** With the OS reduce-motion setting, the coach is a still picture (`core/design/avatar/avatar_art.dart`), Avatar Moments show the still coach with captions, the celebration has no falling leaves, breathing uses a still circle, the splash fades instead of moving, and `LwMotion` durations become zero. Existing tests cover each.
- **Captions.** Avatar Moments always show their captions (word by word, or all at once with reduce motion). The celebration shows what the coach says. The lesson reader reads the text that's on the screen.
- **Colour alone.** Check-in answers have words under the faces; selected chips and segments are a solid fill (not just a colour change) and screen readers say "selected"; chart bars have their own spoken labels; the emergency red is only on emergency/crisis cards, which also say what they are.
- **Contrast tokens.** All text pairs meet 4.5:1 in light and dark (`test/design/tokens_test.dart`).

## Not blockers, but open (D-89)

- **High contrast setting (FR-SET-01).** There's no in-app high-contrast option and the app doesn't read the phone's "increase contrast". WCAG AA doesn't need one (the normal palette already passes), but the spec lists it as a Must. Product decision.
- **Captions always-on (FR-SET-01).** Captions are always shown; there's no setting because there's nothing to turn on.
- **Page transitions** still use the platform's slide/zoom with reduce motion on. Moving content in the app (the coach, celebration, breathing, splash) is handled; screen-to-screen animation isn't (WCAG 2.3.3 is AAA).
- **Text above 310%** (iOS's largest size plus the app's 130%, about 400%) isn't tested.
- **Contrast tool false positive.** On the check-in sheet's answer tiles, Flutter's contrast check measures the whole tile, so the outline and the face outnumber the label's pixels and it reports about 3.7:1. The label itself is navy on white (about 15:1, token test). The sweep ignores that one case, by name.
- **Sheets and dialogs** other than the check-in sheet and the safety screens are covered by each feature's own tests, not by this sweep.

## Owner checks on a real device (VoiceOver / TalkBack)

These can't be automated. Please do them once on an iPhone (VoiceOver) and once on an Android phone (TalkBack), with the **prod** build, and note pass/fail per step. About 45 minutes each.

**Setup.** iPhone: Settings > Accessibility > VoiceOver on; Settings > Accessibility > Display & Text Size > Larger Text, largest; Settings > Accessibility > Motion > Reduce Motion on. Android: Settings > Accessibility > TalkBack on; Font size and Display size to the largest; Settings > Accessibility > Remove animations on. Swipe right/left moves between items; double-tap activates.

1. **Welcome to sign-in.** Swipe through Welcome, About, Age, Legal and Sign-in. Expected: each screen's title is read first and announced as a heading; every button says what it does; the Legal checkbox reads the full "I agree to …" sentence; each document link opens its document; nothing is read twice; nothing is unreachable.
2. **Age "No".** Choose "I'm under 18". Expected: the friendly stop screen is read in order, and its button is reachable at the largest text (scroll with three fingers / two fingers).
3. **Voice.** On the voice step, the greeting plays and both caption sentences are on screen. Open "Choose another voice", play a voice. Expected: "What you'll hear" text matches what is said, and changes with Calm / Energetic.
4. **Check-in.** Do the first check-in with the screen reader only. Expected: each answer reads its word (e.g. "Good"), the progress is announced, and you can finish or skip without sight.
5. **Home and tabs.** Swipe through Home, then each tab. Expected: the tab bar says which tab is selected; cards read as one sensible item; the order follows the screen top to bottom; the coach picture has a short label and isn't read as "image" with no name.
6. **Safety.** In the Why, type a crisis phrase (for example "I want to kill myself") and save. Expected: focus goes to the crisis card; its title is read first; the call/text buttons read the full number and service (988 / Tele-MANAS 14416 / 112 / 911 by region); "Go back" is reachable. Do not actually call.
7. **Profile > Daily plan.** Expected: each plan time reads like "Morning greeting, 7:00 AM. Change the time" and opens the time picker; the switch next to it reads "Morning greeting, on/off" and toggles on its own.
8. **Largest text.** With the largest text, open every tab, Profile, My Daily Routine and Get help now. Expected: nothing is cut off or overlapping, and every button can be scrolled to.
9. **Reduce motion.** With reduce motion on, open an Avatar Moment from a notification and finish a step (celebration). Expected: the coach is still, captions show, no falling leaves; breathing shows a still circle.
10. **Focus after actions.** After saving, closing a sheet or going back, the screen reader's focus lands somewhere sensible (the new screen's title, or the item that opened the sheet), not at the top of a long page or lost.
11. **Keyboard / switch access (Android, optional).** With a Bluetooth keyboard, Tab through Sign-in and Profile. Expected: a visible focus ring on every control, in a sensible order.

Report anything that fails with the screen, the step and what was spoken; each becomes a fix with a test, like the ones above.
