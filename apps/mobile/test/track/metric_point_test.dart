import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/track/application/track_data.dart';
import 'package:livewell/features/track/domain/chart_series.dart';
import 'package:livewell/features/track/domain/metric_point.dart';
import 'package:livewell/features/track/domain/track_stats.dart';

/// T-GOL-02 (FR-GOL-04/05, D-72): recorded measures and the 7/30/90-day
/// chart's bars.
void main() {
  final now = DateTime(2026, 10, 14, 8, 30); // a Wednesday

  group('limits (same as firestore.rules)', () {
    MetricPoint w(double v, WeightUnit u, {DateTime? at}) =>
        MetricPoint.weight(id: 'w', kgOrLb: v, unit: u, measuredAt: at ?? now);
    MetricPoint bp(int s, int d) => MetricPoint.bloodPressure(
      id: 'b',
      systolic: s,
      diastolic: d,
      measuredAt: now,
    );
    MetricPoint g(int v) =>
        MetricPoint.glucose(id: 'g', mgDl: v, measuredAt: now);

    test('weight: 20 to 300 kg, 44 to 660 lb', () {
      expect(w(20, WeightUnit.kg).isValidAt(now), isTrue);
      expect(w(300, WeightUnit.kg).isValidAt(now), isTrue);
      expect(w(19.9, WeightUnit.kg).isValidAt(now), isFalse);
      expect(w(301, WeightUnit.kg).isValidAt(now), isFalse);
      expect(w(660, WeightUnit.lb).isValidAt(now), isTrue);
      expect(w(43, WeightUnit.lb).isValidAt(now), isFalse);
    });

    test('blood pressure: 50-260 over 30-160, top higher', () {
      expect(bp(120, 80).isValidAt(now), isTrue);
      // Recorded as it is: the app never judges a value inside the limits.
      expect(bp(220, 130).isValidAt(now), isTrue);
      expect(bp(80, 80).isValidAt(now), isFalse);
      expect(bp(261, 90).isValidAt(now), isFalse);
      expect(bp(120, 29).isValidAt(now), isFalse);
    });

    test('glucose: whole mg/dL from 20 to 600', () {
      expect(g(20).isValidAt(now), isTrue);
      expect(g(600).isValidAt(now), isTrue);
      expect(g(19).isValidAt(now), isFalse);
      expect(g(601).isValidAt(now), isFalse);
      expect(g(98).valueFields(), {'value': 98, 'unit': 'mg/dL'});
    });

    test('not in the future, at most 30 days back', () {
      expect(
        w(
          70,
          WeightUnit.kg,
          at: now.add(const Duration(hours: 1)),
        ).isValidAt(now),
        isFalse,
      );
      expect(
        w(
          70,
          WeightUnit.kg,
          at: now.subtract(const Duration(days: 29)),
        ).isValidAt(now),
        isTrue,
      );
      expect(
        w(
          70,
          WeightUnit.kg,
          at: now.subtract(const Duration(days: 31)),
        ).isValidAt(now),
        isFalse,
      );
    });

    test('a meal needs which meal; no free text is stored', () {
      final m = MetricPoint.meal(
        id: 'm',
        meal: MealKind.lunch,
        measuredAt: now,
      );
      expect(m.isValidAt(now), isTrue);
      expect(m.valueFields(), {'meal': 'lunch'});
    });

    test('stored fields round-trip, with the source', () {
      final p = MetricPoint.bloodPressure(
        id: 'x',
        systolic: 118,
        diastolic: 76,
        measuredAt: now,
        source: MetricSource.health,
      );
      final back = MetricPoint.fromData('x', {
        'kind': p.kind.id,
        'source': p.source.id,
        ...p.valueFields(),
      }, now)!;
      expect(back.systolic, 118);
      expect(back.diastolic, 76);
      expect(back.source, MetricSource.health);
      expect(MetricPoint.fromData('y', {'kind': 'steps'}, now), isNull);
    });
  });

  test('units: pounds in the US, kilograms elsewhere; conversion', () {
    expect(WeightUnit.forRegion('US'), WeightUnit.lb);
    expect(WeightUnit.forRegion('IN'), WeightUnit.kg);
    expect(WeightUnit.forRegion(null), WeightUnit.kg);
    expect(WeightUnit.kg.convert(100, WeightUnit.lb), closeTo(220.46, 0.01));
    expect(WeightUnit.lb.convert(220.462, WeightUnit.kg), closeTo(100, 0.01));
    expect(parseMeasure(' 72,5 '), 72.5);
    expect(parseMeasure('abc'), isNull);
  });

  group('chart bars (FR-GOL-05)', () {
    test('This Week: 7 days, Monday to Sunday', () {
      final b = chartBuckets(TrackPeriod.week, now);
      expect(b, hasLength(7));
      expect(b.first.first, DateTime(2026, 10, 12));
      expect(b.last.last, DateTime(2026, 10, 18));
      expect(b.every((x) => x.isDay), isTrue);
    });

    test('This Month: weeks from the 1st to the month end', () {
      final b = chartBuckets(TrackPeriod.month, now);
      // Oct 2026: Thu 1st .. Sat 31st.
      expect(b.first.first, DateTime(2026, 10, 1));
      expect(b.first.last, DateTime(2026, 10, 4));
      expect(b[1].first, DateTime(2026, 10, 5));
      expect(b.last.last, DateTime(2026, 10, 31));
      expect(b, hasLength(5));
    });

    test('90 days: weeks back to 90 days ago, ending today', () {
      final b = chartBuckets(TrackPeriod.quarter, now);
      expect(b.first.first, DateTime(2026, 7, 17));
      expect(b.last.last, DateTime(2026, 10, 14));
      expect(b.length, inInclusiveRange(13, 14));
      final days = b.expand((x) => x.dates).toList();
      expect(days, hasLength(90));
      expect(days.toSet(), hasLength(90));
    });

    test('a daylight-saving change never shifts a week', () {
      final b = chartBuckets(TrackPeriod.month, DateTime(2026, 11, 20));
      expect(b.map((x) => x.first.weekday).skip(1).toSet(), {DateTime.monday});
      expect(b.last.last, DateTime(2026, 11, 30));
    });

    test('weeks: averages of logged days, or per day so far', () {
      final b = chartBuckets(TrackPeriod.month, now);
      final daily = <String, Reading>{
        '2026-10-05': (a: 4, b: null),
        '2026-10-07': (a: 2, b: null),
        '2026-10-14': (a: 6, b: null),
        '2026-10-20': (a: 9, b: null), // after today: ignored
      };
      final mean = bucketValues(b, daily, now, Combine.mean);
      expect(mean[0], isNull);
      expect(mean[1]!.a, 3);
      expect(mean[2]!.a, 6);
      expect(mean[3], isNull);
      final perDay = bucketValues(b, daily, now, Combine.perDay);
      expect(perDay[1]!.a, closeTo(6 / 7, 0.001));
      // This week so far: Monday to Wednesday.
      expect(perDay[2]!.a, 2);
    });

    test('measures by day: weights in the shown unit, BP both numbers', () {
      final points = [
        MetricPoint.weight(
          id: '1',
          kgOrLb: 100,
          unit: WeightUnit.kg,
          measuredAt: now,
        ),
        MetricPoint.weight(
          id: '2',
          kgOrLb: 220.462,
          unit: WeightUnit.lb,
          measuredAt: now,
        ),
        MetricPoint.bloodPressure(
          id: '3',
          systolic: 120,
          diastolic: 80,
          measuredAt: now,
        ),
        MetricPoint.bloodPressure(
          id: '4',
          systolic: 130,
          diastolic: 90,
          measuredAt: now,
        ),
        MetricPoint.meal(id: '5', meal: MealKind.lunch, measuredAt: now),
        MetricPoint.meal(id: '6', meal: MealKind.dinner, measuredAt: now),
      ];
      expect(
        dailyFromPoints(
          points,
          MetricKind.weight,
          WeightUnit.kg,
        )['2026-10-14']!.a,
        closeTo(100, 0.01),
      );
      final bp = dailyFromPoints(
        points,
        MetricKind.bloodPressure,
        WeightUnit.kg,
      )['2026-10-14']!;
      expect((bp.a, bp.b), (125, 85));
      expect(
        dailyFromPoints(
          points,
          MetricKind.meal,
          WeightUnit.kg,
        )['2026-10-14']!.a,
        2,
      );
    });

    test('counts since a day, with zeros for quiet days', () {
      expect(
        countsSince(
          ['2026-10-12', '2026-10-12', '2026-10-01'],
          DateTime(2026, 10, 12),
          now,
          zeros: true,
        ),
        {'2026-10-12': 2, '2026-10-13': 0, '2026-10-14': 0},
      );
      expect(
        countsSince(['2026-10-01'], DateTime(2026, 10, 12), now, zeros: true),
        isNull,
      );
    });
  });
}
