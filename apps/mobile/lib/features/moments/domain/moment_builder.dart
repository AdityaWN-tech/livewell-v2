import 'coach_message.dart';
import 'moment_templates.dart';

/// Today's step for a moment, from the person's plan only (FR-GOL-03:
/// beginner or moderate, never something the coach makes up).
class MomentStep {
  const MomentStep({
    required this.title,
    required this.minutes,
    this.smallerTitle,
    this.smallerMinutes,
  });

  final String title;
  final int minutes;
  final String? smallerTitle;
  final int? smallerMinutes;
}

/// What the builder may use. Everything is optional except the time: a
/// variant is used only when all of its placeholders have a value.
class MomentContext {
  const MomentContext({
    required this.now,
    this.firstName,
    this.coachName,
    this.why,
    this.step,
    this.streakDays,
    this.weeklyCount,
    this.safetyHold = false,
  });

  /// Local time; picks "morning / afternoon / evening" and the day's
  /// variant.
  final DateTime now;
  final String? firstName;

  /// The name the person gave their coach (they may have kept the default).
  final String? coachName;
  final String? why;
  final MomentStep? step;
  final int? streakDays;
  final int? weeklyCount;

  /// A red flag today (or a safety card shown): no Avatar Moment at all.
  /// Safety, crisis and medical messages use the safety cards and the
  /// neutral system voice instead (FR-VOC-07).
  final bool safetyHold;
}

/// Builds the coach's message for a moment from the approved templates
/// (T-DLY-03a, spec 9.5).
class MomentBuilder {
  MomentBuilder(
    Iterable<MomentTemplate> templates, {
    required this.approvedOnly,
  }) : _templates = {for (final t in templates) t.moment: t};

  final Map<Moment, MomentTemplate> _templates;

  /// Prod: approved templates only (dev may use pending ones).
  final bool approvedOnly;

  /// The morning moment: "missed day" after a day with no step done and no
  /// check-in (restart wording, never shaming, FR-DLY-07), else the
  /// briefing.
  static Moment morningFor({required bool missedYesterday}) =>
      missedYesterday ? Moment.missedDay : Moment.morning;

  /// The coach's reaction to a check-in (T-AVT-08f): the gentle moment on a
  /// gentle day (low mood or high stress), else a short thank-you that
  /// fits the mood. Nothing from the answers goes into the words.
  static Moment afterCheckIn({required bool gentleDay, required int mood}) =>
      gentleDay
      ? Moment.gentle
      : mood >= 4
      ? Moment.checkInGood
      : Moment.checkInOkay;

  /// Streak days that get their own celebration (T-AVT-08f).
  static const milestones = {7, 14, 30};

  /// What the coach says after Done: the milestone on 7, 14 and 30 days.
  static Moment afterDone({int? streakDays}) => milestones.contains(streakDays)
      ? Moment.streakMilestone
      : Moment.stepDone;

  static String timeOfDay(DateTime t) => switch (t.hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 18 => 'afternoon',
    _ => 'evening',
  };

  /// The message, or null when there is nothing safe to say: a safety hold,
  /// no (approved) template, or no variant whose data is all there.
  CoachMessage? build(Moment moment, MomentContext c) {
    if (c.safetyHold) return null;
    final t = _templates[moment];
    if (t == null || (approvedOnly && !t.approved)) return null;

    final values = _values(moment, c);
    var candidates = [
      for (final v in t.variants)
        if (v.placeholders.every(values.containsKey)) v,
    ];
    // Prefer the personal versions: with the step, the coach's name, the
    // week's count, the streak and the name, when those are known (the
    // plain ones are for when they aren't).
    for (final key in [
      MomentPlaceholders.stepTitle,
      MomentPlaceholders.coachName,
      MomentPlaceholders.weeklyCount,
      MomentPlaceholders.streakDays,
      MomentPlaceholders.firstName,
    ]) {
      if (!values.containsKey(key)) continue;
      final using = [
        for (final v in candidates)
          if (v.placeholders.contains(key)) v,
      ];
      // Only when that still leaves a choice: one line every day would
      // break the daily rotation.
      if (using.length >= 2) candidates = using;
    }
    if (candidates.isEmpty) return null;

    // A different line each day: consecutive days never get the same
    // variant (with the same data) because day % n changes every day.
    final day = DateTime.utc(
      c.now.year,
      c.now.month,
      c.now.day,
    ).difference(DateTime.utc(2026)).inDays;
    final variant = candidates[day % candidates.length];

    final text = variant.text.replaceAllMapped(
      MomentPlaceholders.pattern,
      (m) => values[m[1]!]!,
    );
    return CoachMessage(
      messageId: '${moment.file}.${variant.id}@v${t.version}',
      moment: moment,
      text: text,
      emotion: t.emotion,
      thenEmotion: t.thenEmotion,
      primaryAction: t.primaryAction,
      secondaryActions: t.secondaryActions,
      containsUserText: variant.placeholders.any(
        MomentPlaceholders.userText.contains,
      ),
      approved: t.approved,
    );
  }

  static Map<String, String> _values(Moment moment, MomentContext c) {
    final step = c.step;
    // On a gentle day the step is always the smaller one.
    final gentle = moment == Moment.gentle;
    final name = c.firstName?.trim();
    final coach = c.coachName?.trim();
    final why = _sentence(c.why);
    return {
      MomentPlaceholders.timeOfDay: timeOfDay(c.now),
      if (name != null && name.isNotEmpty) MomentPlaceholders.firstName: name,
      if (coach != null && coach.isNotEmpty)
        MomentPlaceholders.coachName: coach,
      MomentPlaceholders.why: ?why,
      if (step != null) ...{
        MomentPlaceholders.stepTitle: _lower(
          gentle ? (step.smallerTitle ?? step.title) : step.title,
        ),
        MomentPlaceholders.stepMinutes:
            '${gentle ? (step.smallerMinutes ?? step.minutes) : step.minutes}',
        if (step.smallerMinutes != null || gentle)
          MomentPlaceholders.smallerMinutes:
              '${step.smallerMinutes ?? step.minutes}',
      },
      if ((c.streakDays ?? 0) > 0)
        MomentPlaceholders.streakDays: '${c.streakDays}',
      if ((c.weeklyCount ?? 0) > 0)
        MomentPlaceholders.weeklyCount: '${c.weeklyCount}',
    };
  }

  /// The Why as part of a sentence: trimmed, without its final full stop
  /// (the template adds one).
  static String? _sentence(String? s) {
    final t = s?.trim().replaceFirst(RegExp(r'[.!]+$'), '');
    if (t == null || t.isEmpty) return null;
    // Mid-sentence: "for a reason: energy to travel...", but "I want..."
    // keeps its capital.
    return RegExp(r"^I\b").hasMatch(t) ? t : _lower(t);
  }

  /// A step title in the middle of a sentence ("Today's step: a 10-min
  /// walk"): lower-case first letter, unless it starts with a number.
  static String _lower(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
