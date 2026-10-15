/// Coach voices (FR-VOC-01). The library is fixed app data; sources and
/// licences in docs/voices.md. Previews are bundled recordings of approved
/// text only (closed script, FR-VOC-05).
library;

enum VoiceAccent { us, uk }

enum VoiceStyle { calm, energetic }

class LibraryVoice {
  const LibraryVoice(this.id, this.vendorVoiceId, this.accent);

  /// Stable app id, also the Firestore doc id (users/{uid}/voices/{id}).
  final String id;
  final String vendorVoiceId;
  final VoiceAccent accent;

  String previewAsset(VoiceStyle style) =>
      'assets/voices/${id}_${style.name}.m4a';
}

abstract final class VoiceLibrary {
  static const warm = LibraryVoice(
    'lw-warm',
    'kokoro:af_heart',
    VoiceAccent.us,
  );

  /// 6 now; 12 by launch (FR-VOC-01, needs-product).
  static const all = [
    warm,
    LibraryVoice('lw-bright', 'kokoro:af_bella', VoiceAccent.us),
    LibraryVoice('lw-steady', 'kokoro:am_michael', VoiceAccent.us),
    LibraryVoice('lw-deep', 'kokoro:am_fenrir', VoiceAccent.us),
    LibraryVoice('lw-gentle', 'kokoro:bf_emma', VoiceAccent.uk),
    LibraryVoice('lw-clear', 'kokoro:bm_george', VoiceAccent.uk),
  ];

  static const defaultVoice = warm;

  /// The default voice's greeting ("Hi, I'm your Live Well coach…").
  static const greetingAsset = 'assets/voices/greeting.m4a';

  static LibraryVoice byId(String id) =>
      all.firstWhere((v) => v.id == id, orElse: () => defaultVoice);
}

/// The person's choice, saved as the one active voice.
class VoiceChoice {
  const VoiceChoice({
    required this.voiceId,
    this.speed = 1.0,
    this.style = VoiceStyle.calm,
  });

  final String voiceId;

  /// 0.8 to 1.2 (FR-VOC-01; the rules enforce it too).
  final double speed;
  final VoiceStyle style;

  static const minSpeed = 0.8;
  static const maxSpeed = 1.2;

  static const fallback = VoiceChoice(voiceId: 'lw-warm');

  VoiceChoice copyWith({String? voiceId, double? speed, VoiceStyle? style}) =>
      VoiceChoice(
        voiceId: voiceId ?? this.voiceId,
        speed: (speed ?? this.speed).clamp(minSpeed, maxSpeed).toDouble(),
        style: style ?? this.style,
      );

  @override
  bool operator ==(Object other) =>
      other is VoiceChoice &&
      other.voiceId == voiceId &&
      other.speed == speed &&
      other.style == style;

  @override
  int get hashCode => Object.hash(voiceId, speed, style);
}
