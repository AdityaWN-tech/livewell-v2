import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../features/avatar/domain/avatar_frames.dart';
import '../../../features/avatar/domain/coach_face.dart';

export '../../../features/avatar/domain/avatar_frames.dart' show AvatarFrame;
export '../../../features/avatar/domain/coach_face.dart' show MouthShape;

/// The coach's face and pose (T-UI-02b). Safety replies always use [calm].
enum AvatarExpression { happy, waving, talking, listening, calm, celebrating }

/// The coach's frame set, ready to show (T-AVT-08a): an image for each
/// frame. [neutralOnly] means only the neutral frame could be loaded (the
/// second step of the fallback chain); every frame then shows it.
class AvatarImages {
  const AvatarImages(this.frames, {this.neutralOnly = false});

  /// Only the neutral face, for every frame.
  factory AvatarImages.neutral(ImageProvider neutral) =>
      AvatarImages({AvatarFrame.neutral: neutral}, neutralOnly: true);

  final Map<AvatarFrame, ImageProvider> frames;
  final bool neutralOnly;

  ImageProvider? operator [](AvatarFrame f) =>
      frames[f] ?? frames[AvatarFrame.neutral];

  @override
  bool operator ==(Object other) =>
      other is AvatarImages &&
      other.neutralOnly == neutralOnly &&
      other.frames.length == frames.length &&
      other.frames.entries.every((e) => frames[e.key] == e.value);

  @override
  int get hashCode =>
      Object.hash(neutralOnly, Object.hashAllUnordered(frames.values));
}

/// The coach (FR-AVT-01/04/05), played from a frame set: expressions swap
/// with a soft cross-fade, the eyes blink every 3 to 6 seconds, the mouth
/// follows [mouth] while the coach speaks, and the coach breathes gently.
/// Reduced motion: the still neutral frame. With no frame set: a soft circle
/// with the coach's initial. Avatar parts are never drawn in code.
class AvatarView extends StatefulWidget {
  const AvatarView({
    super.key,
    required this.images,
    this.size = 160,
    this.semanticLabel,
    this.expression = AvatarExpression.happy,
    this.blink = false,
    this.mouth,
    this.animate = false,
    this.background,
  });

  /// The frame set, or null for the initial circle.
  final AvatarImages? images;
  final AvatarExpression expression;

  /// Eyes closed now (a caller may blink the coach itself).
  final bool blink;

  /// The talking mouth shape while the coach speaks; null at rest.
  final MouthShape? mouth;

  /// Blinking and idle breathing (off where the coach is just a picture,
  /// and always off with reduced motion).
  final bool animate;

  /// Behind the frames (they are cut out) and in the initial circle.
  final Color? background;
  final double size;
  final String? semanticLabel;

  /// The frame shown for these settings ([still]: reduced motion).
  AvatarFrame frameNow({bool blinking = false, bool still = false}) => frameFor(
    expression,
    blink: blink || blinking,
    mouth: mouth,
    still: still,
  );

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();
  Timer? _blinkTimer;
  Timer? _blinkEnd;
  bool _blinking = false;
  AvatarFrame? _lastBase;
  bool _precached = false;

