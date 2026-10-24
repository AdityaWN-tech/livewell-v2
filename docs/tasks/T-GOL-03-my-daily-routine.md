# T-GOL-03: "My Daily Routine", customized by the user for every day

| Field | Value |
|---|---|
| ID | T-GOL-03 (split into PRs GOL-03a to GOL-03e below) |
| Depends on | T-ONB-03e (7-day plan), T-DLY-03 (Avatar Moments), T-UI-02d (Plan design) |
| Works with | T-TCH-02 (widget) |
| Tag | needs human review (safety, notifications, voice rule) |
| Spec refs | FR-GOL-01/03, FR-DLY-03/04/07/09, FR-TCH-01/02, FR-SAF-04, FR-VOC-05, §4.1 |

Read `AGENTS.md` and the spec first. **One PR per section, stacked in order.** Never weaken a safety rule, cap or the closed-script rule.

---

## Goal

Besides the coach's plan, every user can build **their own routine for each day of the week** (wake up, water, walk, breathing, family time, bedtime…), with times and reminders. The avatar announces each routine item through the day.

Two kinds of items, shown together on one timeline:

| Kind | Who creates it | Limits | Counts for streak |
|---|---|---|---|
| **Coach steps** | The plan (7-day plan / coach) | 1 daily microhabit + up to 2 supporting habits (FR-GOL-01) | Yes |
| **My routine items** | The user | Up to 12 per day | No (shown as "healthy actions" in Track) |

Coach steps are pinned on the timeline with a "From your coach" label. The user can move their time, but deleting one goes through the plan ("Pause this habit").

---

## PR GOL-03a: Data model and activity catalog

- `users/{uid}/routines/{routine_id}`: `name`, `days` (Mon–Sun), `items[]`, `active`, `schema_version`.
- Item fields: `item_id`, `catalog_id` or `custom`, `label`, `icon`, `time`, `duration_min`, `days` (override), `reminder` (bool), `avatar_announce` (bool), `order`.
- `users/{uid}/routine_logs/{date_itemId}`: `status` (done | skipped), `source` (app | widget | notification), idempotent for offline.
- **Activity catalog** `/content/routine/catalog.json` (approved list, each with icon, default duration, spoken name and avatar line templates), e.g.: Wake up, Drink water, Morning stretch, Morning walk, Breathing break, Healthy breakfast, Work break, Walk after a meal, Family time, Read, Prayer or quiet time, Screen off, Sleep wind-down, Bedtime.
- Movement items stay beginner/moderate. If the user answered "yes" to the activity safety question (FR-GOL-03), movement items show "Check with your clinician first" and are off by default.
- **Not allowed in v2:** fasting, calorie targets, weight-loss items, medication or supplement items (`needs-product` if requested later).
- Security rules + emulator tests for both collections.

## PR GOL-03b: "My Routine" screen (Plan tab)

Illustrated style (T-UI-02):
- Day tabs **Mon–Sun** (today selected) and a **timeline** of items: time, icon, label, duration, check circle, "…" menu.
- **+ Add to my routine** → pick from the catalog (grid with icons) or **Custom** (label up to 40 characters + icon + time + duration).
- Edit item: time, duration, which days it repeats, reminder on/off, "Coach announces it" on/off.
- **Copy this day to…** other days; drag to reorder; **Skip today**; delete with undo.
- **Quick-start templates:** Morning starter, Workday, Weekend, Travel day. The user picks one and edits it.
- Conflicting times show a gentle hint ("Two things at 7:00. Want to move one?").
- Life-event modes (FR-DLY-09): Travel / Sick day / Busy week shrink or pause the routine without breaking streaks.
- Empty state: "Build your day, one small step at a time" with a template picker.
- Works at text sizes 1.0, 1.3, 2.0 and on small phones.

## PR GOL-03c: Safety for custom items

- Every custom label goes through the existing **red-flag rules** (PR #13) before saving. If a red flag fires, show the right safety card and don't save the label.
- Disordered-eating patterns (FR-SAF-04), e.g. "skip dinner", "eat 500 calories": kind message, not saved, `ed_safe_mode` logic applies.
- Banned content uses the Blueprint banned-phrase list.

## PR GOL-03d: Reminders and the avatar

- Each item with a reminder becomes an **Avatar Moment** (T-DLY-03): avatar notification → tap → the avatar speaks.
- **What the avatar says:**
  - Catalog items: approved lines from the catalog, e.g. "Good morning, {first_name}! Time to wake up and drink a glass of water." / "It's 9:30, time for a little stretch."
  - **Custom items:** the custom label is shown **as text only**. The avatar speaks a general line ("Hi {first_name}, it's time for your next routine step"). Reason: the spec's closed-script rule (FR-VOC-05) forbids speaking user-typed text in the coach's voice.
- **Notification limits:** routine reminders are their own category with a user setting **"Routine reminders per day"** (default 6, maximum 10, `needs-product` to confirm). Coach reminders keep their own caps (FR-DLY-04, FR-TCH-01). Quiet hours always apply.
- Items within 15 minutes of each other are **bundled** into one notification ("Two things now: water and stretch").
- If the user ignores an item's reminder 5 days in a row, the avatar asks once: "Want to move or pause this one?"
- Marking an item done cancels its pending reminder.

## PR GOL-03e: Home, widget and Track

- **Home:** "Next in your routine" row under Today's step (secondary, so Home still has one primary action, FR-DLY-03).
- **Widget (T-TCH-02):** add slot `routine_item` with the next item and a Done button; no custom label on the lock screen when "Hide details" is on.
- **Track:** "Routine" chip showing items done per day as pastel bars (never red for missed days). Done routine items add to "Weekly healthy actions" (the North Star).
- **Weekly review:** the avatar mentions one routine win ("You drank water every morning this week!").

---

## Tests

- Unit: day/time logic, copy to days, templates, bundling, caps, quiet hours, time-zone change, modes.
- Widget: timeline, add/edit/delete/undo, large text, dark mode.
- Safety: red-flag and disordered-eating labels blocked.
- Voice: custom labels are never sent to TTS (test fails if they are).
- Integration: done offline from notification/widget syncs once.

## Done when

- A user can build a different routine for weekdays and weekends, get avatar reminders through the day, and mark items done from the app, notification and widget, shown in a screen recording.
- Catalog lines listed in `/content/routine/REVIEW.md` for clinical review.
