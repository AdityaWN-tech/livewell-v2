import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
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

/// Today's next step. Null until the planner exists.
/// TODO(T-DLY-03): read users/{uid}/daily_plans/{date}.next_step.
final todayStepProvider = Provider<TodayStep?>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.step : null,
);

/// Phase progress and habits kept. Null until habits and streaks exist.
/// TODO(T-GOL-01): compute from habits and habit_logs.
final milestoneProvider = Provider<Milestone?>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.milestone : null,
);
