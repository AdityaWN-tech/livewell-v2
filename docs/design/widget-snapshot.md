# Home-screen widget: the snapshot (T-AVT-08g-a)

The app writes one JSON string, `lw_snapshot`, that the native widgets read. They never compute anything about the day themselves, and they never read the app's database.

- **iOS:** the App Group's shared `UserDefaults` (`group.net.conciergeconnectedcare.livewell` with `.dev` / `.stg` for the other flavours, D-40), through `home_widget`. Widget kind `LiveWellWidget`.
- **Android:** `home_widget`'s shared preferences. Receiver `LiveWellWidgetReceiver`.

Code: `apps/mobile/lib/features/widget/` (`domain/widget_snapshot.dart`, `domain/widget_builder.dart`, `application/widget_sync.dart`, `data/widget_publisher.dart`).

## Fields (only these, ever)

A test fails if a field is added. **Never** mood, energy, sleep, stress, health values, reflection text or other free text (AGENTS.md). The builder has no input for check-in answers at all; it only knows *whether* the person checked in and whether today is a gentle day.

| Field | Type | What |
|---|---|---|
| `version` | int | 1 |
| `first_name` | string or null | For the greeting. Null when signed out. |
| `avatar_thumbs` | object | Expression name (`waving`, `happy`, `calm`, `listening`, `celebrating`) → PNG path on the device: the frame set's thumbnail (T-AVT-08d), else the initial circle. The iOS PR copies these into the App Group container. |
| `streak_days` | int or null | |
| `routine` | object | `morning` (check-in), `step`, `evening` (reflection): `todo` or `done`. Never "missed", never red. |
| `entries` | array | The first entry is **now**. Then one at each touchpoint time where it changes (default 13:00 and 20:30), then the **next midnight** (a new day: the morning check-in). The widget shows the last entry whose `at` has passed. |
| `hide_details` | bool | "Hide details on lock screen" (default on; setting in 08g-e). |
| `updated_at` | ISO time | |

Each entry has:
- `at`, `slot`, `expression`, `headline`, `subline` (optional) and `lock_headline` (generic unless details are on);
- `primary_action` and `secondary_action` (optional), each `{id, label, link}`.

## Slots and actions

| Slot | When | Face | Headline | Primary | Secondary |
|---|---|---|---|---|---|
| `morning_checkin` | before the check-in, until the step time | waving | Good morning, {first name}! | Check in → `livewell://checkin` | |
| `step` | checked in, before the step time | happy | the step | Start → `livewell://step` | Make it smaller → `livewell://step?smaller=1` |
| `step_window` | from the step time | happy | Time for your {step} | **Done** → `livewell://step?done=1` | Start |
| `gentle` | gentle day, or a safety response today | calm | the smaller step | Start | |
| `done` | step done | celebrating (calm after a safety response) | Day {N}! | Open → `livewell://home` | |
| `evening` | from the evening time, until reflected | listening (calm after a safety response) | How did today go? | Reflect → `livewell://reflection` | |
| `none` | no plan | happy | Open Live Well to start your plan | Open | |
| `signed_out` | signed out | happy | Open Live Well to sign in | Open | |

**Done:** on iOS 17+ and Android 12+ the native PRs log Done from the widget itself (offline, idempotent by date). Elsewhere the button opens the link. There are no portal or course suggestions on the widget.

**When it is rewritten:** whenever the plan, check-in, step, reflection, coach, name or sign-in changes (a 300 ms pause groups changes), when the app comes back to the foreground, and at midnight. The timeline covers the touchpoint times in between, so the widget changes on time without the app running.
