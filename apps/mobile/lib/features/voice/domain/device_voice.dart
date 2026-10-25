import 'voice.dart';

/// Until the coach's own voices exist (T-VOC-01), the coach speaks with the
/// phone's text-to-speech. This picks the phone voice closest to the voice
/// the person chose in the library, so each choice sounds different: same
/// accent, a woman's or a man's voice, and a pitch that fits (D-49).

/// What a library voice sounds like, for matching a phone voice.
class VoiceProfile {
  const VoiceProfile({
    required this.locale,
    required this.female,
    this.pitch = 1.0,
  });

  /// "en-US" or "en-GB".
  final String locale;
  final bool female;

  /// 1.0 is the engine's normal pitch.
  final double pitch;
}

/// The profile of each library voice (their recordings are in
/// docs/voices.md).
VoiceProfile profileFor(LibraryVoice v) => switch (v.id) {
  'lw-warm' => const VoiceProfile(locale: 'en-US', female: true),
  'lw-bright' => const VoiceProfile(locale: 'en-US', female: true, pitch: 1.12),
  'lw-steady' => const VoiceProfile(locale: 'en-US', female: false),
  'lw-deep' => const VoiceProfile(locale: 'en-US', female: false, pitch: 0.85),
  'lw-gentle' => const VoiceProfile(locale: 'en-GB', female: true, pitch: 0.95),
  'lw-clear' => const VoiceProfile(locale: 'en-GB', female: false),
  _ => VoiceProfile(
    locale: v.accent == VoiceAccent.uk ? 'en-GB' : 'en-US',
    female: true,
  ),
};

/// A voice the phone offers (flutter_tts getVoices: name, locale and,
/// on some engines, gender).
class DeviceVoice {
  const DeviceVoice({required this.name, required this.locale, this.gender});

  final String name;
  final String locale;
  final String? gender;

  static DeviceVoice? fromMap(Object? m) {
    if (m is! Map) return null;
    final name = m['name'];
    final locale = m['locale'];
    if (name is! String || locale is! String) return null;
    final gender = m['gender'];
    return DeviceVoice(
      name: name,
      locale: locale,
      gender: gender is String ? gender : null,
    );
  }

  Map<String, String> toMap() => {'name': name, 'locale': locale};
}

// Google's speech engine names its voices by code, e.g. "en-us-x-iom-local".
const _googleFemale = {'sfg', 'tpf', 'tpc', 'iob', 'iog', 'gba', 'gbc', 'gbg'};
const _googleMale = {'iol', 'iom', 'tpd', 'gbb', 'gbd', 'rjs'};

/// True for a woman's voice, false for a man's, null when unknown.
bool? isFemale(DeviceVoice v) {
  final g = v.gender?.toLowerCase();
  if (g == 'female') return true;
  if (g == 'male') return false;
  final n = v.name.toLowerCase();
  if (n.contains('female')) return true;
  if (RegExp(r'(^|[^e])male').hasMatch(n)) return false;
  final code = RegExp(r'-x-([a-z]{3})').firstMatch(n)?.group(1);
  if (_googleFemale.contains(code)) return true;
  if (_googleMale.contains(code)) return false;
  return null;
}

String _norm(String locale) => locale.toLowerCase().replaceAll('_', '-');

/// What the phone should use for [profile]: the closest voice, if any,
/// and the pitch. The same accent comes first, then a woman's or a man's
/// voice, then voices that work offline. Without a voice of the right kind
/// the pitch shifts a little further, so choices still sound different.
({DeviceVoice? voice, double pitch}) pickDeviceVoice(
  List<DeviceVoice> voices,
  VoiceProfile profile,
) {
  final want = _norm(profile.locale);
  final sameLocale = voices.where((v) => _norm(v.locale) == want).toList();
  final pool = sameLocale.isNotEmpty
      ? sameLocale
      : voices.where((v) => _norm(v.locale).startsWith('en')).toList();
  if (pool.isEmpty) {
    return (voice: null, pitch: _fallbackPitch(profile));
  }
  int score(DeviceVoice v) {
    final female = isFemale(v);
    var s = 0;
    if (female == profile.female) s += 4;
    if (female == null) s += 1;
    final n = v.name.toLowerCase();
    if (n.contains('local') || !n.contains('network')) s += 2;
    return s;
  }

  final sorted = [...pool]
    ..sort((a, b) {
      final d = score(b).compareTo(score(a));
      return d != 0 ? d : a.name.compareTo(b.name);
    });
  final best = sorted.first;
  final matched = isFemale(best) == profile.female;
  return (
    voice: best,
    pitch: matched ? profile.pitch : _fallbackPitch(profile),
  );
}

/// No voice of the right kind: a man's choice goes lower, a woman's higher.
double _fallbackPitch(VoiceProfile p) =>
    (p.pitch * (p.female ? 1.08 : 0.82)).clamp(0.5, 2.0).toDouble();
