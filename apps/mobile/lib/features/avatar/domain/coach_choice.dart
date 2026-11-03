/// The person's coach (T-AVT-08b), stored in users/{uid}/avatar/current:
/// `type: 3d_adult`, `source`, `coach_id` (a ready-made coach),
/// `frames_version` (a made-for-you set; server-written, T-AVT-08c/d),
/// `options` (Build my own / Adjust choices, from fixed lists),
/// `coach_name` and `background`.
library;

import 'coaches.dart';

/// Where the coach came from.
enum CoachSource {
  readyMade('default'),
  selfie('selfie'),
  built('built');

  const CoachSource(this.id);

  /// As stored in `source`.
  final String id;
}

/// Number of background colours (core/design/avatar AvatarColours).
const coachBackgrounds = 6;

class CoachChoice {
  const CoachChoice({
    this.source = CoachSource.readyMade,
    this.coach = ReadyCoach.fallback,
    this.framesVersion,
    this.options = const {},
    this.coachName,
    this.background = 0,
  });

  /// "Skip": the default ready-made coach, named "Coach", on mint.
  static const fallback = CoachChoice();

  final CoachSource source;

  /// The ready-made coach (also the look shown until a made-for-you set
  /// is ready).
  final ReadyCoach coach;

  /// The made-for-you frame set (selfie or built), once the server made it.
  final int? framesVersion;

  /// Build my own / Adjust choices (fixed option ids).
  final Map<String, String> options;

  /// The coach's name; null means "Coach".
  final String? coachName;
  final int background;

  static const maxNameLength = 20;

  /// Letters first, then letters, spaces, apostrophes or hyphens (as in
  /// Profile > My coach); empty is fine (the coach is called "Coach").
  static bool validName(String name) =>
      name.trim().isEmpty ||
      RegExp(
        r"^[\p{L}][\p{L} '\-]{0,19}$",
        unicode: true,
      ).hasMatch(name.trim());

  /// A name as it is saved: trimmed, at most 20 characters; empty is none.
  static String? cleanName(String? name) {
    final t = name?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.length > maxNameLength ? t.substring(0, maxNameLength) : t;
  }

  CoachChoice copyWith({
    ReadyCoach? coach,
    int? background,
    String? coachName,
    bool clearName = false,
  }) => CoachChoice(
    // Picking a ready-made coach makes it the coach.
    source: coach == null ? source : CoachSource.readyMade,
    coach: coach ?? this.coach,
    framesVersion: coach == null ? framesVersion : null,
    options: coach == null ? options : const {},
    coachName: clearName ? null : (coachName ?? this.coachName),
    background: background ?? this.background,
  );

  /// The fields the app writes (frames_version stays server-only).
  Map<String, Object> toMap() => {
    'type': '3d_adult',
    'source': source.id,
    'coach_id': coach.id,
    'coach_name': ?coachName,
    'background': background,
    'raw_media_retained': false,
  };

  /// Reads avatar/current. Older cartoon documents (`type: stylized`) keep
  /// their background and get the default coach.
  static CoachChoice fromMap(Map<String, dynamic> m) {
    final legacy = m['style_config'];
    final bg = m['background'] ?? (legacy is Map ? legacy['background'] : null);
    final version = m['frames_version'];
    final options = m['options'];
    return CoachChoice(
      source:
          CoachSource.values.where((s) => s.id == m['source']).firstOrNull ??
          CoachSource.readyMade,
      coach: ReadyCoach.byId(m['coach_id']) ?? ReadyCoach.fallback,
      framesVersion: version is int && version > 0 ? version : null,
      options: options is Map
          ? {
              for (final e in options.entries)
                if (e.value is String) '${e.key}': e.value as String,
            }
          : const {},
      coachName: cleanName(m['coach_name'] as String?),
      background: bg is int && bg >= 0 && bg < coachBackgrounds ? bg : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoachChoice &&
      other.source == source &&
      other.coach == coach &&
      other.framesVersion == framesVersion &&
      other.coachName == coachName &&
      other.background == background &&
      other.options.length == options.length &&
      other.options.entries.every((e) => options[e.key] == e.value);

  @override
  int get hashCode =>
      Object.hash(source, coach, framesVersion, coachName, background);
}
