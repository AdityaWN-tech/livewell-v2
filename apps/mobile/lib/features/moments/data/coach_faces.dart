import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../avatar/data/avatar_frames_store.dart';
import '../../avatar/domain/coach_face.dart';
import '../../starter_plan/domain/touchpoints.dart';

/// The coach's face for each reminder (T-DLY-03c): the moment's expression.
AvatarExpression faceFor(TouchpointKind k) => switch (k) {
  TouchpointKind.greeting => AvatarExpression.waving,
  // Encouraging uses the happy face until the art kit has its own.
  TouchpointKind.nudge => AvatarExpression.happy,
  TouchpointKind.reflection => AvatarExpression.listening,
  TouchpointKind.weekly => AvatarExpression.happy,
};

/// Picture files for the notifications.
abstract class CoachFaces {
  /// Paths by kind; empty when there are none (the text still goes). Uses
  /// the coach's frame set on the device (T-AVT-08a), else a soft circle
  /// with the coach's [initial] on [background] (mint by default).
  Future<Map<TouchpointKind, String>> render({
    CachedFrameSet? frames,
    String initial = '',
    Color? background,
  });

  /// The same, by expression name, for the home-screen widget (T-AVT-08g).
  Future<Map<String, String>> byExpression(
    List<AvatarExpression> expressions, {
    CachedFrameSet? frames,
    String initial = '',
    Color? background,
  });
}

class FileCoachFaces implements CoachFaces {
  static const _px = 192.0;

  @override
  Future<Map<TouchpointKind, String>> render({
    CachedFrameSet? frames,
    String initial = '',
    Color? background,
  }) async {
    try {
      final out = <TouchpointKind, String>{};
      File? circle;
      for (final k in TouchpointKind.values) {
        // The set's small expression thumbnail (T-AVT-08d), else its frame.
        final thumb = frames?.thumbnail(faceFor(k).name);
        if (thumb != null) {
          out[k] = thumb.path;
          continue;
        }
        final frame = frames?.file(
          expressionFrame(faceFor(k)),
          devicePixelRatio: 2,
        );
        if (frame != null) {
          out[k] = frame.path;
          continue;
        }
        circle ??= await _circleFile(
          initial,
          background ?? AvatarColours.background.first,
        );
        out[k] = circle.path;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<Map<String, String>> byExpression(
    List<AvatarExpression> expressions, {
    CachedFrameSet? frames,
    String initial = '',
    Color? background,
  }) async {
    try {
      final out = <String, String>{};
      File? circle;
      for (final e in expressions) {
        final found =
            frames?.thumbnail(e.name) ??
            frames?.file(expressionFrame(e), devicePixelRatio: 2);
        if (found != null) {
          out[e.name] = found.path;
          continue;
        }
        circle ??= await _circleFile(
          initial,
          background ?? AvatarColours.background.first,
        );
        out[e.name] = circle.path;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<File> _circleFile(String initial, Color background) async {
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/coach_faces',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}/initial.png');
    await file.writeAsBytes(await circlePng(initial, background));
    return file;
  }

  /// The initial circle as PNG bytes (never a code-drawn face).
  static Future<List<int>> circlePng(String initial, Color background) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const r = _px / 2;
    canvas
      ..drawCircle(const Offset(r, r), r, Paint()..color = background)
      ..drawCircle(
        const Offset(r, r),
        r - 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = AvatarColours.ring,
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
    final image = await recorder.endRecording().toImage(
      _px.toInt(),
      _px.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}

final coachFacesProvider = Provider<CoachFaces>((ref) => FileCoachFaces());
