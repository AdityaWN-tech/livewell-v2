/// One daily cap across every locally scheduled notification (T-DLY-04,
/// FR-TCH-01, D-71): the plan's touchpoints and the routine's reminders
/// together never pass [NotificationCaps.perDay] on any day. Pure, so it can
/// be tested.
library;

import '../../checkin/domain/checkin.dart' show localDateKey;
import '../../routine/domain/routine_reminders.dart';
import 'touchpoints.dart';

/// Which plan touchpoint keeps its slot first when a day is short of room:
/// the morning greeting (it carries today's step), the step's nudge, the
/// evening reflection, then the weekly review. Routine reminders come after
/// all of them, earliest first (D-71).
const planCapPriority = [
  TouchpointKind.greeting,
  TouchpointKind.nudge,
  TouchpointKind.reflection,
  TouchpointKind.weekly,
];

/// What is left to schedule after the daily cap.
class CappedReminders {
  const CappedReminders({required this.plan, required this.routine});

  final List<ScheduledTouchpoint> plan;
  final List<RoutineReminder> routine;

  /// Every notification time, plan and routine together.
  Iterable<DateTime> get times => [
    for (final p in plan) p.when,
    for (final r in routine) r.when,
  ];
}

/// Keeps at most [perDay] notifications on each local date, plan and routine
/// together. [used] counts notifications already shown on a date (today's,
/// before now) so a reschedule late in the day can't top it up past the cap.
/// Inputs are expected to have passed quiet hours and their own caps
/// already; the order of each list is kept.
CappedReminders capPerDay({
  required List<ScheduledTouchpoint> plan,
  required List<RoutineReminder> routine,
  Map<String, int> used = const {},
  int perDay = NotificationCaps.perDay,
}) {
  final left = <String, int>{};
  bool take(DateTime when) {
    final date = localDateKey(when);
    final n = left[date] ??= perDay - (used[date] ?? 0);
    if (n <= 0) return false;
    left[date] = n - 1;
    return true;
  }

  final keptPlan = <ScheduledTouchpoint>{};
  final byPriority = [...plan]
    ..sort((a, b) {
      final d = localDateKey(a.when).compareTo(localDateKey(b.when));
      if (d != 0) return d;
      return planCapPriority
          .indexOf(a.kind)
          .compareTo(planCapPriority.indexOf(b.kind));
    });
  for (final p in byPriority) {
    if (take(p.when)) keptPlan.add(p);
  }
  final keptRoutine = <RoutineReminder>{};
  final byTime = [...routine]..sort((a, b) => a.when.compareTo(b.when));
  for (final r in byTime) {
    if (take(r.when)) keptRoutine.add(r);
  }
  return CappedReminders(
    plan: [
      for (final p in plan)
        if (keptPlan.contains(p)) p,
    ],
    routine: [
      for (final r in routine)
        if (keptRoutine.contains(r)) r,
    ],
  );
}

/// The notification times scheduled for one date at the last reschedule,
/// kept on the phone. Those at or before now have been shown, so they count
/// toward that date's cap at the next reschedule (D-71).
class ReminderLedger {
  const ReminderLedger(this.date, this.times);

  /// Local date, yyyy-mm-dd.
  final String date;
  final List<DateTime> times;

  /// How many were shown on [now]'s date by [now]. Another date counts 0.
  List<DateTime> shownBy(DateTime now) => date != localDateKey(now)
      ? const []
      : [
          for (final t in times)
            if (!t.isAfter(now)) t,
        ];

  /// The ledger to keep after scheduling [capped] at [now]: what was shown
  /// today so far plus what is now scheduled for later today.
  static ReminderLedger next(
    ReminderLedger? before,
    DateTime now,
    CappedReminders capped,
  ) {
    final today = localDateKey(now);
    return ReminderLedger(today, [
      ...?before?.shownBy(now),
      for (final t in capped.times)
        if (t.isAfter(now) && localDateKey(t) == today) t,
    ]);
  }
}
