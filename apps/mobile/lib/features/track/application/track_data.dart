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
import '../data/health_source.dart';
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

/// Habits kept per day, Monday to Sunday, or null until habit logs exist.
/// TODO(T-GOL-01): count users/{uid}/habit_logs.
final habitsWeekProvider = Provider<List<int>?>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.habitsWeek : null,
);
