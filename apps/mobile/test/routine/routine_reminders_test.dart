import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';
import 'package:livewell/features/routine/domain/routine_reminders.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';

/// T-GOL-03d: which routine items notify, bundles, caps and quiet hours.

const mine = Routine(
  routineId: myRoutineId,
  name: 'My routine',
  days: everyDay,
);

RoutineItem item(
  String id,
  String time, {
  bool reminder = true,
  Set<Weekday>? days,
  int order = 0,
}) => RoutineItem(
  itemId: id,
  routineId: myRoutineId,
  catalogId: 'drink_water',
  label: id,
  icon: 'water',
  time: time,
  durationMin: 2,
  reminder: reminder,
  days: days,
  order: order,
);

/// Wednesday 2026-10-14 at 6:00.
final now = DateTime(2026, 10, 14, 6);
const quiet = QuietHours(); // 22:00 to 07:00

List<RoutineReminder> build(
  List<RoutineItem> items, {
  Map<String, Set<String>> logged = const {},
  RoutineMode? mode,
  int perDay = routineRemindersDefault,
  DateTime? at,
}) => buildRoutineReminders(
  routines: const [mine],
  items: items,
  logged: logged,
  mode: mode,
  quiet: quiet,
  now: at ?? now,
  perDay: perDay,
);

List<List<String>> today(List<RoutineReminder> r) => [
  for (final x in r)
    if (x.date == '2026-10-14') x.itemIds,
];

void main() {
  group('which items notify', () {
    test('items with a reminder, from now, a week ahead', () {
      final r = build([item('water', '08:00'), item('read', '20:30')]);
      expect(today(r), [
        ['water'],
        ['read'],
      ]);
      expect(r.map((x) => x.date).toSet(), hasLength(routineDaysAhead));
      expect(r.first.when, DateTime(2026, 10, 14, 8));
    });

    test('reminder off, already passed, or in quiet hours: none', () {
      final r = build([
        item('off', '08:00', reminder: false),
        item('early', '06:30'), // quiet hours until 7:00
        item('late', '22:30'), // quiet hours from 22:00
        item('ok', '07:00'),
      ], at: DateTime(2026, 10, 14, 6));
      expect(today(r), [
        ['ok'],
      ]);
      final later = build([item('ok', '07:00')], at: DateTime(2026, 10, 14, 9));
      expect(today(later), isEmpty);
    });

    test('done or skipped today: its reminder is cancelled', () {
      final r = build(
        [item('water', '08:00'), item('read', '20:30')],
        logged: {
          '2026-10-14': {'water'},
        },
      );
      expect(today(r), [
        ['read'],
      ]);
      // Tomorrow it reminds again.
      expect(r.where((x) => x.date == '2026-10-15').map((x) => x.itemIds), [
        ['water'],
        ['read'],
      ]);
    });

    test('only on the days the item falls on', () {
      final r = build([
        item('sat', '09:00', days: {Weekday.sat}),
      ]);
      expect(r.map((x) => x.date), ['2026-10-17']);
    });
  });

  group('bundles', () {
    test('items within 15 minutes of the first share one notification', () {
      final r = build([
        item('water', '08:00'),
        item('stretch', '08:10', order: 1),
        item('walk', '08:15', order: 2),
        item('breakfast', '08:20'),
      ]);
      expect(today(r), [
        ['water', 'stretch', 'walk'],
        ['breakfast'],
      ]);
    });
  });

  group('caps (needs-product: 6 a day, at most 10)', () {
    test('the earliest notifications are kept', () {
      final items = [
        for (var h = 8; h < 20; h++)
          item('h$h', '${h.toString().padLeft(2, '0')}:00'),
      ];
      final r = build(items);
      expect(today(r), hasLength(routineRemindersDefault));
      expect(today(r).first, ['h8']);
      expect(today(build(items, perDay: 10)), hasLength(10));
    });

    test('0 turns routine reminders off', () {
      expect(build([item('water', '08:00')], perDay: 0), isEmpty);
    });

    test('the stored setting is read within 0..10, default 6', () {
      expect(routineRemindersPerDay(null), 6);
      expect(routineRemindersPerDay(3), 3);
      expect(routineRemindersPerDay(0), 0);
      expect(routineRemindersPerDay(25), 10);
      expect(routineRemindersPerDay(-1), 0);
      expect(routineRemindersPerDay('8'), 6);
    });
  });

  group('life-event modes', () {
    final items = [
      for (var h = 8; h < 13; h++)
        item('h$h', '${h.toString().padLeft(2, '0')}:00'),
    ];

    test('a sick day sends none; travel only the first 3 steps', () {
      const sick = RoutineMode(kind: ModeKind.sick, until: '2026-10-14');
      expect(today(build(items, mode: sick)), isEmpty);
      // The next day is back to normal.
      expect(
        build(items, mode: sick).where((x) => x.date == '2026-10-15'),
        hasLength(5),
      );
      const travel = RoutineMode(kind: ModeKind.travel, until: '2026-10-20');
      expect(today(build(items, mode: travel)), [
        ['h8'],
        ['h9'],
        ['h10'],
      ]);
    });
  });

  group('ids and payloads', () {
    test('stable, unique, and apart from the plan reminders', () {
      final r = build([
        for (var h = 8; h < 14; h++)
          item('h$h', '${h.toString().padLeft(2, '0')}:00'),
      ]);
      expect(r.map((x) => x.id).toSet(), hasLength(r.length));
      final planMax = TouchpointScheduler.idFor(
        DateTime(2099, 12, 31),
        TouchpointKind.weekly,
      );
      expect(r.every((x) => x.id > planMax), isTrue);
      expect(r.every((x) => x.id < 2147483647), isTrue);
      expect(build([item('h8', '08:00')]).first.id, r.first.id);
    });

    test('the payload carries the date and items', () {
      final p = routinePayload('2026-10-14', ['a1', 'b2']);
      expect(p, 'routine:2026-10-14:a1,b2');
      final back = parseRoutinePayload(p)!;
      expect(back.date, '2026-10-14');
      expect(back.itemIds, ['a1', 'b2']);
      expect(parseRoutinePayload('greeting'), isNull);
      expect(parseRoutinePayload('routine:today:a1'), isNull);
      expect(parseRoutinePayload('routine:2026-10-14:'), isNull);
    });
  });

  group('ignored reminders', () {
    final water = item('water', '08:00');

    test('counts the days in a row up to yesterday with nothing marked', () {
      expect(ignoredDays(water, const [mine], const {}, now), 5);
      final logged = {
        '2026-10-11': {'water'},
      };
      // Marked on the 11th: only the 12th and 13th since.
      expect(ignoredDays(water, const [mine], logged, now), 2);
    });

    test('passes over days it does not fall on', () {
      final weekdaysOnly = item(
        'w',
        '08:00',
        days: {Weekday.mon, Weekday.tue, Weekday.wed, Weekday.thu, Weekday.fri},
      );
      // Tue 13, Mon 12, (weekend skipped), Fri 9, Thu 8, Wed 7.
      expect(ignoredDays(weekdaysOnly, const [mine], const {}, now), 5);
      final logged = {
        '2026-10-08': {'w'},
      };
      expect(ignoredDays(weekdaysOnly, const [mine], logged, now), 3);
    });

    test('days before it was added and items without reminders: none', () {
      expect(
        ignoredDays(
          water,
          const [mine],
          const {},
          now,
          addedOn: DateTime(2026, 10, 12, 18),
        ),
        2,
      );
      expect(
        ignoredDays(
          item('x', '08:00', reminder: false),
          const [mine],
          const {},
          now,
        ),
        0,
      );
    });
  });
}
