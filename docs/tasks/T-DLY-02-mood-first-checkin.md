# T-DLY-02: Daily check-in with mood first

| Field | Value |
|---|---|
| ID | T-DLY-02 |
| Title | Daily check-in with mood as the first question |
| Branch | `task/T-DLY-02-mood-first-checkin` |
| Depends on | T-FND-04 follow-up (hide dev UI) |
| Tag | **needs human review (safety)** |
| Spec refs | FR-DLY-02, FR-DLY-03, FR-SAF-01/02, §15.3 ("portal during distress"), NFR-06, NFR-10 |

Read `AGENTS.md` and the Live Well v2 spec before starting. Follow the working agreement in spec §17.1. Do not weaken any existing safety rule, consent check or frequency cap.

## Goal

The first time the user opens the app each day (in their local time zone), ask how they feel before anything else.

## Flow

Bottom sheet, one question per step, with progress dots.

1. **Mood** (required): "Hi {first name}, how are you feeling today?"
   Five options with faces **and** text labels (screen-reader friendly):
   1 Very low · 2 Low · 3 Okay · 4 Good · 5 Great
2. **Energy** (1–5), skippable
3. **Sleep last night** (1–5), skippable
4. **Stress** (1–5), skippable
5. **"How much time do you have today?"** 2 / 5 / 10 / 30 minutes, skippable
6. **"Anything that could make today hard?"** Optional short text, with voice dictation if the microphone consent is granted (reuse the dictation from the Why screen, PR #12).

Rules:

- A "Skip for now" option is always visible after the mood step.
- Target: the whole flow takes **under 30 seconds**.
- Ask **once per day only**. If the user closes the sheet, do not ask again today; show a small "Check in" card on Home instead.

## Saving

- Path: `users/{uid}/checkins/{yyyy-mm-dd}`
- Fields: `mood`, `energy`, `sleep`, `stress`, `time_available`, `barrier_text`, `source` (`"app"`), `gentle_day`, `created_at`, `updated_at`, `schema_version`
- Idempotent by date: re-submitting the same day updates the record and never duplicates it.
- Must work offline and sync later. If the encrypted local DB (T-FND-08) is not built yet, use Firestore offline persistence and add a TODO linking T-FND-08.
- Update Firestore security rules so users can only read and write their own check-ins, and add emulator tests.

## Safety

- Run `barrier_text` through the existing red-flag rules engine from PR #13 **before** showing any response. If a red flag fires, show the existing emergency or crisis card immediately (region-aware, as today).
- If `mood <= 2` OR `stress >= 4`: set `gentle_day: true` on today's check-in. This blocks any portal card for the rest of the day (spec §15.3) and switches Home to the gentle message.

## Home after check-in

This replaces the "Your day starts here" empty state.

- A short supportive line based on mood, taken from a fixed, reviewed template list in `/content/copy/checkin_responses.md` (no AI yet). Examples:
  - mood 4–5: "Love that energy. Let's use it well today."
  - mood 3: "Thanks for checking in. One small step is plenty today."
  - mood 1–2: "Thanks for telling me. Let's keep today gentle."
- Below it: a placeholder "Today's step" card sized to `time_available` (real next-step logic comes later in T-DLY-01).
- Respect FR-DLY-03: at most 1 primary and 2 secondary actions on Home.
- All copy at about an 8th-grade reading level, kind, never shaming.

## Privacy

- Never send mood, energy, sleep, stress values or `barrier_text` to analytics, Crashlytics or logs.
- Log only the event `checkin_completed` with `{surface: "app", duration_s, steps_answered}`.
- Nothing from the check-in appears in notifications or on the lock screen.

## Accessibility

- Faces always have text labels.
- Tap targets of 44 pt or more.
- Works with large text, screen readers and dark mode.

## Tests

- **Unit:** once-per-day logic across time zones and midnight; `gentle_day` rule.
- **Widget:** each step, skip behaviour, dark mode, large text.
- **Integration:** offline submit, then reconnect, syncs exactly once.
- **Safety:** crisis and emergency phrases in `barrier_text` (English and the Hindi phrases from PR #13) show the correct card.
- **Security rules:** emulator tests for `checkins`.

## Done when

- All tests pass.
- The PR description includes:
  - screenshots of each step, and of Home for mood 1, 3 and 5;
  - a short screen recording of the full check-in completed in under 30 seconds;
  - a "needs human review" note for the safety wording and the mood response copy.

If anything is unclear, choose the most conservative option and open a `needs-product` question in the PR instead of guessing.

## Out of scope

- AI-generated responses (Coach Agent, T-AGT-04).
- Real next-best-step logic (T-DLY-01).
- Widget and watch check-in (T-TCH-02 to T-TCH-05).
