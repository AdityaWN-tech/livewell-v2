import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../starter_plan/domain/starter_plan.dart';
import '../../account/data/profile_repository.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../domain/home_models.dart';

/// True when check-ins can be saved: signed in, or the dev preview.
final canCheckInProvider = Provider<bool>(
  (ref) =>
      ref.watch(previewModeProvider) || ref.watch(signedInUidProvider) != null,
);

/// Today's check-in (local date), live. Re-read on resume so the day
/// changes after midnight.
final todayCheckInProvider = StreamProvider<CheckIn?>((ref) {
  if (!ref.watch(canCheckInProvider)) return Stream.value(null);
  final today = localDateKey(ref.watch(clockProvider)());
  return ref.watch(checkInRepositoryProvider).watchDay(today);
});

/// The person's first name for the greeting, or null.
final firstNameProvider = Provider<String?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.firstName;
  final name = ref.watch(currentProfileProvider).value?.displayName?.trim();
  if (name == null || name.isEmpty) return null;
  return name.split(RegExp(r'\s+')).first;
});

/// Day N since the account was created, or null while unknown.
final dayNumberProvider = Provider<int?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.day;
  final created = ref.watch(currentProfileProvider).value?.createdAt;
  if (created == null) return null;
  return dayNumber(created.toLocal(), ref.watch(clockProvider)());
});

/// The coach's name from Profile > My coach; null means "Coach".
final coachNameProvider = Provider<String?>(
  (ref) => ref.watch(currentProfileProvider).value?.coachName,
);

/// Today's planned day: the starter plan (T-ONB-03e) or, later, the
/// nightly plan, from users/{uid}/daily_plans/{date}.
final todayPlanProvider = StreamProvider<PlanDay?>((ref) {
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return Stream.value(null);
  }
  final today = localDateKey(ref.watch(clockProvider)());
  return ref.watch(planRepositoryProvider).watchDay(today);
});

/// Today's next step: the plan's step; sample data in the dev preview.
/// TODO(T-DLY-03): save Done to users/{uid}/habit_logs.
final todayStepProvider = Provider<TodayStep?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.step;
  final day = ref.watch(todayPlanProvider).value;
  if (day == null) return null;
  return TodayStep(
    driver: day.anchor,
    title: day.title,
    reason: day.reason,
    minutes: day.minutes,
    smallerTitle: day.smallerTitle,
    smallerMinutes: day.smallerMinutes,
  );
});

/// Phase progress and habits kept. Null until habits and streaks exist.
/// TODO(T-GOL-01): compute from habits and habit_logs.
final milestoneProvider = Provider<Milestone?>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.milestone : null,
);

/// Done and "make it smaller" for today's step, shared by Home and Plan so
/// both always show the same step in the same state (T-UI-02 phone bug).
/// TODO(T-DLY-03): save Done to users/{uid}/habit_logs.
class StepProgress {
  const StepProgress({
    required this.date,
    this.done = false,
    this.smaller = false,
    this.doneAt,
  });

  /// Local date it applies to; another day starts fresh.
  final String date;
  final bool done;
  final bool smaller;
  final DateTime? doneAt;
}

class StepProgressNotifier extends Notifier<StepProgress> {
  String get _today => localDateKey(ref.read(clockProvider)());

  @override
  StepProgress build() => StepProgress(date: _today);

  StepProgress get _current =>
      state.date == _today ? state : StepProgress(date: _today);

  void markDone() => state = StepProgress(
    date: _today,
    done: true,
    smaller: _current.smaller,
    doneAt: ref.read(clockProvider)(),
  );

  void makeSmaller() => state = StepProgress(
    date: _today,
    done: _current.done,
    smaller: true,
    doneAt: _current.doneAt,
  );
}

final _stepProgressStore = NotifierProvider<StepProgressNotifier, StepProgress>(
  StepProgressNotifier.new,
);

/// Today's progress (a new day is always fresh).
final stepProgressProvider = Provider<StepProgress>((ref) {
  final s = ref.watch(_stepProgressStore);
  final today = localDateKey(ref.watch(clockProvider)());
  return s.date == today ? s : StepProgress(date: today);
});

final stepProgressActionsProvider = Provider<StepProgressNotifier>(
  (ref) => ref.read(_stepProgressStore.notifier),
);
