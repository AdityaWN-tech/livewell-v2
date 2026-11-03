import 'package:flutter/material.dart';

/// Live Well design tokens. Feature code uses only these (via [LwPalette.of],
/// `Theme.of(context).textTheme`, [LwSpacing], [LwRadius], [LwSize], [LwMotion]);
/// raw colours and magic numbers are not allowed outside lib/core/design/.
///
/// Sources: app colours from the T-UI-02 illustrated design (D-33),
/// logo colours from docs/brand.md; layout,
/// type scale and component style measured from the portal reference screens
/// (assets/design-reference/); feel per spec 14.1 (warm, hopeful, calm, premium).

/// Raw brand colours. Use [LwPalette] in widgets; these feed the palettes.
abstract final class LwBrand {
  // Logo colours. The logo, splash and launcher icon keep these until the
  // client approves the new leaf logo (T-UI-02, needs-product).
  static const deepTeal = Color(0xFF0B3A4E);
  static const lime = Color(0xFF8BE03E);
  static const cream = Color(0xFFF0F8DC);
  static const leaf = Color(0xFFFAFDF0);
  static const onTealText = Color(0xFFECF1F6);

  // Illustrated "Live Well v2" palette (T-UI-02, D-33; replaces T-UI-01's
  // terracotta). Sampled from docs/design/live-well-v2-illustrated.png.
  /// The design's chip green is #089787; white on it is only 3.6:1, so
  /// buttons and selected chips use this slightly deeper green (4.9:1).
  static const green = Color(0xFF07806F);

  /// Bright green for charts, progress and decoration only (3.4:1).
  static const greenBright = Color(0xFF1E9E70);
  static const greenDark = Color(0xFF0B5E52);
  static const navy = Color(0xFF1B2433);
}

