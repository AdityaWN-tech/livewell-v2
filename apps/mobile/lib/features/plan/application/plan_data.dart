import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart' show driverWheelOnProvider;

import '../../../core/time/clock.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal.dart';
import '../../home/application/home_data.dart';
import '../../focus/presentation/focus_screen.dart' show focusMapProvider;
import '../../starter_plan/data/plan_repository.dart';
import '../../starter_plan/domain/starter_plan.dart' show PlanDay;
import '../domain/driver_wheel.dart';
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

/// content/plan/drivers.json (copied to assets/plan/): the one source of
/// the 8 drivers. PROVISIONAL, pending clinical review (D-87): Dr. Gokula's
/// driver names come with the assessment content (T-ASM-01), so the labels
/// are numbers only (the mockup's names are samples).
final driverCatalogProvider = FutureProvider<DriverCatalog>((ref) async {
  try {
    return DriverCatalog.parse(
      await rootBundle.loadString('assets/plan/drivers.json', cache: false),
    );
  } catch (_) {
    return DriverCatalog.fallback;
  }
});

/// The 8 drivers, in their fixed order (numbered until the file loads).
final driversProvider = Provider<List<Driver>>(
  (ref) => (ref.watch(driverCatalogProvider).value ?? DriverCatalog.fallback)
      .drivers,
);

/// The plan's days and the habit logs of the last 30 days (FR-GAM-02).
final _wheelDataProvider =
    FutureProvider<({List<PlanDay> days, Set<String> logs})>((ref) async {
      ref.watch(todayHabitLogsProvider);
      final now = ref.watch(clockProvider)();
      final from = localDateKey(
        DateTime(now.year, now.month, now.day - (DriverWheel.days - 1)),
      );
      final to = localDateKey(now);
      final days = await ref
          .watch(planRepositoryProvider)
          .daysBetween(from, to);
      final logs = await ref
          .watch(goalRepositoryProvider)
          .logsBetween(from, to);
      return (days: days, logs: {for (final l in logs) l.id});
    });

/// 30-day completion per driver (FR-GAM-02), or null before there is a
/// plan: the wheel is then soft grey. Behind the `driverWheel` flag (dev
/// only) while the drivers are provisional (D-87).
final driverCompletionProvider = Provider<List<double>?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.driverCompletion;
  if (!ref.watch(driverWheelOnProvider)) return null;
  final catalog = ref.watch(driverCatalogProvider).value;
  final focus = ref.watch(focusMapProvider).value;
  final data = ref.watch(_wheelDataProvider).value;
  if (catalog == null || focus == null || data == null) return null;
  return DriverWheel.completion(
    catalog: catalog,
    focus: focus,
    planDays: data.days,
    doneLogIds: data.logs,
    today: localDateKey(ref.watch(clockProvider)()),
  );
});

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
