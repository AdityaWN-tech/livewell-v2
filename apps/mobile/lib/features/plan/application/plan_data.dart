import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal.dart';
import '../../home/application/home_data.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../domain/plan_models.dart';

/// Today's habits for the Plan tab: today's step (the same one Home shows,
/// in the same Done / smaller state) as the daily microhabit, then the
/// plan's supporting habits, then the person's own (2 in all, FR-GOL-01).
/// Done marks come from today's habit_logs.
final planHabitsProvider = Provider<List<PlanHabit>>((ref) {
  final preview = ref.watch(previewModeProvider);
  final step = ref.watch(todayStepProvider);
  final progress = ref.watch(stepProgressProvider);
  // A gentle day uses the smaller step, as Home does (FR-DLY-02).
  final small =
      progress.smaller ||
      (ref.watch(todayCheckInProvider).value?.gentleDay ?? false);
  final sample = preview
      ? PreviewSamples.habits.firstWhere((h) => h.role == HabitRole.microhabit)
      : null;
  final done = progress.doneAt;
  final logged = {
    for (final log in ref.watch(todayHabitLogsProvider).value ?? const [])
      log.habitId: log.doneAt,
  };
  HabitStatus statusOf(String id) =>
      logged.containsKey(id) ? HabitStatus.done : HabitStatus.scheduled;
  TimeOfDay? doneAt(String id) => switch (logged[id]) {
    final at? => TimeOfDay.fromDateTime(at),
    null => null,
  };
  return [
    if (step != null)
      PlanHabit(
        id: 'today-step',
        role: HabitRole.microhabit,
        driver: step.driver,
        title: small && step.smallerTitle != null
            ? step.smallerTitle!
            : step.title,
        status: progress.done
            ? HabitStatus.done
            : (sample?.status ?? HabitStatus.scheduled),
        target: sample?.target,
        microstep: sample?.microstep,
        minutes: small && step.smallerMinutes != null
            ? step.smallerMinutes
            : step.minutes,
        completedAt: done == null ? null : TimeOfDay.fromDateTime(done),
      ),
    if (preview)
      for (final h in PreviewSamples.habits.where(
        (h) => h.role == HabitRole.supporting,
      ))
        logged.containsKey(h.id)
            ? h.copyWith(status: HabitStatus.done, completedAt: doneAt(h.id))
            : h,
    if (!preview)
      for (final s
          in ref.watch(todayPlanProvider).value?.supporting ?? const [])
        PlanHabit(
          id: 'support-${s.id}',
          role: HabitRole.supporting,
          driver: s.anchor,
          title: s.title,
          status: statusOf('support-${s.id}'),
          completedAt: doneAt('support-${s.id}'),
        ),
    if (!preview)
      for (final h in ref.watch(userHabitsProvider).value ?? const [])
        if (h.active)
          PlanHabit(
            id: h.id,
            role: HabitRole.supporting,
            driver: '',
            title: h.title,
            status: statusOf(h.id),
            completedAt: doneAt(h.id),
            anchor: h.anchor,
            minutes: h.minutes,
            own: true,
          ),
  ];
});

/// The person's own habits (Step 4a), active or stopped.
final userHabitsProvider = StreamProvider<List<UserHabit>>(
  (ref) => ref.watch(goalRepositoryProvider).watchHabits(),
);

/// Today's habit Done marks.
final todayHabitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final today = localDateKey(ref.watch(clockProvider)());
  return ref.watch(goalRepositoryProvider).watchLogs(today);
});

/// The saved 30-day goal (Step 4a), or null before one is set.
final goalProvider = StreamProvider<Goal?>(
  (ref) => ref.watch(goalRepositoryProvider).watchGoal(),
);

/// The 8 drivers, in their fixed order.
/// needs-product: Dr. Gokula's driver names and order aren't in the content
/// files yet, so these are numbered placeholders (the mockup's names are
/// samples). TODO(T-CNT): load content/drivers.json once it exists.
final driversProvider = Provider<List<Driver>>(
  (ref) => [
    for (var i = 0; i < 8; i++) Driver(index: i, label: 'Driver ${i + 1}'),
  ],
);

/// 30-day completion per driver (FR-GAM-02), or null before the 10-minute
/// assessment: the wheel is then soft grey.
/// TODO(T-ASM-01, T-GAM-02): compute from the assessment and habit logs.
final driverCompletionProvider = Provider<List<double>?>(
  (ref) =>
      ref.watch(previewModeProvider) ? PreviewSamples.driverCompletion : null,
);

/// The 30-day goal card, or null before a goal is set.
final planGoalProvider = Provider<PlanGoal?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.goal;
  final g = ref.watch(goalProvider).value;
  if (g == null) return null;
  final today = localDateKey(ref.watch(clockProvider)());
  return PlanGoal(
    title: g.action,
    day: g.dayOn(today),
    progress: g.progressOn(today),
    paused: g.status == GoalStatus.paused,
  );
});

/// The plan's days from today on (calendar button).
final weekPlanProvider = FutureProvider<List<WeekDay>>((ref) async {
  if (ref.watch(previewModeProvider)) return PreviewSamples.week;
  if (ref.watch(signedInUidProvider) == null) return const [];
  final repo = ref.watch(planRepositoryProvider);
  final today = localDateKey(ref.watch(clockProvider)());
  try {
    final dates = (await repo.datesFrom(today)).take(7);
    return [
      for (final date in dates)
        if (await repo.watchDay(date).first case final d?)
          WeekDay(
            dayNumber: d.dayNumber,
            date: date,
            title: d.title,
            minutes: d.minutes,
          ),
    ];
  } catch (_) {
    // Offline: the sheet says the plan will show when back online.
    return const [];
  }
});
