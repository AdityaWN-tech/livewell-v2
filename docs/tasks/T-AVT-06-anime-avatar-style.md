# T-AVT-06: Anime-style avatar faces in the avatar maker

| Field | Value |
|---|---|
| ID | T-AVT-06 (split into PRs AVT-06a to AVT-06c below) |
| Depends on | T-UI-02h (layered avatar maker, parts.json, CoachAvatar) |
| Works with | T-DLY-03 (Avatar Moments: expressions + lip movement) |
| Tag | needs human review (art licences, inclusive design) |
| Spec refs | FR-AVT-01/02/04/05/06, FR-GAM-03, §7.1, §14.1, NFR-06, NFR-08 |

Read `AGENTS.md` and the spec first. **One PR per section, stacked in order.** Do not draw any avatar parts with code shapes.

---

## Goal

Add an **Anime** art style to the avatar maker. Users choose a style first, then customize every part: face, eyes, eyebrows, nose, lips, hair, hair colour, outfit, caps and accessories, exactly like the existing maker.

- Styles: **Anime** and **Illustrated** (the current Live Well style). Both use the same layer system, so every feature (expressions, lip movement, widget, Avatar Moments) works for both.
- Default style for new users: `needs-product` (suggest letting the user pick at the first avatar step, with a preview of each).

---

## PR AVT-06a: Style support in the part system

- `parts.json` gets a `style` field (`anime` | `illustrated`); each style has its own full part set.
- `style_config` in `users/{uid}/avatar/current` stores `style` + chosen parts. Switching style keeps matching choices where possible (skin tone, hair colour, glasses) and resets the rest.
- Avatar Studio: a **style switch** at the top (Anime / Illustrated) with a live preview.
- Anime-specific categories in addition to the existing ones: **eye highlights** (sparkle styles), **blush**, **bangs** (front fringe), **hair accessories** (clips, ribbons).
- Compatibility rules still apply (hijab/turban hides hair; caps hide fringe, etc.).

## PR AVT-06b: Anime expressions, blinking and lip movement

Each anime eye, eyebrow and mouth style needs these versions:
- **Eyes:** open, closed-smile (^ ^), sparkle (happy), soft (calm), half-closed (listening), blink.
- **Eyebrows:** neutral, raised (happy), soft (calm), slightly up in the middle (caring).
- **Mouth:** closed smile, open smile, talking shapes **A, I, U, E, O** and closed, for lip movement.
- **Extras:** blush on celebrating; small sparkles or hearts around the head on celebrating (skipped with reduced motion).

Map expressions to `CoachAvatar` emotions: waving, happy, encouraging, listening, calm, celebrating. Lip movement uses the 5 mouth shapes from the speech timing (or loudness if timing isn't available). Blink every 3–6 seconds; gentle idle sway.

Animation tech: keep the layer images for now. Later the parts can move to **Rive** (planned in the spec) or a similar 2D rig for smoother anime animation; check any SDK licence and app-size impact first (NFR-08).

## PR AVT-06c: Anime art kit, placeholders and brief

- Until final art exists, use placeholder parts whose licence allows commercial use, recorded in `docs/design/asset-licences.md`. If none is found, show a soft circle with the initial (never code-drawn faces).
- Write `docs/design/anime-asset-brief.md` for the illustrator, with:
  - **Style:** original, friendly anime look; soft pastel colours matching the Live Well palette; clean outlines; big expressive eyes with highlights; warm and calm, not childish or sexualized; suitable for adults of all ages.
  - **Original only:** no copying or imitating specific anime characters, studios or artists; no copyrighted characters.
  - **Inclusive:** 10+ skin tones, all ages (including older adults with grey hair and wrinkles), different body types, hijab, turban, kippah, glasses, hearing aids, wheelchair (full-body view).
  - **Part counts (starting kit):** 6 face shapes, 12 eyes (each with expression versions), 10 eyebrows, 6 noses, 10 mouths (each with A I U E O), 20 hairstyles (front + back layers), 8 bangs, 10 hair colours (recolourable), 15 outfits (recolourable), 8 caps and hats, head coverings, 12 accessories, 6 blush styles, 10 backgrounds.
  - **Technical:** same canvas size and anchor points as the illustrated kit, SVG or PNG @3x with transparency, recolourable areas as single flat colours, file names per `parts.json`.
- Some anime parts (sparkle eyes, ribbons, special outfits) are **unlockable** with streaks (FR-GAM-03).

---

## Tests

- Style switch keeps compatible choices; save and load per style.
- Every expression and mouth shape exists for every anime eye/eyebrow/mouth part (manifest test).
- Lip movement and blink run in the Avatar Moment player; reduced motion shows a still face.
- Golden tests: anime avatar on Home, Care, Studio and widget, light and dark.

## Done when

- A user can pick Anime, customize every part, and see their anime coach wave, talk (with moving lips), blink and celebrate in an Avatar Moment, shown in a screen recording.
- `anime-asset-brief.md` and licences file exist.
