import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/plan/domain/driver_wheel.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';

/// FR-GAM-02: the 8-driver wheel's 30-day fill, from one provisional data
/// source (content/plan/drivers.json, D-87).
void main() {
  final source = File('../../content/plan/drivers.json').readAsStringSync();
  final catalog = DriverCatalog.parse(source);
  final focus = FocusMap.parse(
    File('../../content/plan/focus_to_driver.json').readAsStringSync(),
  );

  test('the app copy matches content/plan/drivers.json', () {
    expect(File('assets/plan/drivers.json').readAsStringSync(), source);
  });

  test('8 drivers, provisional, numbered only: no invented clinical names', () {
    expect(catalog.drivers.length, 8);
    // Until the assessment content (T-ASM-01) names them, the labels must
    // stay neutral numbers. Replace this test with the approved names then.
    expect(catalog.provisional, isTrue);
    expect(catalog.reviewStatus, 'pending');
    for (final (i, d) in catalog.drivers.indexed) {
      expect(d.index, i);
      expect(d.label, 'Driver ${i + 1}');
    }
  });

  test('every provisional focus driver key has one segment', () {
    for (final f in FocusArea.values) {
      expect(catalog.indexOf(focus.driverOf(f)), isNotNull, reason: f.id);
    }
  });

  PlanDay day(String date, FocusArea f, {bool support = true}) => PlanDay(
    date: date,
    dayNumber: 1,
    focus: f,
    title: 't',
    reason: 'r',
    anchor: 'a',
    minutes: 5,
    smallerTitle: null,
    smallerMinutes: null,
    gentle: false,
    supporting: [
      if (support)
        const SupportingHabit(
          id: 'water',
          title: 'Water',
          anchor: 'Breakfast',
          movement: false,
        ),
    ],
  );

  test('no plan days: no fill (the wheel stays grey)', () {
    expect(
      DriverWheel.completion(
        catalog: catalog,
        focus: focus,
        planDays: const [],
        doneLogIds: const {},
        today: '2026-10-30',
      ),
      isNull,
    );
  });

  test('each segment is done / planned for its driver over the days', () {
    final move = catalog.indexOf(focus.driverOf(FocusArea.moveMore))!;
    final sleep = catalog.indexOf(focus.driverOf(FocusArea.sleepBetter))!;
    final c = DriverWheel.completion(
      catalog: catalog,
      focus: focus,
      planDays: [
        day('2026-10-27', FocusArea.moveMore),
        day('2026-10-28', FocusArea.moveMore),
        day('2026-10-29', FocusArea.sleepBetter, support: false),
        // Future days don't count.
        day('2026-10-31', FocusArea.sleepBetter, support: false),
      ],
      doneLogIds: {
        '2026-10-27_daily_step',
        '2026-10-27_support-water',
        '2026-10-28_daily_step',
        '2026-10-29_daily_step',
      },
      today: '2026-10-30',
    )!;
    expect(c.length, 8);
    expect(c[move], 0.75); // 3 of 4
    expect(c[sleep], 1.0); // 1 of 1
    expect(c.where((x) => x == 0).length, 6);
  });

  test("today's habits count only once done", () {
    final move = catalog.indexOf(focus.driverOf(FocusArea.moveMore))!;
    List<double> on(Set<String> done) => DriverWheel.completion(
      catalog: catalog,
      focus: focus,
      planDays: [
        day('2026-10-29', FocusArea.moveMore, support: false),
        day('2026-10-30', FocusArea.moveMore, support: false),
      ],
      doneLogIds: done,
      today: '2026-10-30',
    )!;
    expect(on({'2026-10-29_daily_step'})[move], 1.0);
    expect(on({'2026-10-29_daily_step', '2026-10-30_daily_step'})[move], 1.0);
    expect(on({'2026-10-30_daily_step'})[move], 0.5);
  });
}
