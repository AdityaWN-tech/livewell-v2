import '../../checkin/domain/checkin.dart';

/// The Track period picker (T-UI-02e).
enum TrackPeriod {
  week,
  month,
  quarter;

  /// First local day of the period that ends on [today].
  DateTime start(DateTime today) {
    final d = DateTime(today.year, today.month, today.day);
    return switch (this) {
      // Monday of this week.
      // Calendar arithmetic, so a daylight-saving change never shifts a day.
      TrackPeriod.week => DateTime(d.year, d.month, d.day - (d.weekday - 1)),
      TrackPeriod.month => DateTime(d.year, d.month),
      TrackPeriod.quarter => DateTime(d.year, d.month, d.day - 89),
    };
  }
}

/// The values Track charts, from the check-ins (1 to 5 scales), My Daily
/// Routine (items done, T-GOL-03e) and, when connected, Apple Health /
/// Health Connect (steps, sleep hours).
enum TrackMetric { steps, sleep, mood, habits, routine }

/// One day of the Mon-Sun chart; [value] is null when nothing was logged.
class DayValue {
  const DayValue({required this.date, required this.value});

  /// YYYY-MM-DD.
  final String date;
  final double? value;
}

/// Averages and series for the metric cards.
class TrackStats {
  TrackStats(this.checkIns);

  /// Oldest first.
  final List<CheckIn> checkIns;

  static double? _avg(Iterable<int?> v) {
    final xs = v.nonNulls.toList();
    if (xs.isEmpty) return null;
    return xs.reduce((a, b) => a + b) / xs.length;
  }

  double? get mood => _avg(checkIns.map((c) => c.mood));
  double? get stress => _avg(checkIns.map((c) => c.stress));
  double? get sleep => _avg(checkIns.map((c) => c.sleep));

  /// The last [n] logged values of one answer, oldest first, for a card's
  /// mini bars.
  List<int> recent(int? Function(CheckIn) pick, {int n = 7}) {
    final v = checkIns.map(pick).nonNulls.toList();
    return v.length <= n ? v : v.sublist(v.length - n);
  }

  /// The word for an average on the check-in's 1 to 5 scale: the nearest
  /// answer, so the words stay kind and plain (never clinical).
  static int nearest(double avg) => avg.round().clamp(1, 5);
}

/// Monday to Sunday of the week containing [today], as YYYY-MM-DD keys.
List<String> weekDates(DateTime today) {
  final monday = TrackPeriod.week.start(today);
  return [
    for (var i = 0; i < 7; i++)
      localDateKey(DateTime(monday.year, monday.month, monday.day + i)),
  ];
}
