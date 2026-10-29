/// Apple Health / Health Connect data for Track (Step 4f, D-59): read on
/// the phone, only with the health data consent, never saved to the
/// server or shown on the lock screen.
class HealthSummary {
  const HealthSummary({
    required this.stepsWeek,
    this.stepsGoal = defaultStepsGoal,
    this.sleepMinutesAverage,
  });

  /// The steps bar's full length until goals can set it.
  static const defaultStepsGoal = 8000;

  /// Monday to Sunday; 0 for a day without data.
  final List<int> stepsWeek;
  final int stepsGoal;

  /// Average sleep a night over the last 7 nights with data; null when
  /// the health app has none (Track then shows the check-in answer).
  final int? sleepMinutesAverage;
}

/// Whether the phone can connect health data.
enum HealthAvailability {
  /// Apple Health, or Health Connect installed.
  available,

  /// Android without the Health Connect app (Android 13 and older).
  needsInstall,

  /// Neither (for example a phone too old for Health Connect).
  unavailable,
}

/// Total minutes of the sleep [sessions] (start, end) a night, averaged
/// over the nights that have any. A session belongs to the night it ends
/// on; overlapping sessions from two apps are merged so nothing counts
/// twice.
int? averageSleepMinutes(List<(DateTime, DateTime)> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(DateTime, DateTime)>[];
  for (final s in sorted) {
    if (!s.$2.isAfter(s.$1)) continue;
    if (merged.isNotEmpty && !s.$1.isAfter(merged.last.$2)) {
      final last = merged.removeLast();
      merged.add((last.$1, s.$2.isAfter(last.$2) ? s.$2 : last.$2));
    } else {
      merged.add(s);
    }
  }
  final byNight = <String, int>{};
  for (final (start, end) in merged) {
    final night = '${end.year}-${end.month}-${end.day}';
    byNight[night] = (byNight[night] ?? 0) + end.difference(start).inMinutes;
  }
  if (byNight.isEmpty) return null;
  final total = byNight.values.fold(0, (a, b) => a + b);
  return (total / byNight.length).round();
}
