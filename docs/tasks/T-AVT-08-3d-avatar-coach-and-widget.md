# T-AVT-08: 3D adult avatar coach, everything the avatar does, and the widget

| Field | Value |
|---|---|
| ID | T-AVT-08 (PRs AVT-08a to AVT-08h below) |
| **Replaces** | **T-AVT-06 (anime style): stopped.** **T-AVT-07: merged into this file.** The avatar parts of **T-UI-02h** (layered cartoon creator) are replaced by this file. |
| Updates | T-DLY-03 (Avatar Moments), T-GOL-03 (routine reminders), T-TCH-02 (widget) now use this avatar |
| Tag | **needs human review** (biometric data, consent, safety copy, vendor licences, cost) |
| Style reference | `docs/design/avatar-style-3d-reference.png` (adult man, green knit sweater, mint background) |
| Spec refs | FR-ONB-03, FR-AVT-01..07, FR-VOC-05/07/08, FR-DLY-01..09, FR-TCH-01..04, FR-SAF-02, §7–8, §16.3, NFR-02/05/06/08/10 |

Read `AGENTS.md` and the spec first. **One PR per section, stacked in order, and wait for the product owner's OK after each.** Never weaken a consent, privacy, safety rule, cap or the closed-script rule.

---

## 0. Stop the anime work, keep the reusable engine

The anime style is cancelled. Some of that work is reusable because it does not depend on the art style.

**Keep and reuse (rename to style-neutral names if needed):**
- the blink timer (every 3–6 s, reduced-motion aware);
- the lip-movement logic: speech timing or loudness → mouth shapes `A`, `I`, `U`, `E`, `O`, `closed`;
- the expression mapping (emotion tag → expression);
- the `CoachAvatar` widget API, expression transitions, tests for the above.

**Remove:**
- the Anime/Illustrated style switch, anime parts, anime-only categories (sparkle eyes, blush, bangs, hair clips), anime placeholder art, `anime-asset-brief.md`;
- the layered cartoon-parts creator UI (T-UI-02h avatar tab) and any code-drawn avatar shapes.

Close or update any open AVT-06 PRs. In the PR description list what was kept and what was removed. Update `docs/progress.md`: T-AVT-06 = cancelled, T-AVT-07 = merged into T-AVT-08.

---

## 1. The avatar style

**One style only: semi-realistic 3D caricature for adults.** Slightly larger head, realistic skin texture (light freckles, stubble where it fits), natural detailed hair, warm genuine smile, soft green knit sweater by default, plain mint-green studio background, soft front lighting. Upper body, centred, facing the camera.

- **Adults only (18+).** No child-like faces. The image safety check rejects child-looking results.
- **Inclusive:** all skin tones, ages 20s–70s, facial hair, glasses, hijab, turban, kippah, hearing aids, wheelchair (wheelchair visible at the bottom edge).
- All prompts live in `docs/design/avatar-prompts.md` (copy from the Appendix below). Code reads prompts from that file; nothing is hard-coded.

---

## 2. How users get their avatar (3 ways, one result)

| Way | How | Speed | Cost |
|---|---|---|---|
| **Pick a ready-made coach** | 8 default adult characters (Appendix C), frame sets bundled in the app | Instant, offline | None per user |
| **Make me from my photo** | Live selfie → server creates the 3D avatar that looks like the user | 30–90 s, once | Per avatar |
| **Build my own** | User picks options (face shape, skin tone, eyes, eyebrows, nose, lips, hairstyle, hair colour, facial hair, outfit, outfit colour, cap/hat, head covering, glasses, accessories, background) → server creates the avatar from those choices | 30–90 s | Per avatar |

After any way, the user can **adjust** (hair, outfit, cap, glasses, head covering, accessories, background) using the same option lists. Each change creates a new version with a preview; the old version stays until the user saves.

**All three produce the same "avatar frame set"** (14 images of the same face, Appendix B) that the phone plays for talking, blinking and expressions. No video is generated per message, so the coach responds instantly and works offline (NFR-02, NFR-05).

---

## PR AVT-08a: Clean-up and frame-set engine

