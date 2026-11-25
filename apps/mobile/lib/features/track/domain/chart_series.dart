import '../../checkin/domain/checkin.dart' show localDateKey;
import 'metric_point.dart';
import 'track_stats.dart';

/// One bar of Track's Progress chart (FR-GOL-05): a day for This Week, a
/// Monday-to-Sunday week (clipped to the period) for This Month and 90 days.
class ChartBucket {
  const ChartBucket({required this.first, required this.last});

  /// First and last local day it covers.
  final DateTime first;
  final DateTime last;

  bool get isDay => first == last;

  Iterable<String> get dates sync* {
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      yield localDateKey(d);
    }
  }
}

/// The bars for [period] ending on [now]: 7 days for This Week (Monday to
/// Sunday, later days empty), weeks for This Month (to the month's end)
/// and 90 days (13 or 14 bars).
List<ChartBucket> chartBuckets(TrackPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = period.start(today);
  if (period == TrackPeriod.week) {
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = DateTime(start.year, start.month, start.day + i);
          return ChartBucket(first: d, last: d);
        }(),
    ];
  }
  final end = period == TrackPeriod.month
      ? DateTime(today.year, today.month + 1, 0)
      : today;
  final buckets = <ChartBucket>[];
  var first = start;
  while (!first.isAfter(end)) {
    // The Sunday of first's week, or the end.
    var last = DateTime(first.year, first.month, first.day + 7 - first.weekday);
    if (last.isAfter(end)) last = end;
    buckets.add(ChartBucket(first: first, last: last));
    first = DateTime(last.year, last.month, last.day + 1);
  }
  return buckets;
}

/// A value for one day or bar: the main number and, for blood pressure,
/// the second (diastolic).
typedef Reading = ({double a, double? b});

/// How days are combined into a week's bar.
enum Combine {
  /// The average of the days that have a value (mood, sleep, steps,
  /// weight, blood pressure, glucose).
  mean,

  /// The total divided by the days so far (habits, routine items, meals):
  /// "a day" on average, so a quiet day counts as a quiet day.
  perDay,
}

/// The bars' values: null for a bar with nothing logged, and for days after
/// [now].
List<Reading?> bucketValues(
  List<ChartBucket> buckets,
  Map<String, Reading> daily,
  DateTime now,
  Combine combine,
) {
  final today = localDateKey(now);
  return [
    for (final b in buckets)
      () {
        final days = [
          for (final d in b.dates)
            if (d.compareTo(today) <= 0) d,
        ];
        final values = [for (final d in days) ?daily[d]];
        if (values.isEmpty) return null;
        final n = combine == Combine.mean ? values.length : days.length;
        final main = values.fold(0.0, (s, v) => s + v.a) / n;
        final seconds = values.map((v) => v.b).nonNulls.toList();
        final second = seconds.isEmpty
            ? null
            : seconds.fold(0.0, (s, v) => s + v) /
                  (combine == Combine.mean ? seconds.length : n);
        return (a: main, b: second);
      }(),
  ];
}

/// One day's value per date from recorded points of [kind] (Combine.mean
/// within the day; meals are counted). Weights are shown in [unit].
Map<String, Reading> dailyFromPoints(
  Iterable<MetricPoint> points,
  MetricKind kind,
  WeightUnit unit,
) {
  final byDay = <String, List<MetricPoint>>{};
  for (final p in points.where((p) => p.kind == kind)) {
    (byDay[localDateKey(p.measuredAt)] ??= []).add(p);
  }
  double avg(Iterable<double> xs) => xs.fold(0.0, (s, v) => s + v) / xs.length;
  return {
    for (final MapEntry(key: date, value: ps) in byDay.entries)
      date: switch (kind) {
        MetricKind.weight => (
          a: avg(ps.map((p) => p.weightUnit!.convert(p.value!, unit))),
          b: null,
        ),
        MetricKind.bloodPressure => (
          a: avg(ps.map((p) => p.systolic!.toDouble())),
          b: avg(ps.map((p) => p.diastolic!.toDouble())),
        ),
        MetricKind.glucose => (a: avg(ps.map((p) => p.value!)), b: null),
        MetricKind.meal => (a: ps.length.toDouble(), b: null),
      },
  };
}
