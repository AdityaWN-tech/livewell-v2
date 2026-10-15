/// The 7-day starter plan (T-ONB-03e), built by rules from approved
/// template files (content/plan/templates). The Coach Agent replaces this
/// later (T-AGT-04).
library;

import 'dart:convert';

import '../../focus/domain/focus.dart';

/// Time sizes from the check-in ("How much time do you have?").
abstract final class TimeSizes {
  static const all = [2, 5, 10, 30];

  /// Used when the person skipped the time question.
  static const fallback = 5;

  static int normalise(int? minutes) =>
      all.contains(minutes) ? minutes! : fallback;

  /// The next size down, or null at the smallest (FR-DLY-03 "make it
  /// smaller").
  static int? smaller(int minutes) {
    final i = all.indexOf(minutes);
    return i > 0 ? all[i - 1] : null;
  }

  static int larger(int minutes) {
    final i = all.indexOf(minutes);
    return i < all.length - 1 ? all[i + 1] : minutes;
  }
}

class TemplateDay {
  const TemplateDay({
    required this.title,
    required this.reason,
    required this.anchor,
    required this.movement,
  });

  final String title;
  final String reason;
  final String anchor;
  final bool movement;

  String titleFor(int minutes) => title.replaceAll('{minutes}', '$minutes');
}

class SupportingHabit {
  const SupportingHabit({
    required this.id,
    required this.title,
    required this.anchor,
    required this.movement,
  });

  final String id;
  final String title;
  final String anchor;
  final bool movement;
}

class PlanTemplate {
  const PlanTemplate({
    required this.reviewStatus,
    required this.days,
    required this.supporting,
  });

  final String reviewStatus;
  final List<TemplateDay> days;
  final List<SupportingHabit> supporting;

  bool get approved => reviewStatus == 'approved';

  static PlanTemplate parse(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return PlanTemplate(
      reviewStatus: m['review_status'] as String,
      days: [
        for (final d in (m['days'] as List).cast<Map<String, dynamic>>())
          TemplateDay(
            title: d['title'] as String,
            reason: d['reason'] as String,
            anchor: d['anchor'] as String,
            movement: d['movement'] as bool,
          ),
      ],
      supporting: [
        for (final s in (m['supporting'] as List).cast<Map<String, dynamic>>())
          SupportingHabit(
            id: s['id'] as String,
            title: s['title'] as String,
            anchor: s['anchor'] as String,
            movement: s['movement'] as bool,
          ),
      ],
    );
  }
}

/// One day of the plan, saved as users/{uid}/daily_plans/{date}.
class PlanDay {
  const PlanDay({
    required this.date,
    required this.dayNumber,
    required this.focus,
    required this.title,
    required this.reason,
    required this.anchor,
    required this.minutes,
    required this.smallerTitle,
    required this.smallerMinutes,
    required this.gentle,
  });

  /// Local date, YYYY-MM-DD.
  final String date;
  final int dayNumber;
  final FocusArea focus;
  final String title;
  final String reason;
  final String anchor;
  final int minutes;
  final String? smallerTitle;
  final int? smallerMinutes;
  final bool gentle;
}

class StarterPlan {
  const StarterPlan({required this.days, required this.supporting});

  final List<PlanDay> days;

  /// At most 2 across the whole plan (FR-GOL-01).
  final List<SupportingHabit> supporting;

  static const maxSupporting = 2;
}

/// Builds the plan. Pure and deterministic, so it can be tested.
abstract final class StarterPlanGenerator {
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// [focus]: 1 or 2 choices, main first. [minutes]: today's time size.
  /// [gentleToday]: today is a gentle day (low mood or high stress, or a red
  /// flag), so day 1 is the smallest step with the gentle message.
  /// [activityLimited]: FR-GOL-03 "yes": no movement at all.
  static StarterPlan generate({
    required DateTime start,
    required List<FocusArea> focus,
    required int? minutes,
    required bool gentleToday,
    required bool activityLimited,
    required Map<FocusArea, PlanTemplate> templates,
    required PlanTemplate limited,
    required String gentleReason,
  }) {
    assert(focus.isNotEmpty && focus.length <= 2);
    final size = TimeSizes.normalise(minutes);
    final main = focus.first;
    final second = focus.length > 1 ? focus[1] : null;
    final days = <PlanDay>[];
    for (var i = 0; i < 7; i++) {
      // The second focus gets days 3 and 6; the main focus the rest.
      final area = (second != null && (i == 2 || i == 5)) ? second : main;
      var t = templates[area]!.days[i];
      if (activityLimited && t.movement) t = limited.days[i];
      final gentle = gentleToday && i == 0;
      final m = gentle ? TimeSizes.all.first : size;
      final smaller = TimeSizes.smaller(m);
      final date = DateTime(start.year, start.month, start.day + i);
      days.add(
        PlanDay(
          date: _dateKey(date),
          dayNumber: i + 1,
          focus: area,
          title: t.titleFor(m),
          reason: gentle ? gentleReason : t.reason,
          anchor: t.anchor,
          minutes: m,
          smallerTitle: smaller == null ? null : t.titleFor(smaller),
          smallerMinutes: smaller,
          gentle: gentle,
        ),
      );
    }

    // Supporting habits: the main focus's first, then the second focus's
    // first (or the main focus's second); never movement when limited.
    final candidates = [
      ...templates[main]!.supporting.take(1),
      if (second != null) ...templates[second]!.supporting.take(1),
      ...templates[main]!.supporting.skip(1),
      if (activityLimited) ...limited.supporting,
    ];
    final supporting = <SupportingHabit>[];
    for (final s in candidates) {
      if (supporting.length == StarterPlan.maxSupporting) break;
      if (activityLimited && s.movement) continue;
      if (supporting.any((x) => x.id == s.id)) continue;
      supporting.add(s);
    }
    return StarterPlan(days: days, supporting: supporting);
  }

  /// FR-DLY-08: after the week, offer a bigger step when done on 5 or more
  /// of 7 days, a smaller one under 2. The person must accept any change.
  static int suggestedNextSize(int current, int daysDone) {
    if (daysDone >= 5) return TimeSizes.larger(current);
    if (daysDone < 2) return TimeSizes.smaller(current) ?? current;
    return current;
  }
}

/// Templates can only be used outside dev once the clinical team approves
/// them; dev may use pending ones (T-ONB-03e).
bool templatesUsable({
  required bool isDev,
  required Iterable<PlanTemplate> t,
}) => isDev || t.every((x) => x.approved);
