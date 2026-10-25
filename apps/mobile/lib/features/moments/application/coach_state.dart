import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/time/clock.dart';
import '../../checkin/domain/checkin.dart';
import '../../home/application/home_data.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show reminderTimesProvider;
import '../../starter_plan/domain/touchpoints.dart';
import '../domain/coach_message.dart';
import 'moment_launcher.dart';

/// The coach's resting face for each moment, as in its script file. Also
/// used where there is no message to read it from (prod before review).
AvatarExpression faceForMoment(Moment m) => switch (m) {
  Moment.morning || Moment.firstHello => AvatarExpression.waving,
  Moment.stepDone || Moment.streakMilestone => AvatarExpression.celebrating,
  Moment.evening => AvatarExpression.listening,
  Moment.gentle => AvatarExpression.calm,
  // Encouraging uses the happy face until the art kit has its own.
  Moment.stepReminder ||
  Moment.missedDay ||
  Moment.weeklyReview ||
  Moment.checkInGood ||
  Moment.checkInOkay ||
  Moment.routineItem => AvatarExpression.happy,
};

/// Voice off: the moments show text only and celebrations are silent.
/// Set by the mute button in a moment (T-DLY-03d).
/// TODO(T-DLY-03e): kept as the "Show text only" setting.
class CoachMuted extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool muted) => state = muted;
}

final coachMutedProvider = NotifierProvider<CoachMuted, bool>(CoachMuted.new);

/// A red flag came up today (the check-in showed a safety response): the
/// coach stays quiet for the rest of the day, no moments and no
/// celebration voice. Safety messages are never Avatar Moments.
/// TODO(D-22): kept with the recorded safety event, so a restart keeps it.
class SafetyHold extends Notifier<String?> {
  @override
  String? build() => null;

  void holdToday() => state = localDateKey(ref.read(clockProvider)());
}

final safetyHoldStoreProvider = NotifierProvider<SafetyHold, String?>(
  SafetyHold.new,
);

final safetyHoldTodayProvider = Provider<bool>(
  (ref) =>
      ref.watch(safetyHoldStoreProvider) ==
      localDateKey(ref.watch(clockProvider)()),
);

/// The moment the coach on Home is in now: Done once the step is done, the
/// gentle one on a gentle day, else by the time of day (morning until the
/// step reminder, the step until the evening, then the evening).
final heroMomentProvider = Provider<Moment>((ref) {
  // After a safety response the coach on Home stays calm: never smiling
  // or celebrating near safety content (T-AVT-08f).
  if (ref.watch(safetyHoldTodayProvider)) return Moment.gentle;
  if (ref.watch(stepProgressProvider).done) return Moment.stepDone;
  if (ref.watch(todayCheckInProvider).value?.gentleDay ?? false) {
    return Moment.gentle;
  }
  final now = ref.watch(clockProvider)();
  final t = ClockTime(now.hour, now.minute);
  final times =
      ref.watch(reminderTimesProvider).value ?? const TouchpointTimes();
  if (t.compareTo(times.midday) < 0 && now.hour >= 5) {
    return ref.watch(morningMomentProvider).value ?? Moment.morning;
  }
  if (t.compareTo(times.evening) < 0 && now.hour >= 5) {
    return Moment.stepReminder;
  }
  return Moment.evening;
});
