import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart';
import '../../goals/data/goal_repository.dart';
import '../../plan/application/plan_data.dart' show todayHabitLogsProvider;
import '../../account/data/profile_repository.dart';
import '../../routine/application/routine_data.dart';
import '../../routine/data/routine_repository.dart';
import '../../routine/domain/routine.dart';
import '../data/metric_repository.dart';
import '../domain/metric_point.dart';
import '../data/health_source.dart';
import '../domain/streak.dart';
import '../domain/health_summary.dart';
import '../domain/track_stats.dart';

export '../domain/health_summary.dart';

/// The period picked in Track's header.
class TrackPeriodNotifier extends Notifier<TrackPeriod> {
  @override
  TrackPeriod build() => TrackPeriod.week;

  void set(TrackPeriod p) => state = p;
}

final trackPeriodProvider = NotifierProvider<TrackPeriodNotifier, TrackPeriod>(
  TrackPeriodNotifier.new,
);

/// The last 90 days of check-ins (the longest period), oldest first.
/// Refreshed when today's check-in changes.
final trackHistoryProvider = FutureProvider<List<CheckIn>>((ref) async {
  final now = ref.watch(clockProvider)();
  final todayCheckIn = ref.watch(todayCheckInProvider).value;
  final today = localDateKey(now);
  final from = localDateKey(TrackPeriod.quarter.start(now));
  if (ref.watch(previewModeProvider)) {
    return [...PreviewSamples.checkInHistory(now), ?todayCheckIn];
  }
  if (ref.watch(signedInUidProvider) == null) return const [];
  try {
    return await ref.watch(checkInRepositoryProvider).range(from, today);
  } catch (_) {
    // Offline with nothing cached: today's answer, if any.
    return [?todayCheckIn];
  }
});

/// The picked period's check-ins.
final trackStatsProvider = Provider<TrackStats?>((ref) {
  final all = ref.watch(trackHistoryProvider).value;
  if (all == null) return null;
  final from = localDateKey(
    ref.watch(trackPeriodProvider).start(ref.watch(clockProvider)()),
  );
  return TrackStats([
    for (final c in all)
      if (c.date.compareTo(from) >= 0) c,
  ]);
});

/// The health data consent (FR-ONB-03): Track reads Apple Health or
/// Health Connect only while it is granted. Revoking it in Settings >
/// Consents disconnects.
final healthConsentProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(consentRepositoryProvider)
      .watchRecords()
      .map((r) => isGranted(currentConsents(r), ConsentType.healthData)),
);

/// This week's steps and sleep from the phone's health app, read again
/// each time Track opens (Step 4f, D-59). Null without the consent, or if
/// the health app can't be read (Track then offers to connect).
final healthWeekProvider = FutureProvider.autoDispose<HealthSummary?>((
  ref,
) async {
  if (ref.watch(previewModeProvider)) {
    return const HealthSummary(
      stepsWeek: PreviewSamples.stepsWeek,
      stepsGoal: PreviewSamples.stepsGoal,
      sleepMinutesAverage: PreviewSamples.sleepMinutesAverage,
    );
  }
  if (!(ref.watch(healthConsentProvider).value ?? false)) return null;
  try {
    return await ref
        .watch(healthSourceProvider)
        .week(ref.watch(clockProvider)());
  } catch (_) {
    return null;
  }
});

final healthSummaryProvider = Provider.autoDispose<HealthSummary?>(
  (ref) => ref.watch(healthWeekProvider).value,
);

/// The dates of every habit done in the last 90 days, one entry per log
/// (the daily step and the two own habits; D-60). Read again when today's
/// logs change, so a tick shows at once.
final recentDoneDatesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(todayHabitLogsProvider);
  final now = ref.watch(clockProvider)();
  final logs = await ref
      .watch(goalRepositoryProvider)
      .logsBetween(
        localDateKey(DateTime(now.year, now.month, now.day - 90)),
        localDateKey(now),
      );
  return [for (final l in logs) l.date];
});

/// Habits kept per day, Monday to Sunday, or null with none this week.
final habitsWeekProvider = Provider<List<int>?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.habitsWeek;
  final dates = ref.watch(recentDoneDatesProvider).value;
  if (dates == null) return null;
  return habitsPerDay(dates, ref.watch(clockProvider)());
});

