import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../avatar/domain/avatar_config.dart';
import '../../starter_plan/domain/touchpoints.dart';

/// The coach's face for each reminder (T-DLY-03c): the moment's expression
/// on the person's own avatar. A cartoon face only, never text.
AvatarExpression faceFor(TouchpointKind k) => switch (k) {
  TouchpointKind.greeting => AvatarExpression.waving,
  // Encouraging uses the happy face until the art kit has its own.
  TouchpointKind.nudge => AvatarExpression.happy,
  TouchpointKind.reflection => AvatarExpression.listening,
  TouchpointKind.weekly => AvatarExpression.happy,
};

/// Draws the faces as PNG files for the notifications.
abstract class CoachFaces {
  /// Paths by kind; empty when they can't be drawn (the text still goes).
  /// [initial] is the coach's, for the Anime placeholder (T-AVT-06a).
  Future<Map<TouchpointKind, String>> render(
    AvatarConfig config, {
    String initial = '',
  });
}

class FileCoachFaces implements CoachFaces {
  static const _px = 192.0;

  @override
  Future<Map<TouchpointKind, String>> render(
    AvatarConfig config, {
    String initial = '',
  }) async {
    try {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/coach_faces',
      );
      await dir.create(recursive: true);
      final out = <TouchpointKind, String>{};
      for (final k in TouchpointKind.values) {
        final file = File('${dir.path}/${k.name}.png');
        await file.writeAsBytes(
          await png(config, faceFor(k), initial: initial),
        );
        out[k] = file.path;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// One face as PNG bytes.
  static Future<List<int>> png(
    AvatarConfig config,
    AvatarExpression expression, {
    String initial = '',
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (config.style == AvatarStyle.anime) {
      _placeholder(canvas, config, initial);
    } else {
      AvatarPainter(config, expression).paint(canvas, const Size(_px, _px));
    }
    final image = await recorder.endRecording().toImage(
      _px.toInt(),
      _px.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}

/// The Anime placeholder (never a code-drawn face): a soft circle with the
/// coach's initial, as on screen.
void _placeholder(Canvas canvas, AvatarConfig config, String initial) {
  const r = FileCoachFaces._px / 2;
  canvas
    ..drawCircle(
      const Offset(r, r),
      r,
      Paint()..color = AvatarColours.background[config.background],
    )
    ..drawCircle(
      const Offset(r, r),
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AvatarColours.clothing[config.clothingColour],
    );
  final text = TextPainter(
    text: TextSpan(
      text: initial,
      style: const TextStyle(
        fontSize: r * 0.84,
        fontWeight: FontWeight.w600,
        color: AvatarColours.ink,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, Offset(r - text.width / 2, r - text.height / 2));
}

final coachFacesProvider = Provider<CoachFaces>((ref) => FileCoachFaces());
