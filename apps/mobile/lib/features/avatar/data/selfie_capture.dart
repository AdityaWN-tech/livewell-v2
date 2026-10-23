import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/liveness.dart';

/// The live selfie (T-AVT-08e): the front camera, read on the phone by
/// on-device face detection. Never the gallery (own face only, FR-AVT-03).
abstract class SelfieCapture {
  /// Opens the front camera; throws [SelfieCameraUnavailable].
  Future<void> start();

  /// What the face detector sees, frame by frame.
  Stream<FaceObservation> get observations;

  /// The live picture.
  Widget preview();

  /// Takes the photo. Its bytes are only kept in memory: the camera's file
  /// is deleted before this returns, whatever happens.
  Future<Uint8List> takePhoto();

  /// Closes the camera (it can be started again).
  Future<void> stop();

  /// Closes everything, for good.
  Future<void> close();
}

class SelfieCameraUnavailable implements Exception {
  const SelfieCameraUnavailable();
}

/// Reads [file] into memory and deletes it, even when reading fails.
@visibleForTesting
Future<Uint8List> readAndDelete(XFile file) async {
  try {
    return await file.readAsBytes();
  } finally {
    try {
      await File(file.path).delete();
    } catch (_) {
      // Already gone.
    }
  }
}

/// The phone's front camera with Google ML Kit face detection, which runs
/// on the device (nothing is sent to read the face).
class CameraSelfieCapture implements SelfieCapture {
  CameraController? _camera;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final _out = StreamController<FaceObservation>.broadcast();
  bool _busy = false;

  @override
  Stream<FaceObservation> get observations => _out.stream;

  @override
  Future<void> start() async {
    try {
      final front = (await availableCameras()).firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await camera.initialize();
      _camera = camera;
      await camera.startImageStream((image) => _see(image, front));
    } catch (_) {
      throw const SelfieCameraUnavailable();
    }
  }

  Future<void> _see(CameraImage image, CameraDescription camera) async {
    if (_busy) return;
    _busy = true;
    try {
      final input = _input(image, camera);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      // Portrait: the picture is rotated, so its width is the image height.
      final rotated =
          camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
      final width = (rotated ? image.height : image.width).toDouble();
      final height = (rotated ? image.width : image.height).toDouble();
      if (faces.length != 1) {
        _out.add(FaceObservation(faces: faces.length));
        return;
      }
      final f = faces.single;
      final centre = f.boundingBox.center;
      _out.add(
        FaceObservation(
          faces: 1,
          leftEyeOpen: f.leftEyeOpenProbability,
          rightEyeOpen: f.rightEyeOpenProbability,
          yaw: f.headEulerAngleY,
          widthShare: f.boundingBox.width / width,
          offCentre: math.max(
            (centre.dx / width - 0.5).abs(),
            (centre.dy / height - 0.5).abs(),
          ),
        ),
      );
    } catch (_) {
      // A frame that can't be read is skipped.
    } finally {
      _busy = false;
    }
  }

  InputImage? _input(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.single;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget preview() {
    final camera = _camera;
    return camera == null ? const SizedBox.shrink() : CameraPreview(camera);
  }

  @override
  Future<Uint8List> takePhoto() async {
    final camera = _camera;
    if (camera == null) throw const SelfieCameraUnavailable();
    if (camera.value.isStreamingImages) await camera.stopImageStream();
    return readAndDelete(await camera.takePicture());
  }

  @override
  Future<void> stop() async {
    final camera = _camera;
    _camera = null;
    try {
      if (camera?.value.isStreamingImages ?? false) {
        await camera!.stopImageStream();
      }
      await camera?.dispose();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await stop();
    await _detector.close();
    await _out.close();
  }
}

/// A new capture for each selfie screen.
final selfieCaptureProvider = Provider.autoDispose<SelfieCapture>(
  (ref) => CameraSelfieCapture(),
);