  /// Breathing: a tiny rise and swell, about 4 seconds a breath.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  bool get _still => MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
    _precache();
  }

  @override
  void didUpdateWidget(AvatarView old) {
    super.didUpdateWidget(old);
    _sync();
    if (old.images != widget.images) {
      _precached = false;
      _precache();
    }
  }

  /// Loads every frame up front so swaps never flicker.
  void _precache() {
    final images = widget.images;
    if (_precached || images == null) return;
    _precached = true;
    for (final p in images.frames.values) {
      precacheImage(p, context, onError: (_, _) {});
    }
  }

  void _sync() {
    final on = widget.animate && widget.images != null && !_still;
    if (on && _blinkTimer == null) _nextBlink();
    if (!on) _stopBlinking();
    if (on && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!on && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
  }

  /// Every 3 to 6 seconds, for 140 ms (kept from T-AVT-06b).
  void _nextBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 3000 + _random.nextInt(3000)),
      () {
        if (!mounted) return;
        setState(() => _blinking = true);
        _blinkEnd = Timer(const Duration(milliseconds: 140), () {
          if (mounted) setState(() => _blinking = false);
        });
        _nextBlink();
      },
    );
  }

  void _stopBlinking() {
    _blinkTimer?.cancel();
    _blinkEnd?.cancel();
    _blinkTimer = _blinkEnd = null;
    _blinking = false;
  }

  @override
  void dispose() {
    _stopBlinking();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final size = widget.size;
    final background = widget.background ?? AvatarColours.background.first;
    Widget face;
    if (images == null) {
      face = AvatarInitialCircle(size: size, background: background);
    } else {
      final still = _still;
      final frame = widget.frameNow(blinking: _blinking, still: still);
      // Expression changes cross-fade; blinks and mouth shapes swap at once.
      final base = still
          ? AvatarFrame.neutral
          : expressionFrame(widget.expression);
      final fade = _lastBase != null && _lastBase != base && !still;
      _lastBase = base;
      face = ClipOval(
        child: ColoredBox(
          color: background,
          child: SizedBox.square(
            dimension: size,
            child: AnimatedSwitcher(
              duration: fade
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              child: Image(
                key: ValueKey(frame),
                image: images[frame]!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // Until the first frame has loaded: the initial circle,
                // never an empty face.
                frameBuilder: (context, child, frame, sync) =>
                    frame == null && !sync
                    ? AvatarInitialCircle(size: size, background: background)
                    : child,
                errorBuilder: (_, _, _) =>
                    AvatarInitialCircle(size: size, background: background),
              ),
            ),
          ),
        ),
      );
      face = AnimatedBuilder(
        animation: _breath,
        child: face,
        builder: (context, child) {
          final v = Curves.easeInOut.transform(_breath.value);
          return Transform.translate(
            offset: Offset(0, -size * 0.006 * v),
            child: Transform.scale(scale: 1 + 0.008 * v, child: child),
          );
        },
      );
    }
    return Semantics(
      image: true,
      container: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(dimension: size, child: face),
    );
  }
}

/// Colours for the avatar's background. Avatar art, not UI colours, so they
/// live here rather than in the palette tokens.
abstract final class AvatarColours {
  static const background = [
    Color(0xFFE8F9EE), // mint
    Color(0xFFFEEBDF), // peach
    Color(0xFFF4EFE6), // cream
    Color(0xFFE3ECF5), // sky
    Color(0xFFECE6F3), // lavender
    Color(0xFFFFF4D6), // sunshine
  ];

  /// The ring around the initial circle (the default sweater's green).
  static const ring = Color(0xFF2E8B62);

  static const ink = Color(0xFF2B2420);
}

/// The coach's initial (from the coach's name), for the initial circle.
/// Set once above the app; without it the circle shows no letter.
class AvatarInitial extends InheritedWidget {
  const AvatarInitial({super.key, required this.initial, required super.child});

  final String initial;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AvatarInitial>()?.initial;

  @override
  bool updateShouldNotify(AvatarInitial old) => old.initial != initial;
}

/// The last step of the fallback chain (FR-AVT-05): a soft circle with the
/// coach's initial, until a frame set is available.
class AvatarInitialCircle extends StatelessWidget {
  const AvatarInitialCircle({
    super.key = const Key('avatar-initial'),
    required this.size,
    required this.background,
  });

  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: background,
      border: Border.all(color: AvatarColours.ring, width: size / 40),
    ),
    child: Text(
      AvatarInitial.of(context) ?? '',
      // Fixed size: it is part of the picture, not body text.
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w600,
        color: AvatarColours.ink,
      ),
    ),
  );
}
