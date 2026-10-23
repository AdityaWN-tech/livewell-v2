import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/time/clock.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show reminderTimesProvider;
import '../../starter_plan/application/plan_scheduler.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../starter_plan/domain/touchpoints.dart';
import '../domain/coach_message.dart';
import '../domain/moment_builder.dart';
import 'moment_context.dart';

/// Which moment a reminder opens (T-DLY-03c). The morning one is decided
/// when it is opened: the briefing, or "missed day" after a quiet day.
Moment momentFor(TouchpointKind k) => switch (k) {
  TouchpointKind.greeting => Moment.morning,
  TouchpointKind.nudge => Moment.stepReminder,
  TouchpointKind.reflection => Moment.evening,
  TouchpointKind.weekly => Moment.weeklyReview,
};

/// Today's morning moment: "missed day" when yesterday was a plan day with
/// no check-in, else the briefing (FR-DLY-07).
/// TODO(T-GOL-01): a step done yesterday counts too, once it is recorded.
final morningMomentProvider = FutureProvider<Moment>((ref) async {
  final now = ref.watch(clockProvider)();
  final yesterday = localDateKey(DateTime(now.year, now.month, now.day - 1));
  try {
    final planDay = await ref
        .watch(planRepositoryProvider)
        .watchDay(yesterday)
        .first;
    final checkIn = planDay == null
        ? null
        : await ref.watch(checkInRepositoryProvider).watchDay(yesterday).first;
    return MomentBuilder.morningFor(
      missedYesterday: planDay != null && checkIn == null,
    );
  } catch (_) {
    return Moment.morning;
  }
});

/// The day the morning moment was last played (a trivial UI flag; spec
/// 10.4 allows SharedPreferences).
abstract class MomentSeenStore {
  Future<String?> load();
  Future<void> save(String date);
}

class SharedPrefsMomentSeenStore implements MomentSeenStore {
  static const _key = 'moment_morning_seen';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String date) async =>
      (await SharedPreferences.getInstance()).setString(_key, date);
}

final momentSeenStoreProvider = Provider<MomentSeenStore>(
  (ref) => SharedPrefsMomentSeenStore(),
);

/// The coach's first hello (T-AVT-08f) is due once, on Home right after
/// onboarding: set when onboarding ends, cleared when Home plays it (a
/// trivial UI flag in SharedPreferences, like the morning one).
abstract class FirstHelloStore {
  Future<bool> pending();
  Future<void> setPending(bool pending);
}

class SharedPrefsFirstHelloStore implements FirstHelloStore {
  static const _key = 'moment_first_hello_pending';

  @override
  Future<bool> pending() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> setPending(bool pending) async =>
      (await SharedPreferences.getInstance()).setBool(_key, pending);
}

final firstHelloStoreProvider = Provider<FirstHelloStore>(
  (ref) => SharedPrefsFirstHelloStore(),
);

final _morningSeenProvider = FutureProvider<String?>((ref) async {
  try {
    return await ref.watch(momentSeenStoreProvider).load();
  } catch (_) {
    return null;
  }
});

class MomentLauncher {
  MomentLauncher(this._ref);

  final Ref _ref;

  /// The moment a reminder's [payload] opens, or null for an unknown one.
  Future<Moment?> forPayload(String payload) async {
    final kind = TouchpointKind.values
        .where((k) => k.name == payload)
        .firstOrNull;
    if (kind == null) return null;
    final m = momentFor(kind);
    return m == Moment.morning ? _ref.read(morningMomentProvider.future) : m;
  }

  /// The morning moment was played: the Home card goes and today's
  /// reminder leaves the tray.
  Future<void> morningSeen() async {
    try {
      await _ref
          .read(momentSeenStoreProvider)
          .save(localDateKey(_ref.read(clockProvider)()));
      await _ref.read(planSchedulerProvider).dismissMorning();
    } catch (_) {
      // A UI nicety; never break the moment over it.
    }
    _ref.invalidate(_morningSeenProvider);
  }
}

final momentLauncherProvider = Provider<MomentLauncher>(MomentLauncher.new);

/// "Your coach has a message" on Home: from the morning reminder's time
/// until noon, while the morning moment hasn't been played and there is one
/// to play.
final morningCardProvider = Provider<Moment?>((ref) {
  final now = ref.watch(clockProvider)();
  final times = ref.watch(reminderTimesProvider).value;
  final seen = ref.watch(_morningSeenProvider);
  final moment = ref.watch(morningMomentProvider).value;
  if (times == null || !seen.hasValue || moment == null) return null;
  if (seen.value == localDateKey(now)) return null;
  final t = ClockTime(now.hour, now.minute);
  if (t.compareTo(times.morning) < 0 || now.hour >= 12) {
    return null;
  }
  return ref.watch(coachMessageProvider(moment)).value == null ? null : moment;
});
