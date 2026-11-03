# Step 5: spec audit of the touched modules (2026-10-29)

Code at branch `task/T-TRK-step4f-health-connect` (PR #72, after Steps 1–4f and 6). Status is based on the code and tests that were read, not on docs. Paths are under `apps/mobile/` unless shown otherwise.

Status: **Done**, **Partial**, **Not started**, **Blocked** (content, client, counsel, vendor or server).

## Requirements

| ID | Requirement (short) | Status | What's missing | How verified |
|---|---|---|---|---|
| FR-AVT-01 | Choose avatar in onboarding (skippable), change later | Partial | Prod shows only the 8 ready-made coaches; photo and Build my own are flagged off. No test that switching keeps voice/history | `avatar/presentation/avatar_screen.dart`, `core/config/feature_flags.dart`; `test/avatar/avatar_flow_test.dart` |
| FR-AVT-02 | Inclusive options (skin, hair, body, ages, aids) | Partial / Blocked (Media Service) | Options exist (10 skin, 20 hair, 6 body, wheelchair, hearing aid) but Build my own needs `avatarMaker` + deployed Media Service; design-lead review | `content/avatar/options.json`; `test/avatar/avatar_options_test.dart`, `services/media/tests/test_avatar.py` |
| FR-AVT-03 | Photo avatar of own face, liveness | Partial / Blocked (counsel T-CMP-02, Media deploy) | Flag off; no spoof test set | `avatar/domain/liveness.dart`; `test/avatar/from_photo_test.dart` |
| FR-AVT-04 | Expressions from the agent's emotion tag | Partial | Frames and template emotions exist; no Coach Agent emits tags | `moments/domain/coach_message.dart`; `test/avatar/avatar_frames_test.dart` |
| FR-AVT-05 | Fallback chain to text | Done | Not checked on a device offline | `avatar/presentation/coach_avatar.dart`; `avatar_frames_test.dart` |
| FR-AVT-06 | Reduced motion | Done | none | `coach_avatar.dart`; `avatar_frames_test.dart` |
| FR-AVT-07 | Raw selfies deleted unless opted in | Partial / Blocked (Media deploy) | No keep-for-regeneration opt-in, no storage audit, no test | `services/media/src/media/jobs.py`, `audit.py` |
| FR-ONB-01 | Email, Google, Apple; optional biometric unlock | Partial | **No biometric unlock.** Apple not tried on a device. Google + phone confirmed on the owner's phone (D-58) | `auth/data/firebase_auth_service.dart`; `test/auth/*` |
| FR-ONB-03 | Granular, revocable consents; revoke → 16.3 handling ≤ 24 h | Partial | Revoking acts only for health and analytics; server-side handling (camera, biometric, mic, portal, marketing) not built | `consent/…`, `consents_screen.dart`; `test/consent/consent_test.dart`, `track_screen_test.dart` |
| FR-GOL-01 | 1 goal, daily microhabit, ≤ 2 supporting habits, weekly reflection, long-term outcome | Partial | **No long-term outcome target. Today's step Done is in memory only** (`home/application/home_data.dart`), lost on restart | `goals/…`, rules `habits`/`habit_logs`; `test/plan/goal_habits_test.dart` |
| FR-GOL-02 | SMART goal create/edit/pause/restart | Done | none | `goals/presentation/goal_sheets.dart`; `goal_habits_test.dart` |
| FR-GOL-03 | Beginner/moderate only; red flags → clinician | Partial | Screening and "limited" path exist; goal text not FITT-checked (D-53) | `focus/presentation/activity_check_screen.dart`; `test/focus/focus_flow_test.dart` |
| FR-GOL-04 | Manual steps, sleep, weight, BP, glucose, meals + Health import, source + timestamp | Partial | Health import of steps + sleep (D-59, on device). **No manual entry; no weight, BP, glucose, meals; no stored points with source** | `track/data/health_source.dart`; `test/track/health_summary_test.dart`, `track_screen_test.dart` |
| FR-GOL-05 | Charts 7/30/90 days, colour-safe, labelled | Partial | Chart always this week (period changes only averages). **Habits chart and streak always empty in prod** though habit ticks are saved | `track/presentation/track_screen.dart`; `track_screen_test.dart` |
| FR-GOL-06 | MY GOAL DO IT under Plan | Partial / Blocked (prototype code) | Every letter opens a screen; the prototype's own tab features aren't re-housed | `plan/presentation/framework_screen.dart`; `test/plan/plan_screen_test.dart` |
| FR-LRN-01 | 24+ reviewed lessons with a microhabit | Blocked (content) | Reader built (D-57); no lessons | `learn/presentation/lesson_reader_screen.dart`; `test/learn/lesson_reader_test.dart` |
| FR-LRN-02 | Listen with progress, chosen voice | Partial | Phone TTS near the chosen voice (D-49) until T-VOC-01 | same; `lesson_reader_test.dart` |
| FR-LRN-03 | 6+ breathwork/audio sessions, offline | Partial | 3 built-in patterns (clinical review); no recorded audio, player or download | `learn/domain/breathing.dart`; `test/learn/breathing_test.dart` |
| FR-LRN-04 | Portal card per lesson | Partial | Portal card on Learn only, not in the reader | `learn/presentation/learn_screen.dart`; `test/learn/portal_eligibility_test.dart` |
| FR-VOC-01 | 12+ voices, preview, speed 0.8–1.2 | Partial | 6 voices | `voice/domain/voice.dart`; `test/voice/voice_flow_test.dart` |
| FR-VOC-02 | Self voice clone | Not started (vendor) | Flag-gated explainer only | `voice_screen.dart`; `voice_flow_test.dart` |
| FR-VOC-03 | Loved-one clone | Not started (Phase 2) | Flag off; the row still calls the own-voice handler (`studio_widgets.dart`) | no test |
| FR-VOC-04 | Dr. Gokula voice | Blocked (licence) | Flagged | `studio_widgets.dart`; no test |
| FR-VOC-05 | Closed script; API rejects TTS without message_id | Partial | Client refuses empty ids; **no server TTS API yet**, no pen test | `moments/data/coach_speaker.dart`; `voice_flow_test.dart`, `lesson_reader_test.dart` |
| FR-VOC-06 | Watermark cloned audio | Not started | No clones | — |
| FR-VOC-07 | Safety content in a neutral voice | Partial | Safety content is never voiced (safety hold); no test across all categories | `moments/domain/moment_builder.dart` |
| FR-VOC-08 | "AI voice" label; how the voice was made | Partial | Label shown; **no "how this voice was made" text** in voice settings | `voice_screen.dart`; `voice_flow_test.dart` |
| FR-CNV-01/02/05 | Chat/voice with avatar, barge-in, memory | Not started (agent) | Hidden behind `coachChat`/`coachVoice`; Memory hidden (D-56) | `care_screen.dart`; `test/care/care_screen_test.dart` |
| FR-SAF-01 | Emergency card, one-tap call, keyword + classifier | Partial | Keyword rules (critical set 100%) and one-tap calls; classifier is server work | `packages/safety-rules/`; `safety_rules_test.dart`, `care_screen_test.dart` |
| FR-SAF-02 | Crisis message, nothing else | Done (client) | Agent's calm voice delivery waits for the agent | `safety_screens_test.dart` |
| FR-TCH-01 | Push categories, toggles, quiet hours, global cap 4 | Partial | Local notifications only (no FCM); no briefing/milestone; **routine reminders have their own cap, so a day can pass 4** | `starter_plan/domain/touchpoints.dart`; `starter_plan_test.dart` |
| FR-TCH-02 | Agent-written copy; no PHI on lock screen | Partial | Fixed generic copy (no agent); no-PHI met | `routine_reminders_test.dart` |
| FR-TCH-03 | Widgets, Done without opening, offline + sync, no health values on lock screen | Partial | See below | See below |

## FR-TCH-03 (widgets) in detail

- **Android: not built.** No Glance/AppWidget code or receiver; the app calls `LiveWellWidgetReceiver`, which doesn't exist.
- **iOS:** small, medium, large and lock-screen widgets exist. The Done intent (iOS 17) only writes a date to the App Group; Home applies it only if opened the same day, and only to the in-memory step. **Nothing is saved or synced**, so a Done tapped before midnight without opening the app is lost.
- **Lock screen: met.** Generic words unless details are on; the snapshot is allow-listed and has no room for health values (`widget_snapshot_test.dart`). The "Hide details" setting is still a TODO.
- Medium has no streak (empty in prod) and no briefing.

## Reachable "coming soon" or dead ends

1. **Track > Habits chip** says "Your habits will show here once you start one" even after habits are ticked (`habitsWeekProvider` empty in prod). Misleading.
2. **Streak card and widget streak** never fill in prod.
3. `planNotReady` ("…will set it up soon") is reachable but has Continue: an honest state.
4. Flagged off in prod (not reachable): briefing, coach reply/voice, own voice, photo avatar.
5. Unused string `studioSceneSoon`.
6. `test/polish/no_coming_soon_test.dart` covers the 5 tabs and Profile only, not pushed screens or sheets; its header is out of date.

## Recommended next fixes (current phase)

1. Save today's step Done to `habit_logs` (offline-first, id `date_habitId`), from the app and the widget, so it survives a restart and syncs (FR-GOL-01, FR-TCH-03).
2. Fill the Habits chart and the streak from `habit_logs` (FR-GOL-05, FR-TCH-03 medium).
3. Build the Android widget (Glance): small + medium, interactive Done on Android 12+ (FR-TCH-03).
4. 30/90-day charts; manual entry for weight, BP, glucose, meals with source + timestamp; long-term outcome on the goal (FR-GOL-01/04/05).
5. Small: optional biometric unlock (FR-ONB-01), "how this voice was made" text (FR-VOC-08), routine reminders under the global cap of 4 (FR-TCH-01), loved-one row's own handler, widen the no-coming-soon test to pushed screens.
