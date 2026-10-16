# Brand

## Logo (provisional redraw, D-15)
Redrawn in code from the logo in `apps/mobile/assets/design-reference/portal-login.jpeg` by `apps/mobile/tool/draw_logo.py`
(run `python tool/draw_logo.py` from `apps/mobile`). Outputs in `apps/mobile/assets/brand/`:

| File | Use |
|---|---|
| `master/logo.png` | Full lockup, 1024 px (not bundled): teal rounded square, lime mark, "LIVE WELL", "Health. Habit. Happiness." |
| `master/logo-mark.png`, `master/logo-mark.svg` | Lime circle mark, 1024 px and vector (not bundled; app icon source) |
| `master/wordmark.png` | "LIVE WELL" lettering, full size (not bundled) |
| `logo.png`, `logo-mark.png`, `wordmark.png` + `2.0x/ 3.0x/ 4.0x/` | Bundled, sized for how the app shows them (160 dp, 160 dp, 200 dp wide), so phones decode only what they need |
| `splash/` | Native splash images for flutter_native_splash (not bundled) |

Fonts in the redraw: Times New Roman (title) and Arial Bold (tagline), the closest fonts on this PC to the reference.
When the client's original artwork and font names arrive, replace these files and keep the same names.

## Design tokens (apps/mobile/lib/core/design/)
Feature code uses only these; `test/design/tokens_test.dart` fails the build on raw colours outside `core/design`
and checks every text/background pair for WCAG 2.2 AA in light and dark.

| File | Contents |
|---|---|
| `tokens.dart` | `LwBrand` (logo + app colours), `LwPalette` light/dark (semantic colours, via `LwPalette.of(context)`), `LwShadow`, `LwSpacing`, `LwRadius`, `LwSize`, `LwMotion` |
| `typography.dart` | `LwType`: Poppins type scale |
| `theme.dart` | `LwTheme.light()` / `.dark()`: Material theme built from the tokens (buttons, inputs, chips, cards, sheets, nav bar) |

- **Font:** Poppins (the reference screens' font), bundled in `assets/fonts/poppins` (SIL OFL). Body 16, subtitles 16 grey, titles 24 semibold, display 28, meta 12.
- **Spacing:** 4-point scale `xxs 4 · xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48`; screen gutter 16.
- **Radius:** `sm 8` tags · `md 16` buttons, inputs (`LwRadius.button`) · `lg 24` cards, sheets (`LwRadius.card`) · `pill` chips, segmented tabs.
- **Sizes:** tap targets 48+, buttons 52 high, inputs 56, chips 36.
- **Style (T-UI-02):** white and pastel cards with a very soft shadow on a mint-to-sky wash, solid green selected chips, bold left-aligned screen titles.
- **Kindness rule:** `emergency` red is only for emergency and crisis cards; everyday notices use `caution` amber.
- **Motion:** 150 / 250 / 400 ms, ease-out; `LwMotion.duration()` returns zero when reduce-motion is on.
- **Review on a phone:** the dev flavor opens a "Design tokens" gallery (`lib/features/dev/`).

## App colours (T-UI-02, D-33)
From the illustrated "Live Well v2" design (`docs/design/live-well-v2-illustrated.png`). Replaces the T-UI-01 terracotta palette (D-25). Exact values and every contrast pair: `tokens.dart` and `test/design/tokens_test.dart`.

| Token | Light | Dark | Where |
|---|---|---|---|
| primary | `#07806F` fresh green | `#4CC9A4` | Selected chips and tabs, filled buttons, focus ring, active nav |
| primaryDark | `#0B5E52` deep green | `#BFF0DF` | Text and icons on green tints |
| primaryTint | `#E8F9EE` mint | `#1C3A33` | Nav indicator, quiet selected state |
| accent | `#1E9E70` | `#3DBB96` | **Charts, progress, decoration only** (3:1, not 4.5:1) |
| accentStrong | `#07806F` | `#4CC9A4` | Filled buttons, text links |
| heroSurface | `#F3F7C4` lime pastel | `#2A2F1A` | Featured card (today's next step, coach bubble, portal card), dark text |
| Tints | mint `#E8F9EE` · lime `#F3F7C4` · lavender `#F3EFFE` · peach `#FEEBDF` · sky `#EBF5FE` · butter `#FEF6DD` · rose `#FFE3EC` | deep versions of each | Category cards (steps, sleep, mood, stress, …); text on them is `onTint` navy |
| background / wash | `#F4FBF8`, wash `#E6F7F3` → `#EEF4FC` | `#0D1A1C`, wash `#0F2022` → `#0D1824` | Screens |
| surface / surfaceMuted | `#FFFFFF` / `#F2F4F6` | `#152528` / `#1F2C2F` | White cards / grey chips |
| textPrimary / textSecondary | `#1B2433` navy / `#566070` | `#E9F1EF` / `#A9B8B6` | Text |
| success / caution | `#1E7F55` / `#8A5A00` | `#7FD1A4` / `#E9B85C` | Positive / gentle notices |
| emergency | `#C62828` clear red | `#D32F2F` | Emergency and crisis cards **only** |

- The design's chip green `#089787` with white text is 3.6:1 and fails AA, so `primary` is one step deeper (`#07806F`, 4.85:1). The brighter green stays for charts.
- Green on mint is 4.4:1, so text on mint uses `primaryDark`.
- Emergency is a clear red, kept at CIEDE2000 15 or more from every green, every tint, caution and success (tested), so a safety card never looks like a normal card.
- **Shape (T-UI-02):** cards 24 dp radius with a very soft shadow (`LwShadow.soft`) and no border; buttons and inputs 16; chips and segmented tabs are pills; selected chip = solid green with a white label, unselected = soft grey.

## Logo colours (D-04, logo, splash and icon only)
| Token | Hex | Where |
|---|---|---|
| deepTeal | `#0B3A4E` | Logo background, native splash |
| lime | `#8BE03E` | Logo circle |
| cream | `#F0F8DC` | Line in the mark |
| leaf | `#FAFDF0` | Leaf in the mark |
| text on teal | `#ECF1F6` | Logo lettering, splash text |

These stay until the client approves a new logo (needs-product, D-25).

## Launch sequence (S-7, D-13)
1. **Native splash** (flutter_native_splash, config in `pubspec.yaml`): teal `#0B3A4E` + the mark at 160 dp, Android (incl. 12+) and iOS. No white flash.
2. It stays up until the logo images are decoded (`NativeSplashGate`), so the first Flutter frame shows the same mark in the same place. On Android 12+ the system splash is removed instantly (`MainActivity.kt`) instead of fading.
3. **Reveal** starts once that frame is really on screen: mark rises and shrinks, "LIVE WELL" fades in, then "Health." "Habit." "Happiness." one after another (750 ms).
4. Meanwhile Firebase and the sign-in check load (`appStartupProvider`).
5. Hold: 200 ms → **Home** (signed in, about 1.2 s total) or 950 ms → **Welcome** (new user, about 2 s). Then a 250 ms fade.
6. Reduce motion: still logo, longer hold, fade only.
7. Startup failure: calm "Try again" on teal, never a crash.
Timing markers `LW_STARTUP …` print in debug/profile builds (logcat) for measuring NFR-01.
