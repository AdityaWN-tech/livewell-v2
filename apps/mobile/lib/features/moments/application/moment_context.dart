import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart';
import '../../track/presentation/track_screen.dart' show streakProvider;
import '../../voice/data/voice_repository.dart';
import '../../voice/domain/voice.dart';
import '../data/moment_templates_provider.dart';
import '../domain/coach_message.dart';
import '../domain/moment_builder.dart';
import 'coach_state.dart';

/// What the builder may use today: the person's first name and Why, today's
/// step from the plan, the streak (T-DLY-03a). Nothing from the check-in's
/// answers goes into a script.
final momentContextProvider = Provider<MomentContext>((ref) {
  final step = ref.watch(todayStepProvider);
  final why = ref.watch(previewModeProvider)
      ? 'I want energy to travel with my family.'
      : ref.watch(currentProfileProvider).value?.whyStatement;
  return MomentContext(
    now: ref.watch(clockProvider)(),
    firstName: ref.watch(firstNameProvider),
    coachName: ref.watch(coachNameProvider),
    why: why,
    step: step == null
        ? null
        : MomentStep(
            title: step.title,
            minutes: step.minutes,
            smallerTitle: step.smallerTitle,
            smallerMinutes: step.smallerMinutes,
          ),
    streakDays: ref.watch(streakProvider)?.length,
    // TODO(T-GOL-01): steps done this week, from habit_logs.
    weeklyCount: ref.watch(previewModeProvider)
        ? PreviewSamples.habitsWeek.length
        : null,
    // A red flag in today's check-in (T-DLY-03d); TODO(D-22): from the
    // recorded safety events, so it survives a restart.
    safetyHold: ref.watch(safetyHoldTodayProvider),
  );
});

/// The message for [moment] today, or null (nothing safe or approved).
final coachMessageProvider = FutureProvider.family<CoachMessage?, Moment>((
  ref,
  moment,
) async {
  final builder = await ref.watch(momentBuilderProvider.future);
  return builder.build(moment, ref.watch(momentContextProvider));
});

/// The person's voice speed (0.8x to 1.2x, FR-VOC-01), for the player.
final coachVoiceSpeedProvider = FutureProvider<double>((ref) async {
  try {
    final choice = await ref.watch(voiceRepositoryProvider).current();
    return choice?.speed ?? VoiceChoice.fallback.speed;
  } catch (_) {
    return VoiceChoice.fallback.speed;
  }
});
