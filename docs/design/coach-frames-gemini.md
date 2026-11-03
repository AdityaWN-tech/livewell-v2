# Making the coaches' expression pictures in Gemini

The 8 ready-made coaches come from your Gemini portraits (`docs/design/coaches/<id>.webp`). Until hand-made pictures exist, `apps/mobile/tool/make_coach_frames.py` makes the **blink** and the **mouth shapes** from each portrait, and the **expressions move in code** (cheer = hop with sparkles, waving = sway, listening = lean). Pictures you make in Gemini replace the made-up ones, coach by coach and frame by frame. Every frame you skip keeps working.

## How (about 2 minutes a picture)

1. Open Gemini and start a new chat for one coach.
2. Upload that coach's portrait from `docs/design/coaches/` (for example `brown_hair.webp`).
3. Paste the **base line** below, then one line from the table, and send.
4. Check the result:
   - the **same person** (face, hair, clothes, glasses, hijab, turban, wheelchair);
   - the **same size and position** in the picture;
   - the **same mint background**;
   - **no text**, and nothing childlike.
   If anything changed, ask again ("keep everything else exactly the same").
5. Download the picture and save it as `docs/design/coaches/<coach id>_<frame>.png`, for example `docs/design/coaches/brown_hair_blink.png`.
6. Tell me, or run `python apps/mobile/tool/make_coach_frames.py <face_landmarker.task> brown_hair`. The tool removes the corner mark, aligns the picture and puts it in the app.

**Base line (paste first):**

> Edit this image. Keep exactly the same person, face, hair, clothing, lighting, camera angle, size and position, and the same plain mint background. Only change the facial expression to:

For the mouth pictures, add: *Keep the eyes, eyebrows and head exactly the same; change only the mouth.*

## Which pictures matter most

| Order | Frame (file name ending) | Change the expression to |
|---|---|---|
| 1 | `_blink` | the same smile, eyes fully closed |
| 2 | `_mouth_A` | mouth open wide, as when saying "ah" |
| 3 | `_mouth_O` | mouth round and open, as when saying "oh" |
| 4 | `_mouth_closed` | lips gently closed, relaxed face |
| 5 | `_celebrating` | joyful laugh, eyes squinted, both hands raised in a cheer |
| 6 | `_waving` | big smile, right hand raised and waving beside the face |
| 7 | `_mouth_E` | mouth half open, as when saying "eh" |
| 8 | `_mouth_U` | lips rounded and pushed forward, as when saying "oo" |
| 9 | `_mouth_I` | mouth wide, teeth slightly showing, as when saying "ee" |
| 10 | `_listening` | soft attentive look, small closed smile, head tilted slightly |
| 11 | `_calm` | peaceful soft smile, relaxed eyebrows |
| 12 | `_happy` | big warm smile showing teeth |

The first four give the biggest step up: they're the pictures the coach shows most while talking and blinking.

**Coach ids:** `brown_hair`, `long_black_hair`, `green_hijab`, `navy_turban`, `grey_glasses`, `short_curls`, `short_black_hair`, `wheelchair`.

**Before release:** the pictures are AI-generated, so their commercial use has to be checked against the generator's terms (`docs/design/asset-licences.md`). Until a coach is marked `final` in `apps/mobile/assets/illustrations/illustrations.json`, it shows in dev builds only.
