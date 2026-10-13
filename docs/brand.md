# Brand

## Logo (provisional redraw, D-15)
Redrawn in code from the logo in `apps/mobile/assets/design-reference/portal-login.jpeg` by `apps/mobile/tool/draw_logo.py`
(run `python tool/draw_logo.py` from `apps/mobile`). Outputs in `apps/mobile/assets/brand/`:

| File | Use |
|---|---|
| `logo.png` | Full lockup, 1024 px: teal rounded square, lime mark, "LIVE WELL", "Health. Habit. Happiness." |
| `logo-mark.png` | Lime circle mark only, 1024 px, transparent corners (splash, app icon) |
| `logo-mark.svg` | Same mark as a vector |

Fonts in the redraw: Times New Roman (title) and Arial Bold (tagline), the closest fonts on this PC to the reference.
When the client's original artwork and font names arrive, replace these files and keep the same names.

## Design tokens (apps/mobile/lib/core/design/)
Feature code uses only these; `test/design/tokens_test.dart` fails the build on raw colours outside `core/design`
and checks every text/background pair for WCAG 2.2 AA in light and dark.

| File | Contents |
|---|---|
| `tokens.dart` | `LwBrand` (logo colours), `LwPalette` light/dark (semantic colours, via `LwPalette.of(context)`), `LwSpacing`, `LwRadius`, `LwSize`, `LwMotion` |
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

## Colours (from the logo)
| Token | Hex | Where |
|---|---|---|
| deepTeal | `#0B3A4E` | Logo background, primary |
| lime | `#8BE03E` | Logo circle, accent |
| cream | `#F0F8DC` | Line in the mark |
| leaf | `#FAFDF0` | Leaf in the mark |
| text on teal | `#ECF1F6` | Logo lettering |

Semantic light palette: background `#F4F6F5`, surface `#FFFFFF`, textPrimary `#14232B`, textSecondary `#55646B`,
primaryTint `#E2EDF0`, accentTint `#EEF9E2`, outlineSoft `#E3E8E7`, outlineStrong `#8A979C`, success `#2F6B12`,
caution `#9A5B00`, emergency `#B3261E`. Dark palette: lime becomes primary on `#0A1A22` / `#12262F`.
