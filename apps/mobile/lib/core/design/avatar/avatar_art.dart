import 'package:flutter/material.dart';

import '../../../features/avatar/domain/avatar_config.dart';

/// The coach's face and pose (T-UI-02b). Safety replies always use [calm].
enum AvatarExpression { happy, waving, talking, listening, calm, celebrating }

/// Static illustrated coach avatar drawn from an [AvatarConfig] (FR-AVT-02).
/// A placeholder renderer until the stylized animated renderer exists.
/// TODO(T-AVT-01): replace with the stylized renderer and expressions; the
/// illustration set needs design review for inclusiveness (needs-product).
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.config,
    this.size = 160,
    this.semanticLabel,
    this.expression = AvatarExpression.happy,
  });

  final AvatarConfig config;
  final AvatarExpression expression;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    container: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: AvatarPainter(config, expression),
    ),
  );
}

/// Colours for the avatar options. Avatar art, not UI colours, so they live
/// here rather than in the palette tokens.
abstract final class AvatarColours {
  /// Monk Skin Tone Scale (Google, CC BY 4.0), 10 tones light to deep.
  static const skin = [
    Color(0xFFF6EDE4),
    Color(0xFFF3E7DB),
    Color(0xFFF7EAD0),
    Color(0xFFEADABA),
    Color(0xFFD7BD96),
    Color(0xFFA07E56),
    Color(0xFF825C43),
    Color(0xFF604134),
    Color(0xFF3A312A),
    Color(0xFF292420),
  ];

  static const hair = [
    Color(0xFF1F1A17), // black
    Color(0xFF3B2A20), // dark brown
    Color(0xFF6A4A33), // brown
    Color(0xFF8A3B22), // auburn
    Color(0xFFC9A15A), // blonde
    Color(0xFF9A9A9A), // grey
    Color(0xFFE6E3DD), // white
  ];

  static const clothing = [
    Color(0xFF2E8B62), // forest green (the design's hoodie)
    Color(0xFFB05A3B), // terracotta
    Color(0xFF8FB5AB), // sage
    Color(0xFF2F3E5C), // navy
    Color(0xFFC9973B), // mustard
    Color(0xFF6B3F5E), // plum
  ];

  static const background = [
    Color(0xFFE8F9EE), // mint
    Color(0xFFFEEBDF), // peach
    Color(0xFFF4EFE6), // cream
    Color(0xFFE3ECF5), // sky
    Color(0xFFECE6F3), // lavender
    Color(0xFFFFF4D6), // sunshine
  ];

  static const ink = Color(0xFF2B2420);

  static double _distance(Color a, Color b) {
    final dr = (a.r - b.r) * 255,
        dg = (a.g - b.g) * 255,
        db = (a.b - b.b) * 255;
    return dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
  }

  static int _nearest(List<Color> palette, Color c) {
    var best = 0;
    for (var i = 1; i < palette.length; i++) {
      if (_distance(palette[i], c) < _distance(palette[best], c)) best = i;
    }
    return best;
  }

  /// Closest skin tone to a sampled colour.
  static int nearestSkin(Color c) => _nearest(skin, c);

  /// Closest hair colour to a sampled colour.
  static int nearestHair(Color c) => _nearest(hair, c);

  /// Rough colour difference, for "too close to tell apart".
  static double difference(Color a, Color b) => _distance(a, b);
  static const shirt = Color(0xFFFAFAF7);
  static const cheek = Color(0x33E06A5A);
  static const mouth = Color(0xFF5A1F22);
  static const confetti = [
    Color(0xFFF6C344),
    Color(0xFF4CC9A4),
    Color(0xFFF28DB2),
    Color(0xFF7FB2F0),
  ];
}

class AvatarPainter extends CustomPainter {
  AvatarPainter(this.c, [this.expression = AvatarExpression.happy]);

  final AvatarConfig c;
  final AvatarExpression expression;

  static Paint _fill(Color colour) => Paint()..color = colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Draw in a 100 x 100 box.
    canvas.scale(size.width / 100, size.height / 100);
    const box = Rect.fromLTWH(0, 0, 100, 100);
    canvas.clipPath(Path()..addOval(box));
    canvas.drawRect(box, _fill(AvatarColours.background[c.background]));
    // Fill more of the circle: enlarge around the face.
    canvas
      ..translate(50, 58)
      ..scale(1.12)
      ..translate(-50, -52);
    if (expression == AvatarExpression.listening) {
      // A small head tilt: attentive.
      canvas
        ..translate(50, 60)
        ..rotate(-0.07)
        ..translate(-50, -60);
    }

    final skin = AvatarColours.skin[c.skin];
    final hair = AvatarColours.hair[c.hairColour];
    final cloth = AvatarColours.clothing[c.clothingColour];
    final covered = c.headCovering == HeadCovering.hijab;
    final ink = _fill(AvatarColours.ink);

    // Long hair falls behind the shoulders.
    if (!covered && c.hair == HairStyle.long) {
      canvas.drawRRect(
        RRect.fromLTRBR(27, 30, 73, 82, const Radius.circular(18)),
        _fill(hair),
      );
    }

