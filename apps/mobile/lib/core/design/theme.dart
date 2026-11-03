import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Builds the app theme from the tokens, so Material widgets pick up the
/// Live Well look without per-widget styling.
abstract final class LwTheme {
  static ThemeData light() => _build(LwPalette.light, Brightness.light);
  static ThemeData dark() => _build(LwPalette.dark, Brightness.dark);

  static ThemeData _build(LwPalette p, Brightness brightness) {
    final text = LwType.textTheme(p.textPrimary, p.textSecondary);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryTint,
      onPrimaryContainer: p.onPrimaryTint,
      secondary: p.accentStrong,
      onSecondary: p.onAccentStrong,
      secondaryContainer: p.accentTint,
      onSecondaryContainer: p.onAccentTint,
      tertiary: p.accent,
      onTertiary: p.textPrimary,
      inverseSurface: p.heroSurface,
      onInverseSurface: p.onHeroSurface,
      error: p.emergency,
      onError: p.onEmergency,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      outline: p.outlineStrong,
      outlineVariant: p.outlineSoft,
    );
    const buttonShape = RoundedRectangleBorder(borderRadius: LwRadius.mdAll);
    const buttonSize = Size(LwSize.minTapTarget, LwSize.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: LwSpacing.lg);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: LwType.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      // Primary action: fresh green (T-UI-02). The design's brighter green
      // fails AA with a white label, so this is one step deeper.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accentStrong,
          foregroundColor: p.onAccentStrong,
          disabledBackgroundColor: p.outlineSoft,
          disabledForegroundColor: p.textDisabled,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.outlineStrong),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentStrong,
          minimumSize: const Size(LwSize.minTapTarget, LwSize.minTapTarget),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LwSpacing.md,
          vertical: LwSpacing.md,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: p.textDisabled),
        labelStyle: text.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: LwRadius.mdAll,
          borderSide: BorderSide(color: p.outlineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LwRadius.mdAll,
          borderSide: BorderSide(color: p.outlineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LwRadius.mdAll,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
      // Pill chips (T-UI-02): selected is solid green with a white label,
      // unselected is soft grey.
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceMuted,
        ),
        labelStyle: text.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: p.textPrimary, size: 18),
        checkmarkColor: p.onPrimary,
        side: WidgetStateBorderSide.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? BorderSide(color: p.primary)
              : BorderSide(color: p.outlineSoft),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: LwSpacing.xs),
        showCheckmark: false,
      ),
      // Segmented tabs match selected chips: solid green pill.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.primary : p.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary,
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: p.outlineStrong)),
          minimumSize: const WidgetStatePropertyAll(
            Size(LwSize.minTapTarget, LwSize.minTapTarget),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      // Big friendly cards with a very soft shadow, no heavy border.
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: brightness == Brightness.light ? 1 : 0,
        shadowColor: LwShadow.soft.first.color,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: LwRadius.lgAll,
          side: brightness == Brightness.light
              ? BorderSide.none
              : BorderSide(color: p.outlineSoft),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LwRadius.lg),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primaryTint,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? p.onPrimaryTint
                : p.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected)
                ? p.onPrimaryTint
                : p.textSecondary,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : null,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.outlineSoft,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
