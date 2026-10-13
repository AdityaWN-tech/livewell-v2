import '../../../core/startup/app_startup.dart';

/// Timing of the "Three words" logo reveal (decision D-13).
///
/// The reveal starts on the first frame, before we know whether the user is
/// signed in, so it plays at one pace; only the hold afterwards differs:
/// signed-in users reach Home in about 1.2 s (NFR-01 budget is 2.0 s including
/// app launch), new users see the full tagline for about 2 s before Welcome.
/// With reduce-motion on there is no movement: a still logo, then a fade.
class SplashTiming {
  const SplashTiming._({
    required this.reveal,
    required this.holdHome,
    required this.holdWelcome,
  });

  static const normal = SplashTiming._(
    reveal: Duration(milliseconds: 750),
    holdHome: Duration(milliseconds: 200),
    holdWelcome: Duration(milliseconds: 950),
  );

  static const reducedMotion = SplashTiming._(
    reveal: Duration.zero,
    holdHome: Duration(milliseconds: 600),
    holdWelcome: Duration(milliseconds: 1200),
  );

  /// Cross-fade from the splash into the next screen.
  static const exitFade = Duration(milliseconds: 250);

  static SplashTiming of({required bool reduceMotion}) =>
      reduceMotion ? reducedMotion : normal;

  /// Logo settles, wordmark and the three words appear.
  final Duration reveal;
  final Duration holdHome;
  final Duration holdWelcome;

  Duration hold(StartDestination d) =>
      d == StartDestination.home ? holdHome : holdWelcome;

  /// Splash on screen until the next screen is fully visible, if startup is
  /// ready by the end of the reveal.
  Duration total(StartDestination d) => reveal + hold(d) + exitFade;
}
