import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/speech_bubble.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/presentation/coach_avatar.dart'
    show avatarIdleMotionProvider, coachBackgroundProvider, coachImagesProvider;
import '../application/coach_state.dart';
import '../application/moment_context.dart';
import '../data/coach_speaker.dart';
import '../domain/coach_message.dart';
import '../domain/moment_builder.dart';

/// The Done celebration (T-DLY-03d): the coach celebrates for about 3
/// seconds with falling leaves and says the step-done line, or the
/// milestone line on 7, 14 and 30 days in a row (T-AVT-08f). A tap skips
/// it; silent when the coach is muted, on a safety hold, or before the
/// lines are approved (then it just shows "You did it!").
Future<void> showCelebration(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: LwPalette.of(context).background.withValues(alpha: 0.94),
  transitionDuration: LwMotion.duration(context, LwMotion.medium),
  pageBuilder: (context, _, _) => const Celebration(),
);

class Celebration extends ConsumerStatefulWidget {
  const Celebration({super.key});

  /// How long the leaves fall; the voice may run a little longer.
  static const length = Duration(milliseconds: 2800);

  /// Never longer than this, even if the voice doesn't report its end.
  static const longest = Duration(seconds: 8);

  @override
  ConsumerState<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends ConsumerState<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _leaves = AnimationController(
    vsync: this,
    duration: Celebration.length,
  );
  late final CoachSpeaker _speaker;
  Timer? _minimum;
  Timer? _cap;
  CoachMessage? _message;
  bool _shownLongEnough = false;
  bool _speaking = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(coachSpeakerProvider);
    _minimum = Timer(Celebration.length, () {
      _shownLongEnough = true;
      if (!_speaking) _close();
    });
    _cap = Timer(Celebration.longest, _close);
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_leaves.isAnimating) {
      _leaves.forward(from: 0);
    }
  }

  Future<void> _start() async {
    CoachMessage? m;
    try {
      final moment = MomentBuilder.afterDone(
        streakDays: ref.read(momentContextProvider).streakDays,
      );
      m = await ref.read(coachMessageProvider(moment).future);
    } catch (_) {
      m = null;
    }
    if (!mounted || _closed) return;
    setState(() => _message = m);
    if (m == null || ref.read(coachMutedProvider)) return;
    final speed = await ref.read(coachVoiceSpeedProvider.future);
    if (!mounted || _closed) return;
    _speaking = true;
    final ok = await _speaker.speak(
      m,
      speed: speed,
      onDone: () {
        _speaking = false;
        if (_shownLongEnough) _close();
      },
    );
    if (!ok) _speaking = false;
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _speaker.stop();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _minimum?.cancel();
    _cap?.cancel();
    _leaves.dispose();
    if (_speaking) _speaker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final text = _message?.text ?? l.celebrationDone;
    return Semantics(
      button: true,
      label: text,
      hint: l.celebrationSkip,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('celebration'),
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LeavesPainter(_leaves, [
                  p.primary,
                  p.mint,
                  p.lime,
                  p.butter,
                  p.peach,
                  p.sky,
                ]),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(LwSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: SpeechBubble(
                          key: const Key('celebration-text'),
                          text: text,
                          tail: BubbleTail.bottom,
                        ),
                      ),
                      const SizedBox(height: LwSpacing.md),
                      AvatarView(
                        key: const Key('celebration-avatar'),
                        images: ref.watch(coachImagesProvider).value,
                        background: ref.watch(coachBackgroundProvider),
                        animate: ref.watch(avatarIdleMotionProvider),
                        expression: AvatarExpression.celebrating,
                        size: 180,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaves drifting down: small two-point leaf shapes, gently turning. With
/// reduced motion they rest where they are (the controller doesn't run).
class _LeavesPainter extends CustomPainter {
  _LeavesPainter(this.t, this.colours) : super(repaint: t);

  final Animation<double> t;
  final List<Color> colours;

  static final _leaves = [
    for (var i = 0, r = math.Random(7); i < 22; i++)
      (x: r.nextDouble(), y: r.nextDouble(), spin: r.nextDouble() * 2 - 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.isDismissed ? 0.5 : t.value;
    for (final (i, leaf) in _leaves.indexed) {
      final y = ((leaf.y - 1 + v * 1.4) % 1.2) * size.height;
      final x = leaf.x * size.width + math.sin((v * 4 + leaf.y) * math.pi) * 14;
      final paint = Paint()
        ..color = colours[i % colours.length].withValues(
          // Fade out over the last fifth, so it ends calmly.
          alpha: t.isDismissed ? 1 : ((1 - v) * 5).clamp(0.0, 1.0),
        );
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(leaf.spin * math.pi * (1 + v));
      canvas.drawPath(
        Path()
          ..moveTo(0, -9)
          ..quadraticBezierTo(7, 0, 0, 9)
          ..quadraticBezierTo(-7, 0, 0, -9),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeavesPainter old) => false;
}