- Do section 0 (stop anime, keep the engine).
- Define `avatar_frames.json`: avatar id, version, style `3d_adult`, frames (`neutral`, `happy`, `waving`, `listening`, `calm`, `celebrating`, `blink`, `mouth_A`, `mouth_I`, `mouth_U`, `mouth_E`, `mouth_O`, `mouth_closed`, `thumb`), sizes.
- `CoachAvatar` plays a frame set: expression swaps with a soft cross-fade, blink, lip movement using the kept engine, gentle idle breathing (tiny scale/offset). Reduced motion → still `neutral` frame + captions.
- Frames cached on the device; signed URLs from Cloud Storage `avatars/{uid}/{version}/`.
- Fallback chain (FR-AVT-05): frame set → `neutral` only → default coach → initial circle.
- Tests: expressions, blink, lip shapes, reduced motion, offline cache, fallback.

## PR AVT-08b: Ready-made coaches + Avatar Studio

- Bundle the 8 default characters' frame sets (placeholders until final images exist; status tracked in `illustrations.json`).
- **Avatar Studio** (from onboarding and Profile > My coach), illustrated app design: large live preview of the avatar (idle breathing + blink), tabs **Coaches**, **From my photo**, **Build my own**, **Adjust**, **Background**.
- Coach name field (default "Coach"), saved with the avatar.
- Save to `users/{uid}/avatar/current` (`type: "3d_adult"`, `source: default | selfie | built`, `frames_version`, `options`, `coach_name`).
- Tests: pick, save, load, rename, switch.

## PR AVT-08c: Server: avatar generation (Media Service, Python, Cloud Run)

- `POST /v1/avatar` with `source: selfie | built | adjust`; `GET /v1/avatar/jobs/{id}` for status (spec §12.1).
- **`AvatarStylizer` adapter** so the image method can be swapped (commercial image API with face reference/editing, or self-hosted models on our own GPU). Choice made with a scorecard: likeness, consistency with the reference, speed, cost per avatar, **commercial licence**, data terms (no training on our photos, deletion API).
- **Licence warning:** several popular face models depend on InsightFace models licensed for **non-commercial use only**. Do not use them in prod without a commercial licence. Record every model and licence in `docs/design/asset-licences.md`.
- **Never** send user photos to free public demo servers (public Gradio/Colab).
- Prompts from `docs/design/avatar-prompts.md` (Appendix A).
- Image safety check on every result: reject child-looking faces, nudity, violence, text/logos; for selfies, reject if face similarity is below the threshold. Retry once, then a kind message.
- Cost guardrails: max 3 generations per user per day (Remote Config); cost per avatar on the cost dashboard.

## PR AVT-08d: Server: build the 14-frame set

- From the approved portrait, create every frame with the edit prompts (Appendix B). Mouth frames keep eyes, eyebrows and head identical to `neutral`.
- Remove background where needed, align all frames to the same canvas and position, export WebP (2x/3x) + `thumb`, write `avatar_frames.json`.
- Quality check: same face and position in every frame (similarity score); a failed frame is regenerated once, else falls back to `neutral`.
- Also export small **expression thumbnails** for notifications and the widget.

## PR AVT-08e: "Make me from my photo" (consent, capture, deletion)

- **Consents before the camera opens** (FR-ONB-03): camera + biometric processing, in plain language: what is done with the photo, that it is deleted right after creation (7 days at most), and how to delete the avatar. Declined → Coaches or Build my own.
- **Own face only** (FR-AVT-03): live in-app selfie (no gallery upload), simple liveness (blink or turn head), one face, good-photo tips with on-device face detection.
- Upload only to our Media Service over HTTPS; **raw selfie deleted immediately after the job** (storage audit test, FR-AVT-07, §16.3). Audit log entries.
- Feature flag `avatar_from_photo` (off in prod until counsel review, T-CMP-02).

## PR AVT-08f: Everything the avatar does in the app

The avatar is the face of every coaching moment. It speaks in the user's chosen voice (device text-to-speech for now; voice adapter later), with captions, lip movement and the right expression. Lines come from **approved templates** (`/content/coach/moments/`, `/content/routine/catalog.json`), never from user-typed text (closed-script rule, FR-VOC-05).

