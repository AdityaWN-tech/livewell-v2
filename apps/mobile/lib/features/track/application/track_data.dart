import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart';
import '../domain/track_stats.dart';

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
  if (ref.watch(authServiceProvider).currentUser == null) return const [];
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

/// Apple Health / Health Connect data: steps and sleep hours appear only
/// with that connection and its consent (T-UI-02e). Not built yet, so only
/// the dev preview has sample values.
/// TODO(T-HLT-01): read from the Health integration with its consent.
class HealthSummary {
  const HealthSummary({
    required this.stepsWeek,
    required this.stepsGoal,
    required this.sleepMinutesAverage,
  });

  /// Monday to Sunday; 0 for a day without data.
  final List<int> stepsWeek;
  final int stepsGoal;
  final int sleepMinutesAverage;
}

final healthSummaryProvider = Provider<HealthSummary?>(
  (ref) => ref.watch(previewModeProvider)
      ? const HealthSummary(
          stepsWeek: PreviewSamples.stepsWeek,
          stepsGoal: PreviewSamples.stepsGoal,
          sleepMinutesAverage: PreviewSamples.sleepMinutesAverage,
        )
      : null,
);

/// Habits kept per day, Monday to Sunday, or null until habit logs exist.
/// TODO(T-GOL-01): count users/{uid}/habit_logs.
final habitsWeekProvider = Provider<List<int>?>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.habitsWeek : null,
);
