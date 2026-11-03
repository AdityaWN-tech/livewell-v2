import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/features/voice/domain/voice.dart';

/// The bundled voice previews decode and play to the end on a real device
/// (T-ONB-03c). Run: flutter test integration_test/voice_playback_test.dart
///   --flavor dev -d DEVICE
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final assets = [
    VoiceLibrary.greetingAsset,
    for (final v in VoiceLibrary.all)
      for (final s in VoiceStyle.values) v.previewAsset(s),
  ];

  for (final asset in assets) {
    testWidgets('plays $asset', (_) async {
      final player = AudioPlayer();
      // Fast playback keeps the run short; speed is a supported setting.
      await player.setPlaybackRate(1.2);
      final done = player.onPlayerComplete.first;
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      final length = await player.getDuration();
      expect(length, isNotNull);
      expect(length!.inMilliseconds, inInclusiveRange(3000, 6500));
      await done.timeout(const Duration(seconds: 15));
      await player.dispose();
    });
  }
}
