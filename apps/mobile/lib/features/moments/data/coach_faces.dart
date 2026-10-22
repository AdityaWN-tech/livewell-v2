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
  Future<Map<TouchpointKind, String>> render(AvatarConfig config);
}

class FileCoachFaces implements CoachFaces {
  static const _px = 192.0;

  @override
  Future<Map<TouchpointKind, String>> render(AvatarConfig config) async {
    try {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/coach_faces',
      );
      await dir.create(recursive: true);
      final out = <TouchpointKind, String>{};
      for (final k in TouchpointKind.values) {
        final file = File('${dir.path}/${k.name}.png');
        await file.writeAsBytes(await png(config, faceFor(k)));
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
    AvatarExpression expression,
  ) async {
    final recorder = ui.PictureRecorder();
    AvatarPainter(
      config,
      expression,
    ).paint(Canvas(recorder), const Size(_px, _px));
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
