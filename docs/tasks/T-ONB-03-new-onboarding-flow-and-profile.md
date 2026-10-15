# T-ONB-03: Social sign-in icons, new onboarding flow, 7-day starter plan and Profile

| Field | Value |
|---|---|
| ID | T-ONB-03 (split into PRs ONB-03a to ONB-03f below) |
| Depends on | T-FND-04, T-DLY-02, T-UI-01a (new design tokens) |
| Tag | **needs human review** (auth, consent, biometric/voice, safety copy) |
| Spec refs | FR-ONB-01..06, FR-AVT-01/02/05/07, §7.3–7.4, FR-VOC-01/02/05/08, FR-DLY-01..05, FR-TCH-01, FR-GOL-01/03, FR-SET-01..03, §16.3 |

Read `AGENTS.md` and the Live Well v2 spec first. **One PR per section, stacked in order.** Never weaken a safety rule, consent check or frequency cap. If unclear, pick the most conservative option and open a `needs-product` question.

---

## The new user journey (after this task)

```
Splash → What Live Well does → 18+ check → Legal acceptance   (already built, keep)
   ↓
Sign in / Sign up  (phone OTP, email, Google icon, Apple icon)          ONB-03a
   ↓
Create your coach avatar  (default / cartoon / "use my selfie")         ONB-03b
   ↓
Choose your coach's voice (default → OK, library, or my own voice)      ONB-03c
   ↓
Your Why (existing screen from PR #12)
   ↓
Mood check-in (T-DLY-02) → "What would you like to work on?"           ONB-03d
   ↓
Your 7-day starter plan + 3 daily touchpoints                           ONB-03e
   ↓
Home
Profile available any time                                               ONB-03f
```

- Every onboarding step after sign-in is **resumable** (FR-ONB-06): killing the app returns to the same step.
- Avatar and voice steps have **"Skip, use default"** so nobody gets stuck.
- Returning users who already finished onboarding go straight to Home.

---

## PR ONB-03a: Google and Apple icon sign-in

- On the sign-in screen, below the phone/email options, add a row: "or continue with" + **Google icon** and **Apple icon** (round icon buttons, 48 pt, with accessible labels "Continue with Google" / "Continue with Apple").
- Use the **official brand assets** and follow Google's and Apple's button/branding guidelines (logo only is allowed; do not recolour or distort the logos). Light and dark variants.
- One tap = sign in **or** sign up automatically: if no account exists, Firebase creates it; then create the profile and consent records exactly as PR #11 does today.
- Handle `account-exists-with-different-credential` (same email used with another method): show a kind message and offer to link accounts after signing in with the original method.
- Apple sign-in: native on iOS; on Android use Firebase's web OAuth flow. Apple may hide the email (private relay): accept it.
- iOS App Store rule: because Google sign-in is offered, Sign in with Apple must be offered on iOS. Keep it.
- Remove the old large "Sign in with Google" button.
- Tests: widget tests for both icons (labels, tap targets, light/dark); integration tests with the Auth emulator for new user (sign-up path) and existing user (sign-in path); cancelled sign-in returns to the screen with no error.

## PR ONB-03b: Avatar step

Screen "Create your coach". Three choices:

1. **Default avatar (fastest):** user picks a starting look: "Woman", "Man" or "Neutral". Never guess gender from the photo or name. Shows the default avatar for that look → **Use this**.
2. **Make a cartoon avatar:** stylized creator (spec FR-AVT-02): skin tone (8+), hairstyle, hair colour, eyes, glasses, head coverings (hijab, turban, kippah), clothing, background. Live preview.
3. **Use my selfie:** take a selfie → the app suggests cartoon features (skin tone, hair, glasses) **on the device**, and the user adjusts them in the creator. The selfie is **not uploaded** in this PR.
   - Needs camera consent + biometric consent (FR-ONB-03) with plain-language text. If declined, go back to options 1–2.
   - Delete the selfie from the device after features are suggested (FR-AVT-07).
   - Photo-realistic avatars (selfie → real-looking video) are **Phase 2** behind a flag; show "Coming soon" there, do not build a vendor pipeline here.

Also:
- Save to `users/{uid}/avatar/current` (`type`, `style_config`, `thumbnail` per expression).
- Renderer: use the stylized renderer if T-AVT-01 exists; otherwise a static illustrated avatar from the config, with TODO linking T-AVT-01.
- Inclusive asset set reviewed by design; reduced-motion respected.
- Tests: each path, consent declined path, resume mid-step, selfie deleted after use.

## PR ONB-03c: Voice step

Screen "Choose your coach's voice".

1. The coach greets the user in the **default voice** with a 5-second preview ("Hi {first name}, I'm your Live Well coach."). Buttons: **Sounds good** (OK) and **Choose another voice**.
2. **Voice library:** at least 6 voices now (12 by launch, FR-VOC-01), with preview, speed 0.8x–1.2x and a calm/energetic style. Voices must be licensed for commercial use; record the source and licence of each voice in `docs/voices.md`.
3. **Use my own voice:** shown only when the voice-clone flag is on; otherwise "Coming soon".
   - When built it must follow spec §7.4 / FR-VOC-02 exactly: voice consent, live reading of a random consent sentence with a code, live in-app recording only (no file upload), speaker match, raw audio deleted within 7 days.
   - Do not implement cloning in this PR; build the entry point and the flag only.
