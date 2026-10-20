import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feature switches for things that are not built yet or need a kill switch
/// (spec 10.2). Defaults are off.
/// TODO(T-FND-11): read these from Firebase Remote Config.
class FeatureFlags {
  const FeatureFlags({
    this.briefings = false,
    this.portalCards = false,
    this.voiceClone = false,
    this.drGokulaVoice = false,
  });

  /// Morning briefing player (FR-DLY-01). Off until briefings are generated.
  final bool briefings;

  /// Portal cards (spec 10.2 kill switch). Off until the portal catalog,
  /// consent copy and safety-event log are ready.
  final bool portalCards;

  /// "Use my own voice" (FR-VOC-02, spec 7.4). Off until the consent,
  /// live-recording and speaker-match flow is built and reviewed.
  final bool voiceClone;

  /// "Dr. Gokula (Licensed)" in the voice list (FR-VOC-01). Off until the
  /// licence is signed; always labelled as an AI voice.
  final bool drGokulaVoice;
}

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags(),
);
