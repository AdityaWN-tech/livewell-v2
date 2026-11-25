import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/profile_repository.dart';

/// How Avatar Moments play (T-DLY-03e, Profile > Daily plan). Kept on the
/// profile so it follows the person across devices (FR-SET-01). The voice
/// speed is not here: it lives with the chosen voice (one source of truth,
/// `VoiceChoice.speed`).
class MomentPlayback {
  const MomentPlayback({this.autoSpeak = true, this.captions = true});

  /// "Coach speaks automatically when I open a moment". Off: "Show text
  /// only": the moment opens with the whole message and a play button.
  final bool autoSpeak;

  /// "Captions always on": the words appear in the bubble as they are said.
  /// Off: the bubble fills in once the coach has finished speaking. The
  /// message is always there for screen readers and in text-only mode.
  final bool captions;

  static MomentPlayback fromMap(Map<String, dynamic>? m) => MomentPlayback(
    autoSpeak: m?['auto_speak'] is bool ? m!['auto_speak'] as bool : true,
    captions: m?['captions'] is bool ? m!['captions'] as bool : true,
  );

  Map<String, Object> toMap() => {
    'auto_speak': autoSpeak,
    'captions': captions,
  };

  MomentPlayback copyWith({bool? autoSpeak, bool? captions}) => MomentPlayback(
    autoSpeak: autoSpeak ?? this.autoSpeak,
    captions: captions ?? this.captions,
  );
}

/// The person's playback settings; the defaults until the profile loads.
final momentPlaybackProvider = Provider<MomentPlayback>(
  (ref) => MomentPlayback.fromMap(
    ref
            .watch(currentProfileProvider)
            .value
            ?.settings[ProfileSettings.momentPlayback]
        as Map<String, dynamic>?,
  ),
);