- Always show the **"AI voice"** label (FR-VOC-08).
- Closed-script rule (FR-VOC-05): previews and all speech come only from approved app text, never from user-typed text.
- Save to `users/{uid}/voices/{voice_id}`, one active.
- TTS for previews: use pre-generated, bundled audio files for the default greeting and each library voice (no live TTS needed yet).
- Tests: OK path, choose-another path, flag-off clone path, resume.

## PR ONB-03d: Mood + "What would you like to work on?"

1. Reuse the mood-first check-in from T-DLY-02 (mood, energy, sleep, stress, time available, optional note, red-flag check on the note).
2. New question: **"What would you like to work on this week?"** Pick 1 (optionally a 2nd): Move more · Sleep better · Eat better · Feel less stressed · More energy · Build a healthy routine.
   - Use wording that maps to Dr. Gokula's 8 drivers (map in `/content/plan/focus_to_driver.json`, reviewed by the clinical team — `needs-product` for final mapping).
3. Quick safety screen before movement plans (FR-GOL-03): "Do you have chest pain, fainting, severe breathlessness, or has a clinician limited your activity?" If yes → "talk to your clinician first" guidance and only non-movement habits.
4. Save choices to `users/{uid}` (`focus_driver`, `focus_choices`) and today's check-in.

## PR ONB-03e: 7-day starter plan with 3 daily touchpoints

Rule-based for now (no AI): built from **approved template files** in `/content/plan/templates/*.json`, one set per focus choice and time size (2, 5, 10, 30 min). The Coach Agent (T-AGT-04) replaces this later.

Each day has:
- **1 main step** sized to the user's time + a "make it smaller" option (FR-DLY-03).
- Up to **2 supporting habits** total across the plan (FR-GOL-01).
- **3 touchpoints a day** (user can change times; defaults shown):
  1. **Morning greeting** 7:00: hello by name, their Why, today's step, one affirmation (spec Appendix C style, text + audio in their chosen voice when available).
  2. **Midday nudge** 13:00: tied to the habit anchor, e.g. "After lunch: your 10-minute walk."
  3. **Evening reflection** 20:30: "What went well? What got in the way?"
- A "Your 7 days" preview screen after onboarding: day cards (Day 1 … Day 7) with the step and touchpoint times, and **Start my plan**.
- Day 7 evening: a short weekly review and an offer to continue with a new 7 days (adjusted: step up if done 5+/7, step down if under 2/7, user must accept — FR-DLY-08).

Rules:
- Ask for notification permission here, with a clear reason. If declined, the plan still works in-app.
- Respect notification consent, quiet hours, the global cap (4/day) and nudge cap (3/day) (FR-DLY-04, FR-TCH-01).
- Notification text must not contain health values or the mood (no PHI on lock screen).
- If today is a `gentle_day`, use the gentle template and the smaller step.
- Missed days use streak grace and "restart" wording, never shaming (FR-DLY-07).
- Beginner/moderate activities only; no weight-loss, calorie or fasting content.
- All template text at about an 8th-grade level, in `/content/plan/templates`, marked `review_status: pending` until the clinical team approves; only approved templates are used in prod (dev may use pending).
- Save to `users/{uid}/daily_plans/{date}` for 7 dates and schedule local notifications.
- Tests: plan generation per focus and time size; caps and quiet hours; gentle day; time zone change; reschedule when the user edits times.

## PR ONB-03f: Profile

**Placement (`needs-product`, default = Option A):**
- **Option A (recommended):** the user's profile picture as a round button at the **top-right** of every tab header (replaces the settings gear). Keeps the 5-tab bar from the spec and the new design.
- **Option B:** a 6th tab "Profile" at the bottom right of the tab bar. Only do this if the product owner confirms.

Profile screen sections:
- **Header:** profile picture, name, email/phone, linked sign-in methods.
- **Account:** change profile picture (camera or gallery, cropped, stored in Cloud Storage with signed URLs; this is separate from the coach avatar), edit name, link/unlink Google/Apple/phone, **Log out**, **Switch account** (log out → sign-in screen).
- **My coach:** change avatar (opens ONB-03b creator), change voice (opens ONB-03c), coach name.
- **Appearance:** Light / Dark / System theme (saved per user, applies instantly), text size shortcut.
- **Daily plan:** touchpoint times, quiet hours, notification categories.
- **Privacy & data:** consents screen (PR #8), "What my coach remembers" (placeholder), export data, **Delete avatar**, **Delete voice**, **Delete account** (Apple requires in-app account deletion; follow FR-SET-02/03 and §16.3).
- **Help & about:** safety resources ("Get help now"), terms, privacy, version.
- **Developer** (dev flavour only, per AGENTS.md): Design tokens etc.

Rules:
- Log out clears local cached personal data and the encrypted DB key, cancels scheduled notifications, and returns to sign-in.
- Delete actions need confirmation and write audit log entries.
- Tests: theme switch persists after restart; log out clears data and notifications; profile picture upload and replace; delete account flow (emulator).

---

## Done when

- All 6 PRs pass unit, widget and integration tests (Auth/Firestore emulators).
- Each PR has screenshots (light + dark) and a short screen recording of the new flow end to end: fresh install → sign in with Google → default avatar → default voice OK → mood → focus → 7-day plan → Home → Profile → dark mode → log out.
- Open `needs-product` questions listed in the ONB-03a PR description.

## Out of scope

- Photo-realistic avatar vendor pipeline, live voice cloning, AI-generated coaching (later tasks: T-AVT-03, T-VOC-03..06, T-AGT-04).
