import 'package:flutter/material.dart';

/// Live Well design tokens. Feature code uses only these (via [LwPalette.of],
/// `Theme.of(context).textTheme`, [LwSpacing], [LwRadius], [LwSize], [LwMotion]);
/// raw colours and magic numbers are not allowed outside lib/core/design/.
///
/// Sources: app colours from the T-UI-01 mockup (docs/design/screen.png, D-25),
/// logo colours from docs/brand.md; layout,
/// type scale and component style measured from the portal reference screens
/// (assets/design-reference/); feel per spec 14.1 (warm, hopeful, calm, premium).

/// Raw brand colours. Use [LwPalette] in widgets; these feed the palettes.
abstract final class LwBrand {
  // Logo colours. The logo, splash and launcher icon keep these until the
  // client approves a new logo (T-UI-01, needs-product).
  static const deepTeal = Color(0xFF0B3A4E);
  static const lime = Color(0xFF8BE03E);
  static const cream = Color(0xFFF0F8DC);
  static const leaf = Color(0xFFFAFDF0);
  static const onTealText = Color(0xFFECF1F6);

  // "Live Well Companion" app palette (T-UI-01, D-25; replaces D-04 in the app).
  static const terracotta = Color(0xFFD97457);
  static const forestSlate = Color(0xFF1E3834);
  static const sageMint = Color(0xFFE1ECEB);

  /// Darker terracotta for button fills and text: white on it is 4.8:1
  /// (white on [terracotta] is only 3.2:1).
  static const terracottaStrong = Color(0xFFB05A3B);
}

/// Semantic colours for one brightness. Contrast is checked in
/// test/design/tokens_test.dart (WCAG 2.2 AA, NFR-06).
@immutable
class LwPalette extends ThemeExtension<LwPalette> {
  const LwPalette({
    required this.primary,
    required this.onPrimary,
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
    required this.background,
    required this.surface,
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

  /// Forest Slate: headings, selected icons, focus rings, outlined buttons.
  final Color primary;
  final Color onPrimary;

  /// Sage-Mint: soft selected state (nav indicator, chips, quiet cards).
  final Color primaryTint;
  final Color onPrimaryTint;

  /// Terracotta as in the mockup. Decorative only (dots, icons, progress,
  /// large shapes): it reaches 3:1, not 4.5:1, so never put text on it or
  /// use it as text. Use [accentStrong] for that.
  final Color accent;

  /// The primary action colour: filled buttons, text links.
  final Color accentStrong;
  final Color onAccentStrong;

  /// Pale terracotta background for highlights.
  final Color accentTint;
  final Color onAccentTint;

  /// The dark forest "hero" card (Today's one step, coach bubble, portal card).
  final Color heroSurface;
  final Color onHeroSurface;
  final Color onHeroSurfaceSecondary;

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  /// Decorative card and divider lines.
  final Color outlineSoft;

  /// Input borders and other UI boundaries that must reach 3:1.
  final Color outlineStrong;

  /// Positive text and icons.
  final Color success;

  /// Gentle notices. Kindness rule (spec 4.1): no red for everyday things.
  final Color caution;

  /// Reserved for emergency and crisis cards only (FR-SAF-01/02). A true
  /// crimson, kept far from terracotta (CIEDE2000 15 or more, tested) so a
  /// safety card never looks like a normal button.
  final Color emergency;
  final Color onEmergency;

  static const light = LwPalette(
    primary: LwBrand.forestSlate,
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: LwBrand.sageMint,
    onPrimaryTint: LwBrand.forestSlate,
    accent: LwBrand.terracotta,
    accentStrong: LwBrand.terracottaStrong,
    onAccentStrong: Color(0xFFFFFFFF),
    accentTint: Color(0xFFFCEFEA),
    onAccentTint: LwBrand.forestSlate,
    heroSurface: LwBrand.forestSlate,
    onHeroSurface: Color(0xFFFFFFFF),
    onHeroSurfaceSecondary: Color(0xFFC9D8D4),
    background: Color(0xFFF8FAF9),
    surface: Color(0xFFFFFFFF),
    textPrimary: LwBrand.forestSlate,
    textSecondary: Color(0xFF566864),
    textDisabled: Color(0xFF8A9A96),
    outlineSoft: Color(0xFFE3EAE8),
    outlineStrong: Color(0xFF83918C),
    success: Color(0xFF2B734E),
    caution: Color(0xFF835A00),
    emergency: Color(0xFFA50E1E),
    onEmergency: Color(0xFFFFFFFF),
  );

  static const dark = LwPalette(
    primary: Color(0xFFA9D3C9),
    onPrimary: LwBrand.forestSlate,
    primaryTint: Color(0xFF24403B),
    onPrimaryTint: LwBrand.sageMint,
    accent: LwBrand.terracotta,
    accentStrong: Color(0xFFE58C70),
    onAccentStrong: Color(0xFF13201E),
    accentTint: Color(0xFF3A2620),
    onAccentTint: Color(0xFFE8EFED),
    heroSurface: LwBrand.forestSlate,
    onHeroSurface: Color(0xFFFFFFFF),
    onHeroSurfaceSecondary: Color(0xFFC9D8D4),
    background: Color(0xFF0E1B19),
    surface: Color(0xFF162724),
    textPrimary: Color(0xFFE8EFED),
    textSecondary: Color(0xFFA7B7B3),
    textDisabled: Color(0xFF6E827D),
    outlineSoft: Color(0xFF263B37),
    outlineStrong: Color(0xFF74877F),
    success: Color(0xFF7FD1A4),
    caution: Color(0xFFE9B85C),
    emergency: Color(0xFFB3131F),
    onEmergency: Color(0xFFFFFFFF),
  );

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

/// Corner radii. Slightly rounder than the references for a warmer feel.
abstract final class LwRadius {
  static const double sm = 8; // badges, small tags
  static const double md = 12; // buttons, inputs, cards
  static const double lg = 20; // bottom sheets, hero cards
  static const double pill = 999; // chips, segmented tabs

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
