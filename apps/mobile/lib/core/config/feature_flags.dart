import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flavor.dart';
import 'media_service.dart';
import 'remote_flags.dart';

/// Feature switches for things that are not built yet or need a kill switch
/// (spec 10.2). Defaults are off.
///
/// Values come from [resolveFeatureFlags]: the build's defaults for the
/// flavour, then Firebase Remote Config (T-FND-11, D-73). Flags only show or
/// hide a way into a feature. Safety routing, consents, the frequency cap and
/// the closed-script voice rule are plain code and are never flags.
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
    this.photorealStreaming = false,
    this.coachMemory = false,
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

  /// Live photo-realistic avatar streaming (spec 8.4, 10.2 kill switch).
  /// Not built yet; nothing reads it until the streaming avatar exists, and
  /// it is reserved so the kill switch is in place from the start.
  final bool photorealStreaming;

  /// The value of [flag].
  bool operator [](Flag flag) => switch (flag) {
    Flag.briefings => briefings,
    Flag.portalCards => portalCards,
    Flag.voiceClone => voiceClone,
    Flag.drGokulaVoice => drGokulaVoice,
    Flag.avatarFromPhoto => avatarFromPhoto,
    Flag.avatarMaker => avatarMaker,
    Flag.coachChat => coachChat,
    Flag.coachVoice => coachVoice,
    Flag.lovedOneVoice => lovedOneVoice,
    Flag.photorealStreaming => photorealStreaming,
    Flag.coachMemory => coachMemory,
  };

  /// Builds flags from one value per [Flag]; missing ones are off.
  factory FeatureFlags.fromMap(Map<Flag, bool> v) => FeatureFlags(
    briefings: v[Flag.briefings] ?? false,
    portalCards: v[Flag.portalCards] ?? false,
    voiceClone: v[Flag.voiceClone] ?? false,
    drGokulaVoice: v[Flag.drGokulaVoice] ?? false,
    avatarFromPhoto: v[Flag.avatarFromPhoto] ?? false,
    avatarMaker: v[Flag.avatarMaker] ?? false,
    coachChat: v[Flag.coachChat] ?? false,
    coachVoice: v[Flag.coachVoice] ?? false,
    lovedOneVoice: v[Flag.lovedOneVoice] ?? false,
    photorealStreaming: v[Flag.photorealStreaming] ?? false,
    coachMemory: v[Flag.coachMemory] ?? false,
  );

  @override
  String toString() =>
      'FeatureFlags(${Flag.values.map((f) => '${f.name}: ${this[f]}').join(', ')})';

  /// "What my coach remembers" (FR-CNV-05, T-AGT-05b). Off in staging and
  /// prod until the Memory Agent is deployed and proposing facts (D-101);
  /// the dev flavor always shows it (coachMemoryEnabledProvider).
  final bool coachMemory;
}

/// Every flag, with its Remote Config parameter name (the same names as in
/// `firebase/remoteconfig.template.json`).
enum Flag {
  briefings('ff_briefings'),
  portalCards('ff_portal_cards'),
  voiceClone('ff_voice_clone', prodLocked: true),
  drGokulaVoice('ff_dr_gokula_voice', prodLocked: true),
  avatarFromPhoto('ff_avatar_from_photo', prodLocked: true),
  avatarMaker('ff_avatar_maker'),
  coachChat('ff_coach_chat'),
  coachVoice('ff_coach_voice'),
  lovedOneVoice('ff_loved_one_voice', prodLocked: true),
  photorealStreaming('ff_photoreal_streaming', prodLocked: true),
  coachMemory('ff_coach_memory');

  const Flag(this.remoteKey, {this.prodLocked = false});

  /// Remote Config parameter name.
  final String remoteKey;

  /// Needs counsel or licence sign-off (T-CMP-02, the Dr. Gokula licence,
  /// the voice-consent review). In prod a remote value can only turn it
  /// off; turning it on also needs the build-time allow
  /// (`--dart-define=LW_PROD_ALLOW_FLAGS=...`, D-73).
  final bool prodLocked;
}

/// Prod-locked flags this build may turn on remotely, from
/// `--dart-define=LW_PROD_ALLOW_FLAGS=voiceClone,drGokulaVoice` (flag names,
/// comma separated). Empty in every normal build.
const prodAllowFlagsDefine = String.fromEnvironment('LW_PROD_ALLOW_FLAGS');

/// Parses [prodAllowFlagsDefine]; unknown names are ignored.
Set<Flag> parseProdAllow(String define) {
  final names = define.split(',').map((s) => s.trim()).toSet();
  return {
    for (final f in Flag.values)
      if (names.contains(f.name)) f,
  };
}

/// The build's own values for [flavor]: what the app does when Remote Config
/// has nothing (no Firebase, offline first launch, nothing set in the
/// console). Prod and staging keep every flag off; dev with a Media Service
/// on the developer's computer (LW_MEDIA_URL, D-64) turns the avatar maker
/// and From my photo on to try them.
FeatureFlags defaultFlagsFor(Flavor flavor, {bool mediaDev = false}) {
  final dev = flavor == Flavor.dev && mediaDev;
  return FeatureFlags(avatarFromPhoto: dev, avatarMaker: dev);
}

/// Reads a Remote Config string as a bool: only "true" or "false" (any
/// case, spaces trimmed). Anything else is invalid and returns null.
bool? parseFlagValue(String? raw) => switch (raw?.trim().toLowerCase()) {
  'true' => true,
  'false' => false,
  _ => null,
};

/// The flags in effect: [remote] values (parameter name to raw string, only
/// those set in the console) over the flavour's defaults. Invalid or missing
/// values keep the default. In prod a [Flag.prodLocked] flag can be turned
/// off remotely but only turned on when it is in [prodAllow].
FeatureFlags resolveFeatureFlags(
  Flavor flavor, {
  Map<String, String> remote = const {},
  bool mediaDev = false,
  Set<Flag> prodAllow = const {},
}) {
  final defaults = defaultFlagsFor(flavor, mediaDev: mediaDev);
  return FeatureFlags.fromMap({
    for (final f in Flag.values)
      f: _resolve(
        f,
        defaults[f],
        parseFlagValue(remote[f.remoteKey]),
        flavor,
        prodAllow,
      ),
  });
}

bool _resolve(
  Flag flag,
  bool fallback,
  bool? remote,
  Flavor flavor,
  Set<Flag> prodAllow,
) {
  if (remote == null) return fallback;
  final locked =
      flavor == Flavor.prod && flag.prodLocked && !prodAllow.contains(flag);
  // A kill switch (off) always works; switching a locked flag on doesn't.
  if (locked && remote) return fallback;
  return remote;
}

/// The flags in effect for the running app. Features read flags only from
/// here; tests override it with fixed [FeatureFlags].
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  final mediaDev = ref.watch(mediaServiceBaseProvider) != null;
  return resolveFeatureFlags(
    ref.watch(flavorProvider),
    remote: ref.watch(remoteFlagValuesProvider),
    mediaDev: mediaDev,
    prodAllow: parseProdAllow(prodAllowFlagsDefine),
  );
});
