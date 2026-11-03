import 'package:flutter/material.dart';

import '../tokens.dart';

/// Which side of the bubble points at the speaker.
enum BubbleTail { left, bottom }

/// The coach's speech bubble (T-UI-02b): a white rounded card with a soft
/// shadow and a small tail towards the coach.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.tail = BubbleTail.left,
  });

  final String text;
  final BubbleTail tail;

  static const _tail = LwSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return CustomPaint(
      painter: _BubblePainter(
        colour: p.surface,
        shadow: LwShadow.of(context).first,
        tail: tail,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: tail == BubbleTail.left ? _tail : 0,
          bottom: tail == BubbleTail.bottom ? _tail : 0,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LwSpacing.md,
            vertical: LwSpacing.sm,
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: p.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.colour,
    required this.shadow,
    required this.tail,
  });

  final Color colour;
  final BoxShadow shadow;
  final BubbleTail tail;

  @override
  void paint(Canvas canvas, Size size) {
    const t = SpeechBubble._tail;
    final body = tail == BubbleTail.left
        ? Rect.fromLTRB(t, 0, size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width, size.height - t);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(LwRadius.lg)),
      );
    final point = tail == BubbleTail.left
        ? (Path()
            ..moveTo(t, body.height * 0.55)
            ..lineTo(0, body.height * 0.55 + t * 1.5)
            ..lineTo(t * 2.5, body.height * 0.55 + t * 0.4)
            ..close())
        : (Path()
            ..moveTo(body.width * 0.25, body.bottom - 1)
            ..lineTo(body.width * 0.2, size.height)
            ..lineTo(body.width * 0.35, body.bottom - 1)
            ..close());
    final all = Path.combine(PathOperation.union, path, point);
    canvas
      ..drawShadow(all, shadow.color, shadow.blurRadius / 4, false)
      ..drawPath(all, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.colour != colour || old.tail != tail || old.shadow != shadow;
}
