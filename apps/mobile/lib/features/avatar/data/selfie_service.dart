import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../domain/avatar_config.dart';

/// Takes a selfie and returns the file path, or null if cancelled.
abstract class PhotoSource {
  Future<String?> takeSelfie();
}

class CameraPhotoSource implements PhotoSource {
  @override
  Future<String?> takeSelfie() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      // Small is enough to read colours, and less to keep around.
      maxWidth: 320,
      requestFullMetadata: false,
    );
    return photo?.path;
  }
}

final photoSourceProvider = Provider<PhotoSource>((ref) => CameraPhotoSource());

/// Selfie → suggested cartoon features, entirely on the phone (FR-AVT-02).
/// The photo is never uploaded and is deleted as soon as the colours are
/// read (FR-AVT-07). Only skin tone and hair colour are suggested; the person
/// checks and changes everything in the creator.
class SelfieAnalyzer {
  SelfieAnalyzer(this._source);

  final PhotoSource _source;

  /// Null when the person cancelled the camera.
  Future<SelfieSuggestion?> takeAndSuggest() async {
    final path = await _source.takeSelfie();
    if (path == null) return null;
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final suggestion = data == null
          ? const SelfieSuggestion()
          : suggestFromPixels(
              data.buffer.asUint8List(),
              image.width,
              image.height,
            );
      image.dispose();
      return suggestion;
    } finally {
      // Always delete, even if reading the photo failed.
      if (await file.exists()) await file.delete();
    }
  }

  /// Averages the face area (the middle of a front-camera selfie) for skin,
  /// and the area above it for hair. No hair suggestion when the two are too
  /// alike to tell apart (short hair, a head covering, a busy background).
  static SelfieSuggestion suggestFromPixels(Uint8List rgba, int w, int h) {
    Color average(double x0, double x1, double y0, double y1) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var y = (y0 * h).floor(); y < (y1 * h).ceil(); y++) {
        for (var x = (x0 * w).floor(); x < (x1 * w).ceil(); x++) {
          final i = (y * w + x) * 4;
          r += rgba[i];
          g += rgba[i + 1];
          b += rgba[i + 2];
          n++;
        }
      }
      if (n == 0) return const Color.fromARGB(0, 0, 0, 0);
      return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
    }

    final face = average(0.38, 0.62, 0.40, 0.60);
    final hair = average(0.38, 0.62, 0.08, 0.18);
    final hairDiffers = AvatarColours.difference(face, hair) > 1200;
    return SelfieSuggestion(
      skin: AvatarColours.nearestSkin(face),
      hairColour: hairDiffers ? AvatarColours.nearestHair(hair) : null,
    );
  }
}

final selfieAnalyzerProvider = Provider<SelfieAnalyzer>(
  (ref) => SelfieAnalyzer(ref.watch(photoSourceProvider)),
);