    // Hijab drape behind the face and over the shoulders.
    if (covered) {
      canvas.drawOval(const Rect.fromLTRB(23, 17, 77, 84), _fill(cloth));
    }

    // Neck and shoulders.
    if (!covered) {
      canvas.drawRect(const Rect.fromLTRB(43, 60, 57, 82), _fill(skin));
    }
    canvas.drawRRect(
      RRect.fromLTRBR(12, 76, 88, 120, const Radius.circular(24)),
      _fill(cloth),
    );
    switch (c.clothing) {
      case Clothing.crew:
        canvas.drawArc(
          const Rect.fromLTRB(42, 70, 58, 84),
          0,
          3.14,
          false,
          Paint()
            ..color = AvatarColours.ink.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      case Clothing.collar:
        final collar = _fill(AvatarColours.shirt);
        canvas.drawPath(
          Path()
            ..moveTo(42, 76)
            ..lineTo(50, 84)
            ..lineTo(44, 87)
            ..close(),
          collar,
        );
        canvas.drawPath(
          Path()
            ..moveTo(58, 76)
            ..lineTo(50, 84)
            ..lineTo(56, 87)
            ..close(),
          collar,
        );
      case Clothing.cardigan:
        canvas.drawPath(
          Path()
            ..moveTo(42, 76)
            ..lineTo(50, 92)
            ..lineTo(58, 76)
            ..close(),
          _fill(AvatarColours.shirt),
        );
    }

    // Head and ears.
    if (!covered) {
      canvas.drawCircle(const Offset(32, 47), 4, _fill(skin));
      canvas.drawCircle(const Offset(68, 47), 4, _fill(skin));
    }
    canvas.drawOval(const Rect.fromLTRB(32, 26, 68, 66), _fill(skin));

    if (!covered) _hair(canvas, hair);

    // Head coverings sit over the hair.
    switch (c.headCovering) {
      case HeadCovering.none:
      case HeadCovering.hijab:
        break;
      case HeadCovering.turban:
        canvas.drawPath(
          Path()
            ..moveTo(30, 40)
            ..cubicTo(28, 14, 72, 14, 70, 40)
            ..cubicTo(60, 33, 40, 33, 30, 40)
            ..close(),
          _fill(cloth),
        );
        canvas.drawLine(
          const Offset(36, 26),
          const Offset(62, 36),
          Paint()
            ..color = AvatarColours.ink.withValues(alpha: 0.25)
            ..strokeWidth = 1.5,
        );
      case HeadCovering.kippah:
        canvas.drawArc(
          const Rect.fromLTRB(41, 22, 59, 34),
          3.14,
          3.14,
          true,
          _fill(cloth),
        );
    }

    // Face.
    final brow = Paint()
      ..color = covered ? AvatarColours.ink : hair
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(39, 41), const Offset(45, 40), brow);
    canvas.drawLine(const Offset(55, 40), const Offset(61, 41), brow);
    // Eyes have whites and the mouth is filled, so the face reads on every
    // skin tone (line art alone vanished on the deepest tones).
    final white = _fill(AvatarColours.shirt);
    final lid = Paint()
      ..color = AvatarColours.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    if (expression == AvatarExpression.calm) {
      // Closed, relaxed eyes.
      for (final x in [43.0, 57.0]) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, 46.5), width: 7, height: 4),
          0.2,
          2.74,
          false,
          lid,
        );
      }
    } else {
      switch (c.eyes) {
        case EyeShape.round:
          canvas.drawCircle(const Offset(43, 47), 3, white);
          canvas.drawCircle(const Offset(57, 47), 3, white);
          canvas.drawCircle(const Offset(43.3, 47.3), 1.9, ink);
          canvas.drawCircle(const Offset(57.3, 47.3), 1.9, ink);
        case EyeShape.almond:
          canvas.drawOval(const Rect.fromLTRB(39.5, 45, 46.5, 49.4), white);
          canvas.drawOval(const Rect.fromLTRB(53.5, 45, 60.5, 49.4), white);
          canvas.drawCircle(const Offset(43.2, 47.2), 1.8, ink);
          canvas.drawCircle(const Offset(57.2, 47.2), 1.8, ink);
        case EyeShape.smiling:
          for (final x in [43.0, 57.0]) {
            final r = Rect.fromCenter(
              center: Offset(x, 48),
              width: 7,
              height: 5,
            );
            canvas.drawArc(r, 3.14, 3.14, true, white);
            canvas.drawArc(r, 3.14, 3.14, false, lid);
          }
      }
    }
    canvas.drawCircle(const Offset(39, 54), 3, _fill(AvatarColours.cheek));
    canvas.drawCircle(const Offset(61, 54), 3, _fill(AvatarColours.cheek));
    _mouth(canvas, white, lid);

    // Glasses.
    final frame = Paint()
      ..color = AvatarColours.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    switch (c.glasses) {
      case Glasses.none:
        break;
      case Glasses.round:
        canvas.drawCircle(const Offset(43, 47), 5.2, frame);
        canvas.drawCircle(const Offset(57, 47), 5.2, frame);
        canvas.drawLine(const Offset(48.2, 47), const Offset(51.8, 47), frame);
      case Glasses.square:
        canvas.drawRRect(
          RRect.fromLTRBR(37, 42.5, 49, 51.5, const Radius.circular(2)),
          frame,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(51, 42.5, 63, 51.5, const Radius.circular(2)),
          frame,
        );
        canvas.drawLine(const Offset(49, 46), const Offset(51, 46), frame);
    }
    if (expression == AvatarExpression.waving) {
      _hand(canvas, const Offset(74, 66), skin, cloth);
    } else if (expression == AvatarExpression.celebrating) {
      _hand(canvas, const Offset(75, 62), skin, cloth);
      _hand(canvas, const Offset(25, 62), skin, cloth);
      for (final (x, y, colour) in [
        (24.0, 24.0, AvatarColours.confetti[0]),
        (76.0, 22.0, AvatarColours.confetti[1]),
        (18.0, 44.0, AvatarColours.confetti[2]),
        (83.0, 42.0, AvatarColours.confetti[3]),
      ]) {
        canvas.drawCircle(Offset(x, y), 2.2, _fill(colour));
      }
    }
    canvas.restore();
  }

  void _mouth(Canvas canvas, Paint white, Paint line) {
    switch (expression) {
      case AvatarExpression.talking:
        // Mid-word: a small open oval.
        canvas.drawOval(
          const Rect.fromLTRB(46.5, 55, 53.5, 61),
          _fill(AvatarColours.mouth),
        );
      case AvatarExpression.listening:
      case AvatarExpression.calm:
        // A gentle closed smile.
        canvas.drawArc(
          const Rect.fromLTRB(45, 52, 55, 58),
          0.3,
          2.54,
          false,
          line,
        );
      case AvatarExpression.happy:
      case AvatarExpression.waving:
      case AvatarExpression.celebrating:
        // Open smile: dark mouth with a strip of teeth; wider when
        // celebrating.
        final w = expression == AvatarExpression.celebrating ? 7.0 : 5.5;
        final mouth = Path()
          ..moveTo(50 - w, 55.5)
          ..quadraticBezierTo(50, 62.5 + (w - 5.5), 50 + w, 55.5)
          ..close();
        canvas.drawPath(mouth, _fill(AvatarColours.mouth));
        canvas
          ..save()
          ..clipPath(mouth)
          ..drawRect(Rect.fromLTRB(50 - w, 55, 50 + w, 57), white)
          ..restore();
    }
  }

  /// A raised hand with a sleeve, for waving and celebrating.
  void _hand(Canvas canvas, Offset at, Color skin, Color cloth) {
    final dx = at.dx > 50 ? 1.0 : -1.0;
    canvas.drawLine(
      Offset(at.dx - 6 * dx, 92),
      Offset(at.dx, at.dy + 6),
      Paint()
        ..color = cloth
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at, 5.5, _fill(skin));
  }

  void _hair(Canvas canvas, Color colour) {
    final p = _fill(colour);
    // A cap over the top of the head, used by most styles.
    Path cap({double brow = 37}) => Path()
      ..moveTo(31, brow + 6)
      ..cubicTo(28, 16, 72, 16, 69, brow + 6)
      ..cubicTo(64, brow - 4, 40, brow - 6, 31, brow + 6)
      ..close();
    switch (c.hair) {
      case HairStyle.none:
        break;
      case HairStyle.buzz:
        canvas.drawPath(cap(brow: 31), _fill(colour.withValues(alpha: 0.75)));
      case HairStyle.short:
        canvas.drawPath(cap(), p);
      case HairStyle.long:
        canvas.drawPath(cap(), p);
        canvas.drawRRect(
          RRect.fromLTRBR(29, 36, 35, 66, const Radius.circular(3)),
          p,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(65, 36, 71, 66, const Radius.circular(3)),
          p,
        );
      case HairStyle.wavy:
        canvas.drawPath(cap(), p);
        for (final x in [36.0, 44.0, 52.0, 60.0]) {
          canvas.drawCircle(Offset(x, 35), 4.2, p);
        }
      case HairStyle.curly:
        for (final (x, y) in [
          (34.0, 34.0),
          (40.0, 27.0),
          (48.0, 24.0),
          (56.0, 25.0),
          (63.0, 30.0),
          (67.0, 38.0),
          (32.0, 41.0),
        ]) {
          canvas.drawCircle(Offset(x, y), 6, p);
        }
      case HairStyle.coily:
        canvas.drawOval(const Rect.fromLTRB(26, 10, 74, 44), p);
      case HairStyle.bun:
        canvas.drawCircle(const Offset(50, 17), 7, p);
        canvas.drawPath(cap(), p);
    }
  }

  @override
  bool shouldRepaint(AvatarPainter old) =>
      old.c != c || old.expression != expression;
}
