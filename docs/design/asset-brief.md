# Illustration and character asset brief (T-UI-02b)

Every illustration the illustrated "Live Well v2" design needs, in one consistent style. The app loads each one by **id** from `apps/mobile/assets/illustrations/illustrations.json` and draws a soft tinted placeholder until the final file exists. Reference: `docs/design/live-well-v2-illustrated.png` (style only; **never copy pixels from it**, it is low resolution).

## Style (all assets)
- Flat, hand-drawn look; soft pastel fills from the app tints (mint, lime, lavender, peach, sky, butter, rose); gentle navy outlines (`#1B2433`, about 2 px at 1x); leafy plants as decoration.
- Friendly, bright, calm, hopeful. Tagline: "Small steps. Brighter days."
- Transparent PNG (or WebP), drawn at 3x. Characters 512 x 512, scenes 1080 x 720, lesson cards 600 x 450, icons 96 x 96, feature art 600 x 600.
- **Dark mode:** a `file_dark` variant where the light art would glare (scenes, empty states). Icons and characters can share one file.
- No text inside images (it can't be translated or scaled). No copyrighted characters or brand logos.

## Licence rule
All final art must be **original or licensed for commercial use**, recorded per asset in the manifest (`source`, `licence`). A test fails if an asset is marked `final` without a file, a source and a licence. AI image tools only if their terms allow commercial use and the client approves (needs-product).

## How to add a final asset
1. Save the file(s) in `apps/mobile/assets/illustrations/` using the id: `<id>.png`, `<id>_dark.png`. Characters: `<id>_<expression>.png`.
2. In the manifest, set `file`, `file_dark` (optional), `source`, `licence`, and `status: "final"`.
3. Run `flutter test` (manifest test), then the goldens.

## Coaches: the 3D frame sets (T-AVT-08)
The 8 ready-made coaches are semi-realistic 3D adults in the style of `docs/design/avatar-style-3d-reference.png`, made from the prompts in `docs/design/avatar-prompts.md`. Each needs the **14-frame set**: `neutral`, `happy`, `waving`, `listening`, `calm`, `celebrating`, `blink`, `mouth_A`, `mouth_I`, `mouth_U`, `mouth_E`, `mouth_O`, `mouth_closed`, `thumb`, on one canvas with the face in the same place, WebP at 2x and 3x, with `avatar_frames.json` (schema `packages/schemas/avatar_frames.schema.json`), in `apps/mobile/assets/avatar/frames/coaches/<id>/`. Safety replies always use `calm`. Adults only; the coaches cover a range of skin tones, ages, hair types and head coverings, and include a wheelchair user (FR-AVT-02). The person chooses their coach; the app never guesses gender or looks (D-28).

## Coaches (the 8 ready-made coaches)

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `coach_brown_hair` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): Adult man in his 30s, messy brown hair, light stubble, fair skin with freckles (the style reference, docs/design/avatar-style-3d-reference.png). The default coach. The 14-frame set goes in assets/avatar/frames/coaches/brown_hair/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_long_black_hair` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): South Asian woman in her 30s, long black hair, warm brown skin. The 14-frame set goes in assets/avatar/frames/coaches/long_black_hair/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_green_hijab` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): Woman in her 40s wearing a soft green hijab, medium brown skin. The 14-frame set goes in assets/avatar/frames/coaches/green_hijab/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_navy_turban` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): Sikh man in his 40s with a navy turban and neat black beard. The 14-frame set goes in assets/avatar/frames/coaches/navy_turban/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_grey_glasses` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): Man in his 60s with short grey hair, round glasses and a kind smile. The 14-frame set goes in assets/avatar/frames/coaches/grey_glasses/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_short_curls` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): Black woman in her 50s with short natural curly hair. The 14-frame set goes in assets/avatar/frames/coaches/short_curls/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_short_black_hair` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): East Asian man in his 20s with short black hair. The 14-frame set goes in assets/avatar/frames/coaches/short_black_hair/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |
| `coach_wheelchair` | Ready-made 3D coach (T-AVT-08b, docs/design/avatar-prompts.md section C): Woman in her 30s using a wheelchair, shoulder-length auburn hair (wheelchair visible at the bottom edge). The 14-frame set goes in assets/avatar/frames/coaches/wheelchair/ with avatar_frames.json (placeholder cards until the art is final; shown only in dev builds until then). | Your coach | placeholder |

