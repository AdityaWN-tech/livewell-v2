import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_catalog.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';

/// T-GOL-03b: copy a day, reorder, clashes, templates and modes.

RoutineCatalog catalog() => RoutineCatalog.parse(
  File('../../content/routine/catalog.json').readAsStringSync(),
);

const mine = Routine(
  routineId: myRoutineId,
  name: 'My routine',
  days: everyDay,
);

RoutineItem item(
  String id, {
  String time = '07:00',
  int order = 0,
  Set<Weekday>? days,
}) => RoutineItem(
  itemId: id,
  routineId: myRoutineId,
  catalogId: 'drink_water',
  label: id,
  icon: 'water',
  time: time,
  durationMin: 2,
  days: days,
  order: order,
);

List<String> ids(Iterable<RoutineItem> items) => [
  for (final i in items) i.itemId,
];

var _n = 0;
String newId() => 'n${_n++}';

void main() {
  group('copy this day to…', () {
    test('Wednesday items also fall on Saturday and Sunday', () {
      final items = [
        item('a', days: {Weekday.wed}),
        item('b', days: {Weekday.wed, Weekday.sat}),
        item('c', days: {Weekday.mon}),
      ];
      final r = copyDay([mine], items, Weekday.wed, {Weekday.sat, Weekday.sun});
      expect(r.full, isEmpty);
      final changed = {for (final i in r.changed) i.itemId: i.days};
      expect(changed.keys, unorderedEquals(['a', 'b']));
      expect(changed['a'], {Weekday.wed, Weekday.sat, Weekday.sun});
      expect(changed['b'], {Weekday.wed, Weekday.sat, Weekday.sun});
    });

    test('a day that would pass 12 items is left out', () {
      final items = [
        item('a', days: {Weekday.wed}),
        item('b', days: {Weekday.wed}),
        for (var n = 0; n < 11; n++) item('sat$n', days: {Weekday.sat}),
      ];
      final r = copyDay([mine], items, Weekday.wed, {Weekday.sat, Weekday.sun});
      expect(r.full, {Weekday.sat});
      for (final i in r.changed) {
        expect(i.days, {Weekday.wed, Weekday.sun});
      }
    });

    test('copying to the same day changes nothing', () {
      final r = copyDay(
        [mine],
        [
          item('a', days: {Weekday.wed}),
        ],
        Weekday.wed,
        {Weekday.wed},
      );
      expect(r.changed, isEmpty);
    });
  });

  group('drag to reorder', () {
    final day = [
      item('wake', time: '07:00', order: 0),
      item('water', time: '07:15', order: 1),
      item('walk', time: '08:00', order: 2),
    ];

    test('dropped after an item, it takes that time', () {
      final changed = {for (final i in reorderDay(day, 0, 1)) i.itemId: i};
      // wake now sits after water, at 7:15.
      expect(changed['wake']!.time, '07:15');
      expect(changed['wake']!.order, 1);
      expect(changed['water']!.order, 0);
      expect(changed.containsKey('walk'), isFalse);
    });

    test('dropped at the top, it takes the first time', () {
      final changed = {for (final i in reorderDay(day, 2, 0)) i.itemId: i};
      expect(changed['walk']!.time, '07:00');
      expect(changed['walk']!.order, 0);
    });

    test('not moved: nothing changes', () {
      expect(reorderDay(day, 1, 1), isEmpty);
      expect(reorderDay([day.first], 0, 0), isEmpty);
    });
  });

  test('clashes: times with two or more items', () {
    expect(
      clashes([
        item('a', time: '07:00'),
        item('b', time: '07:00'),
        item('c', time: '08:00'),
      ]),
      ['07:00'],
    );
    expect(clashes([item('a'), item('b', time: '07:01')]), isEmpty);
  });

  group('templates', () {
    test('the four quick starts, made of catalog activities', () {
      final c = catalog();
      expect(c.templates.map((t) => t.id), [
        'morning_starter',
        'workday',
        'weekend',
        'travel_day',
      ]);
      for (final t in c.templates) {
        expect(t.items.length, lessThanOrEqualTo(maxItemsPerDay));
        for (final (id, time) in t.items) {
          expect(c.byId(id), isNotNull, reason: '${t.id}: $id');
          expect(isValidTime(time), isTrue);
        }
      }
    });

    test('Workday is for Monday to Friday', () {
      final c = catalog();
      final workday = c.templates.firstWhere((t) => t.id == 'workday');
      final r = applyTemplate(
        workday,
        c,
        selected: Weekday.sat,
        routineId: 'r1',
        routineName: 'Workday',
        newId: newId,
        activityLimited: false,
        routines: const [],
        existing: const [],
      );
      expect(r.routine.days, {
        Weekday.mon,
        Weekday.tue,
        Weekday.wed,
        Weekday.thu,
        Weekday.fri,
      });
      expect(r.items, hasLength(workday.items.length));
      expect(r.items.every((i) => i.routineId == 'r1' && i.isValid), isTrue);
      expect(r.skipped, 0);
    });

    test('Travel day is just the selected day', () {
      final c = catalog();
      final travel = c.templates.firstWhere((t) => t.id == 'travel_day');
      expect(travel.days.resolve(Weekday.thu), {Weekday.thu});
    });

    test('limited activity: movement items are left out (FR-GOL-03)', () {
      final c = catalog();
      final weekend = c.templates.firstWhere((t) => t.id == 'weekend');
      final r = applyTemplate(
        weekend,
        c,
        selected: Weekday.sat,
        routineId: 'r1',
        routineName: 'Weekend',
        newId: newId,
        activityLimited: true,
        routines: const [],
        existing: const [],
      );
      expect(r.items.map((i) => i.catalogId), isNot(contains('morning_walk')));
      expect(r.items, hasLength(weekend.items.length - 1));
    });

    test('items that would pass 12 a day are skipped and counted', () {
      final c = catalog();
      final workday = c.templates.firstWhere((t) => t.id == 'workday');
      final existing = [
        for (var n = 0; n < 9; n++) item('x$n', days: {Weekday.mon}),
      ];
      final r = applyTemplate(
        workday,
        c,
        selected: Weekday.mon,
        routineId: 'r1',
        routineName: 'Workday',
        newId: newId,
        activityLimited: false,
        routines: const [mine],
        existing: existing,
      );
      expect(r.items, hasLength(3));
      expect(r.skipped, workday.items.length - 3);
    });
  });

  group('life-event modes (FR-DLY-09)', () {
    final day = [
      item('a', time: '07:00'),
      item('b', time: '08:00'),
      item('c', time: '09:00'),
      item('d', time: '10:00'),
    ];

    test('travel and busy week keep the first 3; a sick day rests', () {
      const travel = RoutineMode(kind: ModeKind.travel, until: '2026-10-20');
      const busy = RoutineMode(kind: ModeKind.busy, until: '2026-10-20');
      const sick = RoutineMode(kind: ModeKind.sick, until: '2026-10-14');
      expect(ids(activeItems(day, travel, '2026-10-14')), ['a', 'b', 'c']);
      expect(ids(activeItems(day, busy, '2026-10-20')), ['a', 'b', 'c']);
      expect(activeItems(day, sick, '2026-10-14'), isEmpty);
    });

    test('after the last day, or with no mode, everything runs', () {
      const sick = RoutineMode(kind: ModeKind.sick, until: '2026-10-14');
      expect(activeItems(day, sick, '2026-10-15'), day);
      expect(activeItems(day, null, '2026-10-14'), day);
    });

    test('a mode lasts its length from today, across a month end', () {
      expect(
        RoutineMode.start(ModeKind.sick, DateTime(2026, 10, 31, 9)).until,
        '2026-10-31',
      );
      expect(
        RoutineMode.start(ModeKind.travel, DateTime(2026, 10, 28)).until,
        '2026-11-03',
      );
      expect(
        RoutineMode.start(ModeKind.busy, DateTime(2026, 12, 30)).until,
        '2027-01-05',
      );
    });

    test('stored as {kind, until}; off or unknown values read as no mode', () {
      const m = RoutineMode(kind: ModeKind.busy, until: '2026-10-20');
      final back = RoutineMode.fromData(m.toData())!;
      expect(back.kind, ModeKind.busy);
      expect(back.until, '2026-10-20');
      expect(RoutineMode.fromData(modeOffData), isNull);
      expect(RoutineMode.fromData({'kind': 'holiday', 'until': 'x'}), isNull);
      expect(RoutineMode.fromData(null), isNull);
    });
  });
}
