# T-DLY-03: The avatar leads the daily routine ("Avatar Moments")

| Field | Value |
|---|---|
| ID | T-DLY-03 (split into PRs DLY-03a to DLY-03e below) |
| Depends on | T-DLY-02 (check-in), T-ONB-03e (7-day plan), T-UI-02h (avatar maker + CoachAvatar), T-TCH-02 (widget, optional) |
| Tag | needs human review (safety copy, voice, notifications) |
| Spec refs | FR-DLY-01..07, FR-TCH-01/02, FR-AVT-04/05/06, FR-VOC-05/07/08, FR-GOL-03, §8.1, Appendix C |

Read `AGENTS.md` and the spec first. **One PR per section, stacked in order.** Never weaken a safety rule, consent check, cap or the closed-script rule.

---

## Goal

Every touchpoint of the day is delivered **by the user's avatar, in the user's chosen voice**. The avatar greets the user by name, reminds them of their Why, and invites them to do the next step of their routine.

| Moment | When (user-set) | Avatar says (example) | Expression | Action |
|---|---|---|---|---|
| Morning briefing | 7:00 | "Good morning, Priya! Hope you slept well. Remember your why: energy to travel with your family. Today's step: a 10-minute walk after lunch. Short on time? Five minutes still counts. How are you feeling today?" | waving → happy | Check-in, then Start / Make it smaller |
| Step reminder | habit anchor, e.g. 13:00 | "Hi Priya, lunch done? It's a great time for your 10-minute walk. Shall we go?" | encouraging | Start timer / Done / Make it 5 min / Not today |
| Step done | on Done | "You did it! That's day 9. I'm proud of you." | celebrating | Close |
| Evening reflection | 20:30 | "Hi Priya, how did today go? What went well, and what got in the way?" | listening | Voice or text reply |
| Gentle day | after low mood or high stress | "Thanks for telling me how you feel. Let's keep today gentle: two minutes of slow breathing is enough." | calm | Start breathing |
| Missed day | next morning | "Good morning, Priya. Yesterday was a rest day, and that's okay. Let's restart with a small step." | encouraging | Restart |
| Weekly review | Sunday 08:00 | "This week you completed 5 walks. Great work! Next week, let's try ..." | happy | See week |

Tone rules: invitations, never orders or guilt ("Shall we...?", "Want to...?", never "You must" or "You failed"). About 8th-grade reading level. One step only, plus a smaller option.

---

## PR DLY-03a: Script templates and builder

- Template files in `/content/coach/moments/{moment}.json`, each with several variants so the avatar doesn't repeat itself (rotate, never the same variant two days in a row).
- Placeholders only from safe data: `{first_name}`, `{why}`, `{step_title}`, `{step_minutes}`, `{smaller_minutes}`, `{streak_days}`, `{time_of_day}`, `{weekly_count}`.
- Every template has `review_status` (pending | approved). Prod uses **approved only**; dev may use pending.
- Script builder picks the moment, variant and expression from today's plan, check-in and streak, and outputs a `CoachMessage` (spec §9.5) with `message_id`, `text`, `emotion`, `primary_action`, `secondary_actions`.
- Safety:
  - Activity suggestions come only from the user's plan (beginner/moderate, FR-GOL-03). The avatar never suggests running or intense exercise unless that is the user's approved plan.
  - Safety, crisis and medical-boundary messages are **never** delivered as an Avatar Moment; they use the existing safety cards and the neutral system voice (FR-VOC-07).
  - No portal or course mentions in morning, reminder or gentle moments.
- Tests: each moment/variant renders, no missing placeholders, gentle and missed-day logic, safety blocks.

## PR DLY-03b: Avatar Moment player (full screen)

- A full-screen "Avatar Moment" screen in the illustrated style: the user's avatar large in the centre on its background, a speech bubble with the text appearing in sync, captions always available (NFR-06), and the action buttons at the bottom.
- **Voice:** speaks the script in the user's selected voice.
  - Until real voices exist, use the device's built-in text-to-speech (e.g. `flutter_tts`), choosing a calm system voice and the user's speed setting.
  - Later, swap to the voice adapter (T-VOC-01) without changing this screen.
  - The TTS request must carry the `message_id` (closed-script rule FR-VOC-05).
  - Show the "AI voice" label on the first playback each session (FR-VOC-08).
- **Lip movement:** use the avatar's mouth layers; drive open/closed mouth from audio amplitude or word timing. Eyes blink every few seconds.
- **Expressions:** follow the `emotion` tag (waving, happy, encouraging, calm, listening, celebrating).
- Controls: pause/replay, mute (text only), skip. Respect the phone's silent mode for notification sounds and the reduced-motion setting (still avatar + captions).
- Fallback chain (FR-AVT-05): voice + animated avatar → still avatar + voice → text only.
- Tests: plays, pauses, mute, captions, reduced motion, fallback when TTS fails.

## PR DLY-03c: Notifications that open the avatar

Phones do not let an app pop up and talk by itself. So each moment starts with a **notification from the avatar**, and tapping it opens the Avatar Moment.

- Notification shows the avatar's face (expression thumbnail) and a short line in the coach's voice, e.g. "Good morning, Priya ☀️ Your coach has a message for you."
- Tap → opens the Avatar Moment player, which starts speaking.
- Lock-screen text stays general: never mood, health values or the reflection (FR-TCH-02).
- Optional setting "Play my coach's voice in the notification" (default OFF): uses a short pre-generated greeting audio as the notification sound (iOS custom sounds under 30 s; Android notification channel sound). Respect silent mode and Do Not Disturb.
- Respect notification consent, categories, quiet hours, the daily cap of 4 and the nudge cap of 3 (FR-DLY-04, FR-TCH-01).
- If the user opens the app in the morning before tapping, Home shows the morning moment at the top as a card "Your coach has a message" → plays.
- Tests: scheduling for each moment, caps, quiet hours, tap opens the right moment, time-zone change.

## PR DLY-03d: Avatar on Home, widget and celebrations

- **Home hero:** the avatar shows the current moment's expression and speech bubble (short version), with a play button for the full message.
- **Widget (if T-TCH-02 exists):** avatar thumbnail with the current expression and the short line.
- **Done celebration:** short avatar celebration (2–3 s) with confetti leaves and a spoken "You did it!" (skippable, silent if muted).
- **Check-in reaction:** after the mood check-in, the avatar reacts with a matching expression and one sentence.

## PR DLY-03e: Settings

Profile > Daily plan:
- Times for morning, step reminder and evening (with "Not today" and quiet hours).
- "Coach speaks automatically when I open a moment" (ON) / "Show text only" (OFF).
- Voice speed (0.8x–1.2x), captions always on.
- Preview button: plays tomorrow's morning message now.

---

## Done when

- A simulated day works end to end on a test phone: morning notification → avatar speaks greeting with name and Why → check-in → step reminder → Done celebration → evening reflection, shown in a screen recording.
- Gentle day and missed-day versions shown in the recording too.
- All templates are listed in one file for clinical review (`/content/coach/moments/REVIEW.md`).

## Out of scope

- AI-written scripts (Coach Agent, T-AGT-04), cloned voices and Dr. Gokula's voice (T-VOC tasks), photo-realistic video briefings (Phase 2).
