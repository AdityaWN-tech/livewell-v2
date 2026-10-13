import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hand-off from the native splash to the Flutter splash without a flicker:
/// the native splash stays up until the logo images are decoded, so the first
/// Flutter frame already shows the mark exactly where the native one was.
abstract final class NativeSplashGate {
  static bool _preserved = false;

  /// Call in bootstrap, before runApp.
  static void preserve(WidgetsBinding binding) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    _preserved = true;
  }

  /// Safe to call more than once, and a no-op when never preserved (tests).
  static void release() {
    if (!_preserved) return;
    _preserved = false;
    FlutterNativeSplash.remove();
  }
}

const splashImages = [
  AssetImage('assets/brand/logo-mark.png'),
  AssetImage('assets/brand/wordmark.png'),
];

/// Engine-facing steps of the hand-off. Replaced with [SplashHandoff.instant]
/// in widget tests, where real image decoding and rasterizing don't run under
/// fake time.
class SplashHandoff {
  const SplashHandoff({
    required this.precache,
    required this.firstFrameOnScreen,
  });

  /// Decodes the splash images.
  final Future<void> Function(BuildContext context) precache;

  /// Completes once the first Flutter frame is actually on screen (not just
  /// built). Starting the reveal earlier lets a slow first frame hide it.
  final Future<void> Function() firstFrameOnScreen;

  static final engine = SplashHandoff(
    precache: (context) => Future.wait([
      for (final image in splashImages) precacheImage(image, context),
    ]),
    firstFrameOnScreen: () async {
      await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
      await WidgetsBinding.instance.endOfFrame;
    },
  );

  static final instant = SplashHandoff(
    precache: (_) async {},
    firstFrameOnScreen: () => WidgetsBinding.instance.endOfFrame,
  );
}

final splashHandoffProvider = Provider<SplashHandoff>(
  (ref) => SplashHandoff.engine,
);
