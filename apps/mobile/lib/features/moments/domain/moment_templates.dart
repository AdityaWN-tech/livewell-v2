import 'dart:convert';

import 'coach_message.dart';

/// The placeholders a template may use (T-DLY-03a): safe data only, from
/// the person's profile or plan. Anything else is rejected (tested).
abstract final class MomentPlaceholders {
  static const firstName = 'first_name';

  /// The name the person gave their coach (T-AVT-08f first hello).
  static const coachName = 'coach_name';
  static const why = 'why';
  static const stepTitle = 'step_title';
  static const stepMinutes = 'step_minutes';
  static const smallerMinutes = 'smaller_minutes';
  static const streakDays = 'streak_days';
  static const timeOfDay = 'time_of_day';
  static const weeklyCount = 'weekly_count';

  /// The week's routine win (T-GOL-03e): a catalog activity's approved
  /// spoken name, never a custom label, and on how many days.
  static const routineWin = 'routine_win';
  static const routineWinDays = 'routine_win_days';

  static const all = {
    firstName,
    coachName,
    why,
    stepTitle,
    stepMinutes,
    smallerMinutes,
    streakDays,
    timeOfDay,
    weeklyCount,
    routineWin,
    routineWinDays,
  };

  /// Typed by the person: never spoken by a cloned voice (FR-VOC-05).
  static const userText = {firstName, coachName, why};

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
    this.thenEmotion,
    required this.primaryAction,
    required this.secondaryActions,
    required this.variants,
  });

  final Moment moment;
  final int version;
  final bool approved;
  final CoachEmotion emotion;
  final CoachEmotion? thenEmotion;
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
    final then = m['then_emotion'] as String?;
    final thenEmotion = then == null
        ? null
        : CoachEmotion.values.where((e) => e.name == then).firstOrNull;
    if (then != null && thenEmotion == null) {
      throw FormatException('then_emotion $then');
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
      thenEmotion: thenEmotion,
      primaryAction: primary,
      secondaryActions: [
        for (final a in (m['secondary_actions'] as List).cast<String>())
          ?MomentAction.byName(a),
      ],
      variants: variants,
    );
  }
}
