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
      secondary: p.accent,
      onSecondary: p.onAccent,
      secondaryContainer: p.accentTint,
      onSecondaryContainer: p.textPrimary,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
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
          foregroundColor: p.primary,
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
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primaryTint,
        labelStyle: text.labelMedium,
        side: BorderSide(color: p.outlineStrong),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: LwSpacing.xs),
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: LwRadius.mdAll,
          side: BorderSide(color: p.outlineSoft),
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
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),
      dividerTheme: DividerThemeData(
        color: p.outlineSoft,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
