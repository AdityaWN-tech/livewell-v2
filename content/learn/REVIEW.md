# Learn: clinical review (Step 4e, D-57)

## Breathing guide patterns

Built into the app (`apps/mobile/lib/features/learn/domain/breathing.dart`), so they work offline. They are drafts until the clinical team approves them. No pattern uses a hold longer than 4 seconds, and the guide always shows: "Breathe gently, through your nose if you can. If you feel dizzy or unwell, stop and breathe normally."

| id | Name | Timing (seconds) | Lengths offered | Approved? |
|---|---|---|---|---|
| `box` | Box breathing | in 4, hold 4, out 4, hold 4 | 1, 2, 5 min (or the session's length) | ☐ |
| `calm` | Slow breathing | in 4, out 6 | 1, 2, 5 min | ☐ |
| `sleep` | Sleep wind-down | in 4, out 7 | 1, 2, 5 min | ☐ |

Questions for the reviewers: are these timings right for beginners and older adults? Should box breathing be hidden for anyone (for example during a safety hold or with breathing conditions)? Should the guide add anything to the safety line?

## Lessons (content_items)

The app shows a lesson only when it is `review_status: approved` **and** has `cards` (FR-LRN-01: 2 to 5 minute lessons, each ending with a MY GOAL DO IT microhabit). Writing and approving the 24+ lessons (3 per driver) is content work for the clinical team; none exist yet. Each card and the microhabit can be read aloud by the coach ("Listen", FR-LRN-02) exactly as approved: the text is never changed or added to.

Fields the reader uses (see `docs/data-model.md`): `title`, `category`, `summary`, `read_minutes`, `art_id`, `cards` (list of short paragraphs), `microhabit` {`title`, `minutes`}, `version`. A breathing session is `type: audio` with `breathing: box | calm | sleep`. Recorded audio sessions (`audio_url`) are not shown until the audio player and offline download are built.
