import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/coach_message.dart';

/// Speaks a coach message (T-DLY-03b). It takes a whole [CoachMessage],
/// never free text: everything spoken carries its template's message_id
/// (closed-script rule, FR-VOC-05).
abstract class CoachSpeaker {
  /// Starts speaking. [onWord] gets the character range of each word as
  /// it is said (when the engine reports it); [onDone] runs at the end.
  /// Returns false when speech can't start (the player then shows text
  /// only, FR-AVT-05).
  Future<bool> speak(
    CoachMessage message, {
    required double speed,
    void Function(int start, int end)? onWord,
    void Function()? onDone,
  });

  Future<void> pause();
  Future<void> stop();
}

/// The phone's own text-to-speech, until the coach's voices exist.
/// TODO(T-VOC-01): swap to the voice adapter; this screen doesn't change.
class DeviceCoachSpeaker implements CoachSpeaker {
  final _tts = FlutterTts();

  @override
  Future<bool> speak(
    CoachMessage message, {
    required double speed,
    void Function(int start, int end)? onWord,
    void Function()? onDone,
  }) async {
    if (message.messageId.isEmpty) return false;
    try {
      await _tts.awaitSpeakCompletion(false);
      // flutter_tts: 0.5 is a normal pace on Android and iOS; the person's
      // 0.8x to 1.2x setting scales it.
      await _tts.setSpeechRate(0.5 * speed);
      await _tts.setPitch(1.0);
      _tts.setProgressHandler((_, start, end, _) => onWord?.call(start, end));
      _tts.setCompletionHandler(() => onDone?.call());
      _tts.setErrorHandler((_) => onDone?.call());
      final result = await _tts.speak(message.text);
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (_) {
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to stop.
    }
  }
}

final coachSpeakerProvider = Provider<CoachSpeaker>((ref) {
  final speaker = DeviceCoachSpeaker();
  ref.onDispose(speaker.stop);
  return speaker;
});
