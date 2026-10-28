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
    this.avatarFromPhoto = false,
    this.avatarMaker = false,
    this.coachChat = false,
    this.coachVoice = false,
    this.lovedOneVoice = false,
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

  /// "Make me from my photo" in the Avatar Studio (T-AVT-08e). Off in prod
  /// until counsel review (T-CMP-02).
  final bool avatarFromPhoto;

  /// "Build my own" and "Adjust" in the Avatar Studio (T-AVT-08c). Off
  /// until the Media Service is deployed (GPU on Blaze, D-39) and its
  /// prompts and options are reviewed; also hidden while the service isn't
  /// set up in the app.
  final bool avatarMaker;

  /// Typing to the coach on Care (FR-CNV-01). Off until the agent service
  /// answers (T-AGT, ADR-001); until then Care shows help, resources and
  /// the clinician card, never a chat that can't answer (Step 4d, D-56).
  final bool coachChat;

  /// Talking to the coach out loud (FR-CNV-01/02). Off until speech-to-text,
  /// the coach's voice and the agent exist.
  final bool coachVoice;

  /// "A loved one's voice" (FR-VOC-03, Phase 2). Off until its own consent
  /// and clone flow exist.
  final bool lovedOneVoice;
}

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags(),
);