| Moment | When | Example line | Expression |
|---|---|---|---|
| **First hello** (onboarding) | after avatar + voice chosen | "Hi Priya, I'm Sam, your Live Well coach. You told me your why: energy to travel with your family. Let's start with one small step." | waving → happy |
| **Morning greeting** | morning time (default 7:00) | "Good morning, Priya! Hope you slept well. Today's step: a 10-minute walk after lunch. Five minutes still counts. How are you feeling today?" | waving |
| **Check-in reaction** | after mood check-in | good: "Love that energy!" / okay: "Thanks for checking in." / low or stressed: "Thanks for telling me. Let's keep today gentle." | happy / calm |
| **Step reminder** | habit time | "Lunch done? It's a great time for your walk. Shall we go?" | encouraging |
| **Routine items** | each routine time | "Time to drink a glass of water!" (custom items: "It's time for your next routine step") | happy |
| **Done celebration** | on Done | "You did it! That's day 9." | celebrating |
| **Gentle day** | low mood / high stress | "Let's keep it gentle today: two minutes of slow breathing is enough." | calm |
| **Missed day** | next morning | "Yesterday was a rest day, and that's okay. Let's restart small." | encouraging |
| **Evening reflection** | evening time | "How did today go? What went well?" | listening |
| **Weekly review** | Sunday | "This week you walked 5 times. Great work!" | happy |
| **Streak milestones** | 7, 14, 30 days | "Two weeks in a row. That's a real habit now!" | celebrating |
| **Lesson narration** | Learn > Listen | reads approved lesson text | neutral / talking |
| **Care chat** | Care tab | listening while the user speaks; talking when replying ("coming soon" until the AI coach exists) | listening / talking |
| **Notifications** | every moment | avatar face thumbnail + short line; tap opens the full Avatar Moment | matching |
| **Home hero** | always | current moment's expression + short speech bubble + play | matching |

**What the avatar never does:**
- Safety, crisis and emergency messages are shown as the existing safety cards with the **neutral system voice** (FR-SAF-02, FR-VOC-07). The avatar is hidden or shown still with the `calm` frame; it never smiles or celebrates next to safety content.
- No orders or guilt ("you must", "you failed"); only invitations ("Shall we...?").
- No portal/course mentions in greetings, reminders or gentle moments.
- Never suggests running or hard exercise unless that is the user's approved plan (FR-GOL-03).

Phones don't allow an app to pop up and talk by itself, so each moment starts with an **avatar notification**; tapping it opens the full-screen Avatar Moment, which speaks. Respect notification consent, quiet hours and caps (FR-DLY-04, FR-TCH-01).

## PR AVT-08g: The widget with the 3D avatar

Home-screen widgets on iOS (WidgetKit) and Android (Glance) that recommend **one thing to do now**, delivered by the avatar.

| Time of day | Widget shows | Button |
|---|---|---|
| Morning, before check-in | waving avatar, "Good morning, {first name}" | Check in |
| After check-in | today's step | Start / Make it smaller |
| Step or routine time | "Time for your 10-min walk" / next routine item | **Done** |
| After Done | celebrating avatar, "Day {N}!" | Open |
| Evening | listening avatar, "How did today go?" | Reflect |
| Gentle day | calm avatar, smaller step | Start |

- Sizes: **small** (avatar face + one line + one button), **medium** (adds streak + Morning · Step · Evening routine row, never red for missed), **large** (day checklist with times). iOS lock-screen: streak + "Next step ready".
- **Done works without opening the app** (iOS 17+, Android 12+), offline, synced later (idempotent).
- Data via `home_widget` snapshot: first name, avatar expression thumbnail path, slot, headline, actions, streak, routine status. **Never** mood, health values, reflection text or custom labels when "Hide details on lock screen" is on (default ON).
- No portal or course suggestions on the widget.
- Updates: on plan, check-in, habit, routine or avatar change; at each touchpoint time; at midnight.
- "Add the widget" guide card after onboarding and in Profile > Daily plan.

## PR AVT-08h: Settings and deletion

- Profile > My coach: avatar preview, coach name, "Choose another coach", "Remake from a new photo", "Build my own", "Adjust", voice, **Delete my avatar** (removes portrait + frames + vendor copy, audit log, falls back to a default coach; FR-SET-03).
- Profile > Daily plan: moment times, "Coach speaks automatically", voice speed, captions always on, widget settings.

---

## Tests (all PRs)

- Frame set complete and consistent (manifest test); player offline; reduced motion.
- Consent declined path; no gallery upload; raw selfie deleted (audit test); delete my avatar removes everything.
- No user photo ever sent to a non-approved endpoint (adapter test); child-looking results rejected.
- Every moment in the table renders the right line, expression and voice; safety content never uses the avatar's happy frames or cloned voices; custom labels never sent to TTS.
- Widget: slot for every time of day, gentle day, Done offline, privacy snapshot test, light/dark.