## Scenes and Studio backgrounds

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `scene_home_hero` | Home hero: leafy plants, soft sun, room for the coach on the left and a speech bubble on the right | (decorative) | placeholder |
| `scene_care_hero` | Care hero: calm leafy corner, room for the coach and a speech bubble | (decorative) | placeholder |
| `studio_bg_garden` | Avatar & Voice Studio background: Garden | Garden background | placeholder |
| `studio_bg_sunrise` | Avatar & Voice Studio background: Sunrise | Sunrise background | placeholder |
| `studio_bg_room` | Avatar & Voice Studio background: Cosy room | Cosy room background | placeholder |
| `studio_bg_beach` | Avatar & Voice Studio background: Beach (unlocked by a 7-day streak) | Beach (unlocked by a 7-day streak) background | placeholder |

## Lesson art

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `lesson_breathe_reset` | Person breathing calmly with headphones | (decorative) | placeholder |
| `lesson_reduce_stress` | Person relaxing with a cup of tea | (decorative) | placeholder |
| `lesson_better_sleep` | Moon and a person sleeping peacefully | (decorative) | placeholder |
| `lesson_move_body` | Person walking briskly outdoors | (decorative) | placeholder |
| `lesson_mindful_eating` | Bowl of colourful vegetables | (decorative) | placeholder |
| `lesson_deep_breathing` | Lotus flower | (decorative) | placeholder |
| `lesson_driver_1` | Lesson art for driver 1 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_2` | Lesson art for driver 2 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_3` | Lesson art for driver 3 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_4` | Lesson art for driver 4 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_5` | Lesson art for driver 5 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_6` | Lesson art for driver 6 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_7` | Lesson art for driver 7 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |
| `lesson_driver_8` | Lesson art for driver 8 (name from Dr. Gokula's content; needs-product) | (decorative) | placeholder |

## Icons and Live Well Map wheel

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `icon_mood` | Smiling mood face. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_energy` | Energy lightning bolt. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_sleep` | Sleep moon. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_stress` | Stress lotus. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_streak` | Streak flame. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_steps` | Shoe for steps. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_water` | Water drop. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_goal` | Target goal. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `icon_reflection` | Reflection notebook. Rounded outline with a small coloured fill | (decorative) | placeholder |
| `wheel_driver_1` | Live Well Map wheel icon for driver 1 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_2` | Live Well Map wheel icon for driver 2 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_3` | Live Well Map wheel icon for driver 3 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_4` | Live Well Map wheel icon for driver 4 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_5` | Live Well Map wheel icon for driver 5 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_6` | Live Well Map wheel icon for driver 6 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_7` | Live Well Map wheel icon for driver 7 (name from content; needs-product) | (decorative) | placeholder |
| `wheel_driver_8` | Live Well Map wheel icon for driver 8 (name from content; needs-product) | (decorative) | placeholder |

## Empty states

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `empty_no_data` | Empty state: No data yet | No data yet | placeholder |
| `empty_offline` | Empty state: You are offline | You are offline | placeholder |
| `empty_coming_soon` | Empty state: Coming soon | Coming soon | placeholder |

## Feature art (onboarding tutorial, store screenshots)

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `feature_notifications` | Onboarding tutorial and store screenshots: Phone with a gentle reminder | Phone with a gentle reminder | placeholder |
| `feature_travel` | Onboarding tutorial and store screenshots: Travel suitcase | Travel suitcase | placeholder |
| `feature_reflection` | Onboarding tutorial and store screenshots: Reflection notebook | Reflection notebook | placeholder |
| `feature_portal` | Onboarding tutorial and store screenshots: Laptop showing a portal course | Laptop showing a portal course | placeholder |
| `feature_watch` | Onboarding tutorial and store screenshots: Smartwatch with a check-in | Smartwatch with a check-in | placeholder |

## Open (needs-product)
- **Who draws the art** (designer, licensed library or an approved image tool) and the licence terms.
- **The 8 driver names** for `wheel_driver_1..8` and `lesson_driver_1..8` come from Dr. Gokula's content; the mockup names are samples.
- **The new leaf logo** shown in the design (the current logo stays until approved).
