/// "Make me from my photo" (T-AVT-08e): own face only (FR-AVT-03), from a
/// live in-app selfie, never the gallery. On-device face detection gives a
/// [FaceObservation] per camera frame; [LivenessTracker] turns them into a
/// tip for the person and says when a live person blinked (or turned their
/// head), with one face, close enough and centred.
library;

/// What the on-device face detector saw in one camera frame.
class FaceObservation {
  const FaceObservation({
    required this.faces,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.yaw,
    this.widthShare = 0,
    this.offCentre = 0,
  });

  /// No face at all.
  static const none = FaceObservation(faces: 0);

  final int faces;

  /// 0 (closed) to 1 (open), when the detector can tell.
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Head turn left or right, in degrees.
  final double? yaw;

  /// The face's width as a share of the picture's width.
  final double widthShare;

  /// How far the face's centre is from the picture's centre (0 to 1).
  final double offCentre;

  bool get eyesOpen =>
      (leftEyeOpen ?? 0) > LivenessTracker.open &&
      (rightEyeOpen ?? 0) > LivenessTracker.open;

  bool get eyesClosed =>
      (leftEyeOpen ?? 1) < LivenessTracker.closed &&
      (rightEyeOpen ?? 1) < LivenessTracker.closed;
}

/// How to show we're a live person: blink, or turn the head and back.
enum LivenessMethod {
  blink('blink'),
  turn('turn');

  const LivenessMethod(this.id);

  /// Sent to the Media Service with the selfie.
  final String id;
}

/// The one thing to tell the person now.
enum SelfieTip {
  noFace,
  oneFaceOnly,
  moveCloser,
  moveBack,
  centre,
  blink,
  turn,
  ready,
}

class LivenessTracker {
  LivenessTracker([this.method = LivenessMethod.blink]);

  final LivenessMethod method;

  static const open = 0.6;
  static const closed = 0.25;
  static const minWidth = 0.3;
  static const maxWidth = 0.75;
  static const maxOffCentre = 0.15;
  static const turnDegrees = 18.0;
  static const straightDegrees = 8.0;

  bool _sawOpen = false;
  bool _sawClosed = false;
  bool _sawTurn = false;
  bool _passed = false;

  /// A live person was seen (a blink, or a turn and back).
  bool get passed => _passed;

  /// Starts over (the face left the picture).
  void reset() => _sawOpen = _sawClosed = _sawTurn = _passed = false;

  SelfieTip see(FaceObservation f) {
    if (f.faces == 0) return SelfieTip.noFace;
    // Own face only: someone else in the picture stops it.
    if (f.faces > 1) {
      reset();
      return SelfieTip.oneFaceOnly;
    }
    if (f.widthShare < minWidth) return SelfieTip.moveCloser;
    if (f.widthShare > maxWidth) return SelfieTip.moveBack;
    if (f.offCentre > maxOffCentre) return SelfieTip.centre;
    if (!_passed) {
      switch (method) {
        case LivenessMethod.blink:
          if (f.eyesOpen && !_sawClosed) _sawOpen = true;
          if (_sawOpen && f.eyesClosed) _sawClosed = true;
          if (_sawClosed && f.eyesOpen) _passed = true;
        case LivenessMethod.turn:
          final yaw = f.yaw?.abs() ?? 0;
          if (yaw >= turnDegrees) _sawTurn = true;
          if (_sawTurn && yaw <= straightDegrees) _passed = true;
      }
      if (!_passed) {
        return method == LivenessMethod.blink
            ? SelfieTip.blink
            : SelfieTip.turn;
      }
    }
    // The photo is taken looking at the camera, eyes open.
    final straight = (f.yaw?.abs() ?? 0) <= straightDegrees;
    return f.eyesOpen && straight ? SelfieTip.ready : SelfieTip.centre;
  }
}
