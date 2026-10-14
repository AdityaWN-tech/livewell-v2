import 'package:flutter/material.dart';

/// Live Well design tokens. Feature code uses only these (via [LwPalette.of],
/// `Theme.of(context).textTheme`, [LwSpacing], [LwRadius], [LwSize], [LwMotion]);
/// raw colours and magic numbers are not allowed outside lib/core/design/.
///
/// Sources: brand colours from the Live Well logo (docs/brand.md); layout,
/// type scale and component style measured from the portal reference screens
/// (assets/design-reference/); feel per spec 14.1 (warm, hopeful, calm, premium).

/// Raw brand colours. Use [LwPalette] in widgets; these feed the palettes.
abstract final class LwBrand {
  static const deepTeal = Color(0xFF0B3A4E);
  static const lime = Color(0xFF8BE03E);
  static const cream = Color(0xFFF0F8DC);
  static const leaf = Color(0xFFFAFDF0);
  static const onTealText = Color(0xFFECF1F6);
}

/// Semantic colours for one brightness. Contrast is checked in
/// test/design/contrast_test.dart (WCAG 2.2 AA, NFR-06).
@immutable
class LwPalette extends ThemeExtension<LwPalette> {
  const LwPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryTint,
    required this.onPrimaryTint,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
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

  /// Brand teal: primary buttons, links, selected icons.
  final Color primary;
  final Color onPrimary;

  /// Soft selected state (chips, tabs), like the reference's tinted "Upcoming" tab.
  final Color primaryTint;
  final Color onPrimaryTint;

  /// Lime: celebrations, progress, streaks. Never used as text on light surfaces.
  final Color accent;
  final Color onAccent;
  final Color accentTint;

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  /// Decorative card and divider lines.
  final Color outlineSoft;

  /// Input borders and other UI boundaries that must reach 3:1.
  final Color outlineStrong;

  /// Positive text and icons (lime is too light for text).
  final Color success;

  /// Gentle notices. Kindness rule (spec 4.1): no red for everyday things.
  final Color caution;

  /// Reserved for emergency and crisis cards only (FR-SAF-01/02).
  final Color emergency;
  final Color onEmergency;

  static const light = LwPalette(
    primary: LwBrand.deepTeal,
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: Color(0xFFE2EDF0),
    onPrimaryTint: LwBrand.deepTeal,
    accent: LwBrand.lime,
    onAccent: LwBrand.deepTeal,
    accentTint: Color(0xFFEEF9E2),
    background: Color(0xFFF4F6F5),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14232B),
    textSecondary: Color(0xFF55646B),
    textDisabled: Color(0xFF8A979C),
    outlineSoft: Color(0xFFE3E8E7),
    outlineStrong: Color(0xFF8A979C),
    success: Color(0xFF2F6B12),
    caution: Color(0xFF9A5B00),
    emergency: Color(0xFFB3261E),
    onEmergency: Color(0xFFFFFFFF),
  );

  static const dark = LwPalette(
    primary: LwBrand.lime,
    onPrimary: LwBrand.deepTeal,
    primaryTint: Color(0xFF1C3A2A),
    onPrimaryTint: LwBrand.lime,
    accent: LwBrand.lime,
    onAccent: LwBrand.deepTeal,
    accentTint: Color(0xFF1C3A2A),
    background: Color(0xFF0A1A22),
    surface: Color(0xFF12262F),
    textPrimary: Color(0xFFEAF0F2),
    textSecondary: Color(0xFFA9B8BE),
    textDisabled: Color(0xFF6F8189),
    outlineSoft: Color(0xFF243B45),
    outlineStrong: Color(0xFF7D9099),
    success: Color(0xFF9FE36A),
    caution: Color(0xFFF2B866),
    emergency: Color(0xFFB3261E),
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
