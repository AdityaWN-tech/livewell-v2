# Avatar prompts (T-AVT-08)

The single source of the prompts used to make the coach's 3D avatar and its 14-frame set. Code reads the prompts from this file; nothing is hard-coded (T-AVT-08 section 1). Copied from the appendices of `docs/tasks/T-AVT-08-3d-avatar-coach-and-widget.md`; change them here, with review.

**Style reference:** `docs/design/avatar-style-3d-reference.png` (adult man in his 30s, messy brown hair, light stubble, freckles, green knit crew-neck sweater, mint-green studio background). It is a **reference only**: it shows the look; it is never shipped in the app or used as a coach. It is an AI-generated image; the generator's corner watermark was removed for use as a clean reference (2026-10-22). Its source is recorded in `asset-licences.md`.

**Rules for every prompt:** adults only (18+), never child-like; inclusive (all skin tones, ages 20s–70s, facial hair, glasses, hijab, turban, kippah, hearing aids, wheelchair). Option values in **Build my own** come from fixed lists in `/content/avatar/options.json` (T-AVT-08b); no free text from users goes into a prompt.

## A. Image prompts

**Master style**
> Stylized 3D character portrait of an adult, semi-realistic 3D animation style with a friendly caricature look: slightly larger head, realistic skin texture with natural pores and light freckles, soft rosy cheeks, expressive eyes, natural hair with fine detail, warm genuine smile. Wearing a soft green knit crew-neck sweater. Upper body, centred, facing the camera, head and shoulders filling the top two thirds of the frame. Plain soft mint-green studio background, soft diffused front lighting, gentle shadows, shallow depth of field, high detail, square 1024x1024.

**Avoid list**
> child, teenager, baby face, cartoon flat style, anime, distorted hands, extra fingers, text, logo, watermark, harsh shadows, dark background, sunglasses, hat unless requested, nudity, scary or creepy expression

**From a selfie**
> Using the attached photo as the identity reference, create a portrait of the same adult person in this style: [MASTER STYLE]. Keep their face shape, skin tone, eye shape, nose, eyebrows, facial hair, hair colour and hairstyle so they are clearly recognizable, and keep their real age. Expression: warm happy smile, eyes open, looking at the camera. Pose: shoulders straight, hands not visible. Clothing: [OUTFIT]. Head covering or accessories only if requested: [ACCESSORIES].

**Build my own (from options)**
> Create an original adult character in this style: [MASTER STYLE]. Age: [AGE RANGE]. Face shape: [FACE]. Build: [BODY TYPE]. Skin tone: [SKIN]. Eyes: [EYES]. Eyebrows: [EYEBROWS]. Nose: [NOSE]. Lips: [LIPS]. Hair: [HAIRSTYLE], [HAIR COLOUR]. Facial hair: [FACIAL HAIR]. Clothing: [OUTFIT] in [OUTFIT COLOUR]. Head covering, hat or accessories: [ACCESSORIES]. Expression: warm happy smile, eyes open, looking at the camera. Pose: shoulders straight, hands not visible.

(Option values come from fixed lists in `/content/avatar/options.json`; no free text from users.)

**Adjust (from options)** (added in T-AVT-08c; not in the task's appendix: needs review)
> Edit this image. Keep exactly the same person, face, skin, expression, lighting, camera angle, size and position, and the same background. Only change: [CHANGES].

## B. Frame edit prompts

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

## C. Default coaches (master style + description)

1. Adult man in his 30s, messy brown hair, light stubble, fair skin with freckles (the reference).
2. South Asian woman in her 30s, long black hair, warm brown skin.
3. Woman in her 40s wearing a soft green hijab, medium brown skin.
4. Sikh man in his 40s with a navy turban and neat black beard.
5. Man in his 60s with short grey hair, round glasses and a kind smile.
6. Black woman in her 50s with short natural curly hair.
7. East Asian man in his 20s with short black hair.
8. Woman in her 30s using a wheelchair, shoulder-length auburn hair (wheelchair visible at the bottom edge).
