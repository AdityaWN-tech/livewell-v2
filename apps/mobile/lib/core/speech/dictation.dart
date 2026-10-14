import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice typing (FR-ONB-05 Why, later reflections). Uses the phone's own
/// speech recognizer, asked to stay on the device so audio isn't sent to a
/// server (spec 8.3: on-device STT for privacy). Callers must check the
/// microphone consent first (FR-ONB-03).
abstract class Dictation {
  /// Starts listening and reports the words heard so far. Returns false when
  /// voice typing isn't available (no recognizer, no on-device model, or the
  /// OS permission was refused).
  Future<bool> start(void Function(String text, bool isFinal) onText);

  Future<void> stop();
}

class DeviceDictation implements Dictation {
  final _speech = SpeechToText();
  bool? _ready;

  @override
  Future<bool> start(void Function(String text, bool isFinal) onText) async {
    _ready ??= await _speech.initialize(onError: (_) {});
    if (_ready != true) return false;
    await _speech.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}

final dictationProvider = Provider<Dictation>((ref) => DeviceDictation());
