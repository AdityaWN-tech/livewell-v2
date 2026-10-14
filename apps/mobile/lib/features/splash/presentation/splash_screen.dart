import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/startup/app_startup.dart';
import '../../../core/startup/startup_trace.dart';
import '../../../l10n/app_localizations.dart';
import '../application/splash_handoff.dart';
import '../domain/splash_timing.dart';

/// "Three words" logo reveal (D-13). The first frame matches the native splash
/// (teal, 160 dp mark in the centre); the logo then settles, "LIVE WELL"
/// appears and "Health. Habit. Happiness." comes in word by word, while
/// [appStartupProvider] loads in the background.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  // Cancelled on dispose so nothing fires after the splash is gone.
  Timer? _hold;
  bool _started = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final timing = SplashTiming.of(reduceMotion: reduceMotion);
    _controller.duration = timing.reveal;

    // Start loading first so it overlaps everything below. The extra listener
    // keeps an early failure from being reported as unhandled; Future.wait
    // below still sees it.
    final startup = ref.read(appStartupProvider.future);
    unawaited(startup.then((_) {}, onError: (_) {}));

    // Keep the native splash up until the logo is decoded, so the first
    // Flutter frame already shows the mark (no flicker in the hand-off).
    try {
      await ref.read(splashHandoffProvider).precache(context);
    } catch (_) {
      // A missing image must never block startup.
    }
    NativeSplashGate.release();
    if (!mounted) return;
    StartupTrace.mark('native_splash_released');

    final Future<void> reveal;
    if (reduceMotion) {
      _controller.value = 1;
      reveal = Future.value();
    } else {
      // Start once the first frame is really on screen: a slow first frame
      // would otherwise play the beginning of the reveal unseen.
      await ref.read(splashHandoffProvider).firstFrameOnScreen();
      if (!mounted) return;
      StartupTrace.mark('reveal_start');
      reveal = _controller.forward().orCancel.catchError((_) {});
    }

    try {
      final results = await Future.wait<Object?>([reveal, startup]);
      if (!mounted) return;
      final destination = results[1]! as StartDestination;
      StartupTrace.mark('reveal_done_and_startup_ready ${destination.path}');
      _hold = Timer(timing.hold(destination), () {
        if (mounted) {
          context.go(destination.path);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => StartupTrace.mark('first_screen_shown ${destination.path}'),
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    ref.invalidate(appStartupProvider);
    _controller.reset();
    unawaited(_run());
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: LwBrand.deepTeal,
        body: _failed
            ? _StartupError(onRetry: _retry)
            : Semantics(
                label: l10n.splashSemanticLabel,
                excludeSemantics: true,
                child: _Reveal(animation: _controller, l10n: l10n),
              ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.l10n});

  final Animation<double> animation;
  final AppLocalizations l10n;

  // Fractions of the reveal. Mark settles first, then the wordmark, then one
  // word after another.
  static const _settle = Interval(0, 0.45, curve: LwMotion.curve);
  static const _wordmark = Interval(0.25, 0.6, curve: LwMotion.curve);
  static const _words = [
    Interval(0.45, 0.75, curve: LwMotion.curve),
    Interval(0.6, 0.9, curve: LwMotion.curve),
    Interval(0.7, 1, curve: LwMotion.curve),
  ];

  // Final layout, relative to the screen centre.
  static const _markRise = 72.0;
  static const _markSettledScale = 0.8;
  static const _wordmarkOffset = 24.0;
  static const _wordsOffset = 64.0;
  static const _wordSlide = LwSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final words = [
      l10n.taglineHealth,
      l10n.taglineHabit,
      l10n.taglineHappiness,
    ];
    final wordStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: LwBrand.onTealText, fontWeight: FontWeight.w600);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final settle = _settle.transform(animation.value);
        final wordmark = _wordmark.transform(animation.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Transform.translate(
                offset: Offset(0, -_markRise * settle),
                child: Transform.scale(
                  scale: 1 - (1 - _markSettledScale) * settle,
                  child: Image.asset(
                    'assets/brand/logo-mark.png',
                    width: LwSize.splashMark,
                    height: LwSize.splashMark,
                  ),
                ),
              ),
            ),
            Center(
              child: Transform.translate(
                offset: Offset(
                  0,
                  _wordmarkOffset + _wordSlide * (1 - wordmark),
                ),
                child: Opacity(
                  opacity: wordmark,
                  child: Image.asset(
                    'assets/brand/wordmark.png',
                    width: LwSize.splashWordmarkWidth,
                  ),
                ),
              ),
            ),
            Center(
              child: Transform.translate(
                offset: const Offset(0, _wordsOffset),
                // Wrap, not Row: with very large text the three words go
                // onto a second line instead of overflowing (NFR-06).
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < words.length; i++)
                      Builder(
                        builder: (context) {
                          final t = _words[i].transform(animation.value);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, _wordSlide * (1 - t)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: LwSpacing.xxs,
                                ),
                                child: Text(words[i], style: wordStyle),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.startupErrorTitle,
              textAlign: TextAlign.center,
              style: t.titleLarge?.copyWith(color: LwBrand.onTealText),
            ),
            const SizedBox(height: LwSpacing.xs),
            Text(
              l10n.startupErrorBody,
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: LwBrand.onTealText),
            ),
            const SizedBox(height: LwSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LwBrand.lime,
                foregroundColor: LwBrand.deepTeal,
              ),
              onPressed: onRetry,
              child: Text(l10n.startupErrorRetry),
            ),
          ],
        ),
      ),
    );
  }
}