## Done when

- Screen recording on a test phone: pick a ready-made coach → (flag on) make one from a selfie → adjust the outfit → the avatar says the first hello → simulated day: morning greeting, check-in reaction, step reminder, Done celebration, evening reflection → widget changing through the day with Done from the home screen.
- Anime work removed, reusable engine kept, `docs/progress.md` updated.
- Licences, prompts file and counsel-review ticket in place.

---

## Appendix A: Image prompts (copy to `docs/design/avatar-prompts.md`)

**Master style**
> Stylized 3D character portrait of an adult, semi-realistic 3D animation style with a friendly caricature look: slightly larger head, realistic skin texture with natural pores and light freckles, soft rosy cheeks, expressive eyes, natural hair with fine detail, warm genuine smile. Wearing a soft green knit crew-neck sweater. Upper body, centred, facing the camera, head and shoulders filling the top two thirds of the frame. Plain soft mint-green studio background, soft diffused front lighting, gentle shadows, shallow depth of field, high detail, square 1024x1024.

**Avoid list**
> child, teenager, baby face, cartoon flat style, anime, distorted hands, extra fingers, text, logo, watermark, harsh shadows, dark background, sunglasses, hat unless requested, nudity, scary or creepy expression

**From a selfie**
> Using the attached photo as the identity reference, create a portrait of the same adult person in this style: [MASTER STYLE]. Keep their face shape, skin tone, eye shape, nose, eyebrows, facial hair, hair colour and hairstyle so they are clearly recognizable, and keep their real age. Expression: warm happy smile, eyes open, looking at the camera. Pose: shoulders straight, hands not visible. Clothing: [OUTFIT]. Head covering or accessories only if requested: [ACCESSORIES].

**Build my own (from options)**
> Create an original adult character in this style: [MASTER STYLE]. Age: [AGE RANGE]. Face shape: [FACE]. Skin tone: [SKIN]. Eyes: [EYES]. Eyebrows: [EYEBROWS]. Nose: [NOSE]. Lips: [LIPS]. Hair: [HAIRSTYLE], [HAIR COLOUR]. Facial hair: [FACIAL HAIR]. Clothing: [OUTFIT] in [OUTFIT COLOUR]. Head covering, hat or accessories: [ACCESSORIES]. Expression: warm happy smile, eyes open, looking at the camera. Pose: shoulders straight, hands not visible.

(Option values come from fixed lists in `/content/avatar/options.json`; no free text from users.)

## Appendix B: Frame edit prompts

Base:
> Edit this image. Keep exactly the same person, face, hair, clothing, lighting, camera angle, size and position, and the same background. Only change the facial expression to: [EXPRESSION].

Mouth frames add:
> Keep the eyes, eyebrows and head exactly the same as the neutral frame; change only the mouth.

| Frame | [EXPRESSION] |
|---|---|
| neutral | relaxed, gentle closed-mouth smile, eyes open |
| happy | big warm smile showing teeth, eyes open |
| waving | big smile, eyes happily squinted, right hand raised and waving beside the face |
| listening | soft attentive look, small closed smile, head tilted slightly |
| calm | peaceful soft smile, eyes softly open, relaxed eyebrows |
| celebrating | joyful laugh, eyes squinted, both hands raised in a cheer |
| blink | same as neutral, eyes fully closed |
| mouth_A | mouth open wide as when saying "ah" |
| mouth_I | mouth wide, teeth slightly showing, as when saying "ee" |
| mouth_U | lips rounded and pushed forward, as when saying "oo" |
| mouth_E | mouth half open, as when saying "eh" |
| mouth_O | mouth round and open, as when saying "oh" |
| mouth_closed | lips gently closed, neutral face |

## Appendix C: Default coaches (master style + description)

1. Adult man in his 30s, messy brown hair, light stubble, fair skin with freckles (the reference).
2. South Asian woman in her 30s, long black hair, warm brown skin.
3. Woman in her 40s wearing a soft green hijab, medium brown skin.
4. Sikh man in his 40s with a navy turban and neat black beard.
5. Man in his 60s with short grey hair, round glasses and a kind smile.
6. Black woman in her 50s with short natural curly hair.
7. East Asian man in his 20s with short black hair.
8. Woman in her 30s using a wheelchair, shoulder-length auburn hair (wheelchair visible at the bottom edge).
