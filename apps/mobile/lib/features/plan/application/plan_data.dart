import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../domain/plan_models.dart';

/// Today's habits for the Plan tab. Empty until habits can be created.
/// TODO(T-GOL-01): read users/{uid}/habits (active) and today's
/// users/{uid}/habit_logs for the status.
final planHabitsProvider = Provider<List<PlanHabit>>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.habits : const [],
);
