import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../starter_plan/domain/starter_plan.dart';
import '../../account/data/profile_repository.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../domain/home_models.dart';

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

/// The coach's name from settings; null means the default "Coach".
/// TODO(T-AVT-01): read the name chosen in Avatar Studio.
final coachNameProvider = Provider<String?>((ref) => null);

/// Today's planned day: the starter plan (T-ONB-03e) or, later, the
/// nightly plan, from users/{uid}/daily_plans/{date}.
final todayPlanProvider = StreamProvider<PlanDay?>((ref) {
  if (ref.watch(previewModeProvider) ||
      ref.watch(authServiceProvider).currentUser == null) {
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
