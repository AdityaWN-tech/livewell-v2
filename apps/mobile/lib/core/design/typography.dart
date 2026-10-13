import 'package:flutter/material.dart';

/// Type scale (Poppins, from the reference screens). Body text is 16 so it stays
/// comfortable for older users (spec persona Robert); sizes scale with the OS
/// text size setting (NFR-06) because Flutter applies the user's text scaler.
abstract final class LwType {
  static const fontFamily = 'Poppins';

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    // Welcome / sign-in titles ("Login to LIVE WELL").
    displaySmall: _s(28, 36, FontWeight.w600, primary),
    // Tab and screen titles ("Courses", "Workshops").
    headlineSmall: _s(24, 32, FontWeight.w600, primary),
    // Card titles.
    titleLarge: _s(18, 26, FontWeight.w600, primary),
    titleMedium: _s(16, 24, FontWeight.w500, primary),
    titleSmall: _s(14, 20, FontWeight.w600, primary),
    bodyLarge: _s(16, 24, FontWeight.w400, primary),
    // Subtitles ("Welcome back! Please enter your details.").
    bodyMedium: _s(16, 24, FontWeight.w400, secondary),
    bodySmall: _s(14, 20, FontWeight.w400, secondary),
    // Buttons, chips, tabs.
    labelLarge: _s(16, 24, FontWeight.w600, primary),
    labelMedium: _s(14, 20, FontWeight.w500, primary),
    // Meta lines ("8 sections · 50 lectures").
    labelSmall: _s(12, 16, FontWeight.w500, secondary),
  );

  static TextStyle _s(
    double size,
    double height,
    FontWeight weight,
    Color color,
  ) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0,
  );
}
