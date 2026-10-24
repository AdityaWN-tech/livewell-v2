# T-TCH-02 / T-TCH-03: "Today's routine" home-screen widgets (iOS + Android)

| Field | Value |
|---|---|
| ID | T-TCH-02 (iOS) and T-TCH-03 (Android), split into PRs TCH-a to TCH-e below |
| Depends on | T-DLY-02 (check-in), T-ONB-03e (7-day plan), T-UI-02a (theme), T-FND-08 or offline queue |
| Tag | needs human review (privacy on lock screen) |
| Spec refs | FR-TCH-01..04, FR-DLY-01..07, FR-AVT-04/05, NFR-05, NFR-08, NFR-10, §9.7 |

Read `AGENTS.md` and the Live Well v2 spec first. **One PR per section, stacked in order.** Never show health values or mood on the widget, and never weaken a safety rule or cap.

---

## What the widget does

The widget is the user's **daily routine on the home screen**. It changes through the day and always recommends **one thing to do now**, with a one-tap action.

| Time of day (user's plan times) | Widget shows | Main tap |
|---|---|---|
| Morning, before check-in | Avatar waving, "Good morning, {first name}", "Start with a 30-second check-in" | Opens the mood check-in |
| Morning, after check-in | Today's step, e.g. "10-min walk after lunch" + "Make it 5 min" | Open step |
| Step window (e.g. after lunch) | "Time for your 10-min walk" | **Done** (logs without opening the app) |
| Step done | Avatar celebrating, "Nice work! Day {N} streak" | Open Home |
| Evening | "How did today go?" | Opens evening reflection |
| Gentle day | Calm avatar, smaller step, gentle wording | Same as above |
| No plan / signed out | "Open Live Well to start your plan" | Open app |

Rules:
- **One recommendation at a time**, matching the Home "one next step" rule (FR-DLY-03).
- Wording comes from the same approved templates as the app (`/content/plan/templates`, `/content/copy`). No AI-generated text yet.
- No portal or course suggestions on the widget, ever.

---

## PR TCH-a: Shared widget data

- Use the `home_widget` Flutter package (or equivalent) to share a small **widget snapshot** with the native widgets (iOS App Group, Android shared storage).
- Snapshot fields: `first_name`, `avatar_thumb_path` (per expression), `expression`, `current_slot` (morning_checkin | step | step_window | done | evening | gentle | none), `headline`, `subline`, `primary_action` (id + label), `secondary_action` (optional), `streak_days`, `routine` (3 items: morning, step, evening, each `todo | done | skipped`), `updated_at`.
- **Never** include mood, energy, sleep, stress values, health metrics or free text in the snapshot.
- Write the snapshot whenever: the plan changes, check-in is saved, a habit is logged, the reflection is saved, the avatar or name changes, theme changes, and at midnight.
- Pre-compute the **timeline** for the rest of the day (entries at each touchpoint time) so the widget updates on time without the app running.
- Tests: snapshot built correctly for every slot; no sensitive fields (test fails if any are added).

## PR TCH-b: iOS widgets (WidgetKit, SwiftUI)

Sizes:
- **Small:** avatar face (expression), headline (2 lines max), one action button (Done / Check in / Reflect).
- **Medium:** avatar + headline + subline, primary button, "Make it smaller" when relevant, streak chip, and a **routine row** of 3 dots: Morning · Step · Evening (done = filled, to-do = outline, never red).
- **Large (Could):** greeting, the 3 routine items as a checklist with times, today's thought, streak.
- **Lock screen (iOS 16+):** circular = streak flame + days; rectangular = "Next: 10-min walk". Generic wording only.

Behaviour:
- **Interactive Done button** with App Intents (iOS 17+): logs the habit to the offline queue (idempotent by date + habit) and refreshes the widget instantly with the celebration state. On iOS 16, the button opens the app instead.
- Taps deep-link to the right screen (`livewell://checkin`, `livewell://step/{id}`, `livewell://reflection`, `livewell://home`).
- Timeline policy from the snapshot; refresh at least 4 times a day (FR-TCH-04).
- Separate widget bundle IDs and App Groups per flavour (dev, staging, prod).

## PR TCH-c: Android widgets (Jetpack Glance)

- Same small, medium and large layouts as iOS (parity checklist in the PR).
- **Interactive Done** with Glance `ActionCallback` (Android 12+), logged to the offline queue, then widget refresh. On older versions, open the app.
- Updates via WorkManager at touchpoint times + on snapshot change.
- Resizable; respects the launcher's rounded corners and dynamic sizing.

## PR TCH-d: Look and feel

- Follow the illustrated design (T-UI-02): soft pastel card, rounded corners, leafy accent, the user's avatar with expression, primary green button.
- Light and dark versions; text always readable (AA contrast); supports large text by reducing lines, never cutting words.
- Avatar comes from the user's saved avatar (exported as small PNG thumbnails per expression). If missing, show the default character.
- Reduced motion: no animated content.
- Add a "**Add the widget**" card in onboarding (after the 7-day plan) and in Profile > Daily plan, with a short animation/picture showing how to add it on iOS and Android.

## PR TCH-e: Privacy, settings and analytics

- Profile > Daily plan > Widget: **"Hide details on lock screen"** (default ON for the lock-screen widget: shows "Your next step is ready" instead of the step name).
- Signing out clears the snapshot and shows the signed-out state.
- Analytics: `widget_interaction` with `{action, size, slot}` only.
- Notifications and widget stay consistent: if a step is marked done in the widget, its reminder notification for that step is cancelled.

---

## Tests

- Unit: slot selection for every time of day, gentle day, done, signed out, time-zone change, midnight rollover.
- Done from widget while **offline** → syncs exactly once later (integration).
- Snapshot privacy test (no sensitive fields).
- iOS snapshot tests for each size, light/dark; Android Glance preview tests.
- Deep links open the right screen.

## Done when

- Small and medium widgets work on iOS and Android, with interactive Done on iOS 17+ and Android 12+.
- The widget changes correctly through a simulated day (morning → step → done → evening), shown in a screen recording on both platforms.
- PR descriptions include screenshots of every size and slot, light and dark.

## Out of scope

- Watch complications (T-TCH-04/05/06), AI-written widget text, briefing audio playback from the widget (add later behind the briefing flag).