/// Habits kept per day in the picked period, from its first day to today
/// (0 on a day with none), or null with none in the period (the chart then
/// shows its empty state).
final habitsDailyProvider = Provider<Map<String, int>?>((ref) {
  final now = ref.watch(clockProvider)();
  final period = ref.watch(trackPeriodProvider);
  if (ref.watch(previewModeProvider)) {
    final dates = weekDates(now);
    return {
      for (var i = 0; i < now.weekday; i++)
        dates[i]: PreviewSamples.habitsWeek[i],
    };
  }
  final dates = ref.watch(recentDoneDatesProvider).value;
  if (dates == null) return null;
  return countsSince(dates, period.start(now), now, zeros: true);
});

/// My Daily Routine items done per day over the last 90 days (T-GOL-03e),
/// days with none left out (never shown as "missed"); null when there is
/// no routine yet.
final routineDailyProvider = FutureProvider<Map<String, int>?>((ref) async {
  final items = ref.watch(routineItemsProvider).value;
  if (items == null || items.isEmpty) return null;
  final now = ref.watch(clockProvider)();
  final today = localDateKey(now);
  ref.watch(routineLogsProvider(today));
  try {
    final logs = await ref
        .watch(routineRepositoryProvider)
        .logsBetween(localDateKey(TrackPeriod.quarter.start(now)), today);
    return countsSince(
      [
        for (final l in logs)
          if (l.status == RoutineStatus.done) l.date,
      ],
      TrackPeriod.quarter.start(now),
      now,
    );
  } catch (_) {
    return const {};
  }
});

/// How many times each date appears in [dates], from [first] to [now];
/// with [zeros], every day in between is there (0 if absent), and null is
/// returned when the range has none at all.
Map<String, int>? countsSince(
  Iterable<String> dates,
  DateTime first,
  DateTime now, {
  bool zeros = false,
}) {
  final from = localDateKey(first);
  final today = localDateKey(now);
  final counts = <String, int>{};
  if (zeros) {
    for (
      var d = DateTime(first.year, first.month, first.day);
      localDateKey(d).compareTo(today) <= 0;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      counts[localDateKey(d)] = 0;
    }
  }
  var any = false;
  for (final d in dates) {
    if (d.compareTo(from) < 0 || d.compareTo(today) > 0) continue;
    counts[d] = (counts[d] ?? 0) + 1;
    any = true;
  }
  return zeros && !any ? null : counts;
}

/// Steps per day for the chart in the picked period, with the steps goal
/// and when they were read (shown under the chart: every point says where
/// it came from and when, FR-GOL-04). Null without Apple Health / Health
/// Connect.
typedef HealthSteps = ({Map<String, int> days, int goal, DateTime readAt});

final healthStepsProvider = FutureProvider.autoDispose<HealthSteps?>((
  ref,
) async {
  final now = ref.watch(clockProvider)();
  final period = ref.watch(trackPeriodProvider);
  final week = await ref.watch(healthWeekProvider.future);
  if (week == null) return null;
  final today = localDateKey(now);
  final dates = weekDates(now);
  final thisWeek = {
    for (var i = 0; i < 7; i++)
      if (week.stepsWeek[i] > 0 && dates[i].compareTo(today) <= 0)
        dates[i]: week.stepsWeek[i],
  };
  if (period == TrackPeriod.week || ref.watch(previewModeProvider)) {
    return (days: thisWeek, goal: week.stepsGoal, readAt: now);
  }
  try {
    final more = await ref
        .watch(healthSourceProvider)
        .dailySteps(period.start(now), now);
    return (days: {...more, ...thisWeek}, goal: week.stepsGoal, readAt: now);
  } catch (_) {
    return (days: thisWeek, goal: week.stepsGoal, readAt: now);
  }
});

/// Recorded measures of the last 90 days, oldest first (T-GOL-02, D-72).
final metricPointsProvider = StreamProvider<List<MetricPoint>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(metricRepositoryProvider)
      .watchSince(TrackPeriod.quarter.start(now));
});

/// The eating-safe mode (FR-SAF-04): weight and meals are not offered.
final edSafeModeProvider = Provider<bool>(
  (ref) => ref.watch(currentProfileProvider).value?.edSafeMode ?? false,
);

/// The unit weights are shown in: the latest entry's, else pounds in the US
/// and kilograms elsewhere (NFR-11).
final weightUnitProvider = Provider<WeightUnit>((ref) {
  final points = ref.watch(metricPointsProvider).value ?? const [];
  for (final p in points.reversed) {
    if (p.kind == MetricKind.weight) return p.weightUnit!;
  }
  return WeightUnit.forRegion(ref.watch(currentProfileProvider).value?.region);
});
