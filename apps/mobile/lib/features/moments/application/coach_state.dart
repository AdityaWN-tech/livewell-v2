import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/time/clock.dart';
import '../../checkin/domain/checkin.dart';
import '../../home/application/home_data.dart';
import '../../safety/data/safety_event_store.dart';
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
  Moment.lesson => AvatarExpression.calm,
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

/// A red flag came up (the check-in showed a safety response). The time is
/// kept on the phone (survives a restart): the coach stays quiet for the
/// rest of that day, no moments and no celebration voice, and portal cards
/// stay off for 72 hours. Safety messages are never Avatar Moments.
/// TODO(D-22): also read the server's safety event record once it exists.
class SafetyHold extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() =>
      ref.watch(safetyEventStoreProvider).lastEventAt();

  /// Records a safety event now. The hold applies at once; the phone's copy
  /// is written in the background.
  Future<void> holdToday() async {
    final now = ref.read(clockProvider)();
    state = AsyncData(now);
    try {
      await ref.read(safetyEventStoreProvider).recordEvent(now);
    } catch (_) {
      // Kept in memory for this run; nothing else to do.
    }
  }
}

final safetyHoldStoreProvider = AsyncNotifierProvider<SafetyHold, DateTime?>(
  SafetyHold.new,
);

/// The coach is on today's safety hold. The phone's record loads in a few
/// milliseconds at start; until then, or if it can't be read, there is no
/// known hold (as before D-70). Portal cards use the stricter
/// [recentSafetyEventProvider], where unknown counts as an event.
final safetyHoldTodayProvider = Provider<bool>((ref) {
  final today = localDateKey(ref.watch(clockProvider)());
  final last = ref.watch(safetyHoldStoreProvider).value;
  return last != null && localDateKey(last) == today;
});

/// How long portal cards stay off after a safety event (AGENTS.md, FR-SAF-07).
const safetyPortalBlock = Duration(hours: 72);

/// A safety event in the last 72 hours on this phone. Unknown (loading or
/// unreadable) counts as yes. A time in the future (clock changed) also
/// counts as recent.
final recentSafetyEventProvider = Provider<bool>((ref) {
  final now = ref.watch(clockProvider)();
  return switch (ref.watch(safetyHoldStoreProvider)) {
    AsyncData(:final value) =>
      value != null && now.difference(value) < safetyPortalBlock,
    _ => true,
  };
});

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
