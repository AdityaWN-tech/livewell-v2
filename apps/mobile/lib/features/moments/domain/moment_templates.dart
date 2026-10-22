import 'dart:convert';

import 'coach_message.dart';

/// The placeholders a template may use (T-DLY-03a): safe data only, from
/// the person's profile or plan. Anything else is rejected (tested).
abstract final class MomentPlaceholders {
  static const firstName = 'first_name';
  static const why = 'why';
  static const stepTitle = 'step_title';
  static const stepMinutes = 'step_minutes';
  static const smallerMinutes = 'smaller_minutes';
  static const streakDays = 'streak_days';
  static const timeOfDay = 'time_of_day';
  static const weeklyCount = 'weekly_count';

  static const all = {
    firstName,
    why,
    stepTitle,
    stepMinutes,
    smallerMinutes,
    streakDays,
    timeOfDay,
    weeklyCount,
  };

  /// Typed by the person: never spoken by a cloned voice (FR-VOC-05).
  static const userText = {firstName, why};

  static final pattern = RegExp(r'\{([a-z_]+)\}');

  static Set<String> inText(String text) => {
    for (final m in pattern.allMatches(text)) m[1]!,
  };
}

class MomentVariant {
  const MomentVariant(this.id, this.text);

  final String id;
  final String text;

  Set<String> get placeholders => MomentPlaceholders.inText(text);
}

/// One file of content/coach/moments.
class MomentTemplate {
  const MomentTemplate({
    required this.moment,
    required this.version,
    required this.approved,
    required this.emotion,
    required this.primaryAction,
    required this.secondaryActions,
    required this.variants,
  });

  final Moment moment;
  final int version;
  final bool approved;
  final CoachEmotion emotion;
  final MomentAction primaryAction;
  final List<MomentAction> secondaryActions;
  final List<MomentVariant> variants;

  /// Throws [FormatException] on anything unexpected, so a bad file never
  /// reaches a person.
  factory MomentTemplate.parse(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final moment = Moment.byFile(m['moment'] as String? ?? '');
    final emotion = CoachEmotion.values
        .where((e) => e.name == m['emotion'])
        .firstOrNull;
    final primary = MomentAction.byName(m['primary_action'] as String? ?? '');
    if (moment == null || emotion == null || primary == null) {
      throw const FormatException('moment, emotion or primary_action');
    }
    final variants = [
      for (final v in (m['variants'] as List).cast<Map<String, dynamic>>())
        MomentVariant(v['id'] as String, v['text'] as String),
    ];
    for (final v in variants) {
      final unknown = v.placeholders.difference(MomentPlaceholders.all);
      if (unknown.isNotEmpty) {
        throw FormatException('unknown placeholders $unknown in ${v.id}');
      }
    }
    return MomentTemplate(
      moment: moment,
      version: m['version'] as int,
      approved: m['review_status'] == 'approved',
      emotion: emotion,
      primaryAction: primary,
      secondaryActions: [
        for (final a in (m['secondary_actions'] as List).cast<String>())
          ?MomentAction.byName(a),
      ],
      variants: variants,
    );
  }
}
