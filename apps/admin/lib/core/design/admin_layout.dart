/// Layout sizes for the desktop console (not in the app's tokens, which
/// are copied unchanged from apps/mobile; see test/core/design_copy_test.dart).
abstract final class AdminLayout {
  /// Content never gets wider than this on big screens.
  static const double maxContentWidth = 1100;

  /// Sign-in and other single-column pages.
  static const double narrowPageWidth = 480;

  /// From this width, details and the card preview sit side by side.
  static const double twoColumnBreakpoint = 840;

  /// The label column of a details list.
  static const double labelColumn = 140;

  /// The signed-in person's line in the app bar.
  static const double appBarIdentity = 360;
}
