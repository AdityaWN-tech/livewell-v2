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
| `tokens.dart` | `LwBrand` (logo + app colours), `LwPalette` light/dark (semantic colours, via `LwPalette.of(context)`), `LwSpacing`, `LwRadius`, `LwSize`, `LwMotion` |
| `typography.dart` | `LwType`: Poppins type scale |
| `theme.dart` | `LwTheme.light()` / `.dark()`: Material theme built from the tokens (buttons, inputs, chips, cards, sheets, nav bar) |

- **Font:** Poppins (the reference screens' font), bundled in `assets/fonts/poppins` (SIL OFL). Body 16, subtitles 16 grey, titles 24 semibold, display 28, meta 12.
- **Spacing:** 4-point scale `xxs 4 · xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48`; screen gutter 16.
- **Radius:** `sm 8` tags · `md 12` buttons, inputs, cards · `lg 20` sheets · `pill` chips. Slightly rounder than the references for warmth.
- **Sizes:** tap targets 48+, buttons 52 high, inputs 56, chips 36.
- **Style taken from the references:** white cards with a soft 1 px outline on a light grey background, pill chips with outline, selected state as a soft tint (not a solid fill), bold left-aligned screen titles.
- **Kindness rule:** `emergency` red is only for emergency and crisis cards; everyday notices use `caution` amber.
- **Motion:** 150 / 250 / 400 ms, ease-out; `LwMotion.duration()` returns zero when reduce-motion is on.
- **Review on a phone:** the dev flavor opens a "Design tokens" gallery (`lib/features/dev/`).

## App colours (T-UI-01, D-25)
From the "Live Well Companion" mockup (`docs/design/screen.png`). Exact values and every contrast pair: `tokens.dart` and `test/design/tokens_test.dart`.

| Token | Light | Dark | Where |
|---|---|---|---|
| primary | `#1E3834` Forest Slate | `#A9D3C9` | Headings, selected icons, focus ring, outlined buttons |
| primaryTint | `#E1ECEB` Sage-Mint | `#24403B` | Nav indicator, selected chips, quiet cards |
| accent | `#D97457` Terracotta | `#D97457` | **Decorative only**: dots, icons, progress (3:1, not 4.5:1) |
| accentStrong | `#B05A3B` | `#E58C70` | Filled buttons (white / dark label), text links |
| accentTint | `#FCEFEA` | `#3A2620` | Soft highlight backgrounds |
| heroSurface | `#1E3834` | `#1E3834` | Dark hero cards (today's step, coach bubble, portal card) |
| background / surface | `#F8FAF9` / `#FFFFFF` | `#0E1B19` / `#162724` | Screens / cards |
| textPrimary / textSecondary | `#1E3834` / `#566864` | `#E8EFED` / `#A7B7B3` | Text |
| success / caution | `#2B734E` / `#835A00` | `#7FD1A4` / `#E9B85C` | Positive / gentle notices |
| emergency | `#A50E1E` | `#B3131F` | Emergency and crisis cards **only** |

- Plain terracotta with white text is 3.2:1 and fails AA, so buttons use `accentStrong`.
- Emergency is a true crimson, kept at CIEDE2000 15 or more from both terracottas (tested), so a safety card never looks like a normal button.

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
