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

## Characters: expressions
Every character in **all 6 expressions**: `happy`, `waving`, `talking`, `listening`, `calm`, `celebrating`. Safety replies always use `calm`. Characters must cover a range of skin tones (Monk Skin Tone Scale), ages, hair types and head coverings, and include a wheelchair user (FR-AVT-02). The person chooses their coach; the app never guesses gender or looks (D-28).

## Characters (default coach avatars)

| id | What to draw | Alt text | Status |
|---|---|---|---|
| `character_hoodie` | Young man in a green hoodie (the default coach in the design). All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_hoodie_{expression}.png | Your coach | placeholder |
| `character_long_hair` | Woman with long hair. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_long_hair_{expression}.png | Your coach | placeholder |
| `character_glasses` | Man with glasses. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_glasses_{expression}.png | Your coach | placeholder |
| `character_curly` | Woman with curly hair. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_curly_{expression}.png | Your coach | placeholder |
| `character_hijab` | Woman wearing a hijab. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_hijab_{expression}.png | Your coach | placeholder |
| `character_turban` | Man wearing a turban. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_turban_{expression}.png | Your coach | placeholder |
| `character_older` | Older adult with grey hair. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_older_{expression}.png | Your coach | placeholder |
| `character_wheelchair` | Person using a wheelchair. All 6 expressions: happy, waving, talking, listening, calm, celebrating. File pattern: character_wheelchair_{expression}.png | Your coach | placeholder |

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