/// A soft drop shadow for cards (T-UI-02: very soft shadows, no heavy
/// borders).
abstract final class LwShadow {
  static const soft = [
    BoxShadow(color: Color(0x14172A3A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const softDark = [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? softDark : soft;
}

/// Semantic colours for one brightness. Contrast is checked in
/// test/design/tokens_test.dart (WCAG 2.2 AA, NFR-06).
@immutable
class LwPalette extends ThemeExtension<LwPalette> {
  const LwPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryTint,
    required this.onPrimaryTint,
    required this.accent,
    required this.accentStrong,
    required this.onAccentStrong,
    required this.accentTint,
    required this.onAccentTint,
    required this.heroSurface,
    required this.onHeroSurface,
    required this.onHeroSurfaceSecondary,
    required this.mint,
    required this.lime,
    required this.lavender,
    required this.peach,
    required this.sky,
    required this.butter,
    required this.rose,
    required this.onTint,
    required this.onTintSecondary,
    required this.background,
    required this.washTop,
    required this.washBottom,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.outlineSoft,
    required this.outlineStrong,
    required this.success,
    required this.caution,
    required this.emergency,
    required this.onEmergency,
  });

  /// Fresh green: selected chips, active tab, main buttons, focus rings.
  final Color primary;
  final Color onPrimary;

  /// Deep green: text and icons on green tints.
  final Color primaryDark;

  /// Mint: soft selected state (nav indicator, quiet cards).
  final Color primaryTint;
  final Color onPrimaryTint;

  /// Bright green for charts, progress bars and small decoration. It
  /// reaches 3:1, not 4.5:1: never text, and never text on it.
  final Color accent;

  /// The main action colour: filled buttons, text links.
  final Color accentStrong;
  final Color onAccentStrong;

  /// Butter highlight background.
  final Color accentTint;
  final Color onAccentTint;

  /// The featured card (Today's next step, portal card, coach bubble): a
  /// soft lime pastel with dark text in the illustrated design.
  final Color heroSurface;
  final Color onHeroSurface;
  final Color onHeroSurfaceSecondary;

  /// Category card fills (steps = mint, sleep = lavender, mood = butter,
  /// stress = sky, ...). Text on them is always [onTint] /
  /// [onTintSecondary].
  final Color mint;
  final Color lime;
  final Color lavender;
  final Color peach;
  final Color sky;
  final Color butter;
  final Color rose;
  final Color onTint;
  final Color onTintSecondary;

  /// Screen colour; [washTop] to [washBottom] is the mint-to-sky wash.
  final Color background;
  final Color washTop;
  final Color washBottom;

  /// White cards.
  final Color surface;

  /// Grey chips and quiet fills.
  final Color surfaceMuted;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  /// Decorative divider lines.
  final Color outlineSoft;

  /// Input borders and other UI boundaries that must reach 3:1.
  final Color outlineStrong;

  /// Positive text and icons.
  final Color success;

  /// Gentle notices. Kindness rule (spec 4.1): no red for everyday things.
  final Color caution;

  /// Reserved for emergency and crisis cards only (FR-SAF-01/02): a clear
  /// red, never a pastel, far from every other colour (tested).
  final Color emergency;
  final Color onEmergency;

  /// The 7 pastel category fills, in a fixed order.
  List<Color> get tints => [mint, lime, lavender, peach, sky, butter, rose];

  static const light = LwPalette(
    primary: LwBrand.green,
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: LwBrand.greenDark,
    primaryTint: Color(0xFFE8F9EE),
    onPrimaryTint: LwBrand.greenDark,
    accent: LwBrand.greenBright,
    accentStrong: LwBrand.green,
    onAccentStrong: Color(0xFFFFFFFF),
    accentTint: Color(0xFFFEF6DD),
    onAccentTint: LwBrand.navy,
    heroSurface: Color(0xFFF3F7C4),
    onHeroSurface: LwBrand.navy,
    onHeroSurfaceSecondary: Color(0xFF4F5868),
    mint: Color(0xFFE8F9EE),
    lime: Color(0xFFF3F7C4),
    lavender: Color(0xFFF3EFFE),
    peach: Color(0xFFFEEBDF),
    sky: Color(0xFFEBF5FE),
    butter: Color(0xFFFEF6DD),
    rose: Color(0xFFFFE3EC),
    onTint: LwBrand.navy,
    onTintSecondary: Color(0xFF4F5868),
    background: Color(0xFFF4FBF8),
    washTop: Color(0xFFF0FAF7),
    washBottom: Color(0xFFF3F8FD),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F4F6),
    textPrimary: LwBrand.navy,
    textSecondary: Color(0xFF566070),
    textDisabled: Color(0xFF8C94A3),
    outlineSoft: Color(0xFFE6EAF0),
    outlineStrong: Color(0xFF7F8A9A),
    success: Color(0xFF1E7F55),
    caution: Color(0xFF8A5A00),
    emergency: Color(0xFFC62828),
    onEmergency: Color(0xFFFFFFFF),
  );

  static const dark = LwPalette(
    primary: Color(0xFF4CC9A4),
    onPrimary: Color(0xFF08201B),
    primaryDark: Color(0xFFBFF0DF),
    primaryTint: Color(0xFF1C3A33),
    onPrimaryTint: Color(0xFFBFF0DF),
    accent: Color(0xFF3DBB96),
    accentStrong: Color(0xFF4CC9A4),
    onAccentStrong: Color(0xFF08201B),
    accentTint: Color(0xFF3A3320),
    onAccentTint: Color(0xFFE9F1EF),
    heroSurface: Color(0xFF2A2F1A),
    onHeroSurface: Color(0xFFE9F1EF),
    onHeroSurfaceSecondary: Color(0xFFB9C4C2),
    mint: Color(0xFF1C3A33),
    lime: Color(0xFF2A2F1A),
    lavender: Color(0xFF272240),
    peach: Color(0xFF3A2A22),
    sky: Color(0xFF1A2E3E),
    butter: Color(0xFF3A3320),
    rose: Color(0xFF3A2230),
    onTint: Color(0xFFE9F1EF),
    onTintSecondary: Color(0xFFB9C4C2),
    background: Color(0xFF0D1A1C),
    washTop: Color(0xFF0F2022),
    washBottom: Color(0xFF0D1824),
    surface: Color(0xFF152528),
    surfaceMuted: Color(0xFF1F2C2F),
    textPrimary: Color(0xFFE9F1EF),
    textSecondary: Color(0xFFA9B8B6),
    textDisabled: Color(0xFF6E8287),
    outlineSoft: Color(0xFF243538),
    outlineStrong: Color(0xFF71858A),
    success: Color(0xFF7FD1A4),
    caution: Color(0xFFE9B85C),
    emergency: Color(0xFFD32F2F),
    onEmergency: Color(0xFFFFFFFF),
  );

  /// A richer shade of a pastel tint, for chart bars and filled segments:
  /// more colour, a little darker in light mode and lighter in dark mode,
  /// so the hue stays recognisable (never colour alone: charts are also
  /// labelled).
  static Color richer(Color tint) {
    final hsl = HSLColor.fromColor(tint);
    final light = hsl.lightness > 0.5;
    return hsl
        .withSaturation(
          (hsl.saturation + (light ? 0.05 : 0.3)).clamp(0, 1).toDouble(),
        )
        .withLightness(
          (hsl.lightness + (light ? -0.13 : 0.14)).clamp(0, 1).toDouble(),
        )
        .toColor();
  }

  static LwPalette of(BuildContext context) =>
      Theme.of(context).extension<LwPalette>()!;

  @override
  LwPalette copyWith() => this;

  @override
  LwPalette lerp(LwPalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// 4-point spacing scale. Screen gutters are 16, matching the references.
abstract final class LwSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double screenGutter = md;
  static const double cardPadding = md;
  static const double sectionGap = lg;
}

/// Corner radii (T-UI-02): big friendly cards, pill chips.
abstract final class LwRadius {
  static const double sm = 8; // badges, small tags
  static const double md = 16; // buttons, inputs
  static const double lg = 24; // cards, sheets, hero cards
  static const double pill = 999; // chips, segmented tabs, pills

  static const double card = lg;
  static const double button = md;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Component sizes. Tap targets are 48 or more (NFR-06 asks 44 pt or more).
abstract final class LwSize {
  static const double minTapTarget = 48;
  static const double buttonHeight = 52;
  static const double inputHeight = 56;
  static const double chipHeight = 36;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double avatarSm = 40;

  /// Logo mark on the splash. Must equal the native splash image
  /// (640 px at 4x in assets/brand/splash/), so the hand-off doesn't jump.
  static const double splashMark = 160;
  static const double splashWordmarkWidth = 200;
}

/// Motion. Calm, never bouncy. Use [LwMotion.duration] so reduce-motion is respected.
abstract final class LwMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  /// Zero when the OS reduce-motion setting is on (FR-AVT-06, NFR-06).
  static Duration duration(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
