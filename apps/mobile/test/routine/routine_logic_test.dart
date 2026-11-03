import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/data/routine_repository.dart';
import 'package:livewell/features/routine/domain/routine.dart';

/// T-GOL-03a: routines, items and logs.

const weekdays = Routine(
  routineId: 'weekdays',
  name: 'Weekdays',
  days: {Weekday.mon, Weekday.tue, Weekday.wed, Weekday.thu, Weekday.fri},
);
const weekend = Routine(
  routineId: 'weekend',
  name: 'Weekend',
  days: {Weekday.sat, Weekday.sun},
);

RoutineItem item(
  String id, {
  String routine = 'weekdays',
  String time = '07:00',
  int order = 0,
  Set<Weekday>? days,
  String? catalogId = 'drink_water',
}) => RoutineItem(
  itemId: id,
  routineId: routine,
  catalogId: catalogId,
  label: 'Drink water',
  icon: 'water',
  time: time,
  durationMin: 2,
  days: days,
  order: order,
);

List<String> ids(List<RoutineItem> items) => [for (final i in items) i.itemId];

void main() {
  group('the day timeline', () {
    test('weekdays and weekends get their own items, in time order', () {
      final items = [
        item('walk', time: '07:45'),
        item('wake', time: '07:00'),
        item('lie_in', routine: 'weekend', time: '08:30'),
        item('bed', time: '22:30'),
      ];
      expect(ids(itemsForDay([weekdays, weekend], items, Weekday.wed)), [
        'wake',
        'walk',
        'bed',
      ]);
      expect(ids(itemsForDay([weekdays, weekend], items, Weekday.sun)), [
        'lie_in',
      ]);
    });

    test("an item's own days win over its routine's", () {
      final items = [
        item('gym', days: {Weekday.mon, Weekday.sat}),
        item('water'),
      ];
      expect(ids(itemsForDay([weekdays], items, Weekday.sat)), ['gym']);
      expect(ids(itemsForDay([weekdays], items, Weekday.tue)), ['water']);
      expect(
        ids(itemsForDay([weekdays], items, Weekday.mon)),
        unorderedEquals(['gym', 'water']),
      );
    });

    test('same time: the person order decides; times sort as times', () {
      final items = [
        item('b', time: '09:00', order: 2),
        item('a', time: '09:00', order: 1),
        item('late', time: '10:00'),
        item('early', time: '06:59'),
      ];
      expect(ids(itemsForDay([weekdays], items, Weekday.mon)), [
        'early',
        'a',
        'b',
        'late',
      ]);
    });

    test('paused routines and items of a missing routine are left out', () {
      final items = [item('a'), item('orphan', routine: 'gone')];
      expect(
        itemsForDay([weekdays.copyWith(active: false)], items, Weekday.mon),
        isEmpty,
      );
      expect(ids(itemsForDay([weekdays], items, Weekday.mon)), ['a']);
    });

    test('up to 12 items a day, across routines', () {
      final everyDayRoutine = Routine(
        routineId: 'all',
        name: 'Every day',
        days: everyDay,
      );
      final items = [
        for (var n = 0; n < 11; n++) item('w$n', time: '08:00', order: n),
        item('x', routine: 'all'),
      ];
      final routines = [weekdays, everyDayRoutine];
      expect(itemsForDay(routines, items, Weekday.mon), hasLength(12));
      expect(hasRoomOn(routines, items, Weekday.mon), isFalse);
      // The weekend only has the every-day item.
      expect(hasRoomOn(routines, items, Weekday.sat), isTrue);
      expect(maxItemsPerDay, 12);
    });

    test('the weekday follows the local date', () {
      expect(Weekday.of(DateTime(2026, 10, 24)), Weekday.sat);
      expect(Weekday.of(DateTime(2026, 10, 26, 0, 1)), Weekday.mon);
      expect(Weekday.of(DateTime(2026, 10, 25, 23, 59)), Weekday.sun);
    });
  });

  group('validation (the same limits as the security rules)', () {
    test('a good item and routine pass', () {
      expect(item('i1').isValid, isTrue);
      expect(item('c1', catalogId: null).isValid, isTrue);
      expect(weekdays.isValid, isTrue);
    });

    test('bad labels, times, durations, icons, days and ids are caught', () {
      final ok = item('i1');
      expect(ok.copyWith(label: '  ').isValid, isFalse);
      expect(ok.copyWith(label: 'x' * 41).isValid, isFalse);
      expect(ok.copyWith(label: 'x' * 40).isValid, isTrue);
      expect(ok.copyWith(time: '7:00').isValid, isFalse);
      expect(ok.copyWith(time: '24:00').isValid, isFalse);
      expect(ok.copyWith(durationMin: 0).isValid, isFalse);
      expect(ok.copyWith(durationMin: 181).isValid, isFalse);
      expect(ok.copyWith(icon: 'pill').isValid, isFalse);
      expect(ok.copyWith(days: {}).isValid, isFalse);
      expect(ok.copyWith(routineId: 'has_underscore').isValid, isFalse);
      expect(item('has_underscore').isValid, isFalse);
      expect(weekdays.copyWith(name: '').isValid, isFalse);
      expect(weekdays.copyWith(name: 'x' * 41).isValid, isFalse);
      expect(weekdays.copyWith(days: {}).isValid, isFalse);
    });

    test('times', () {
      expect(isValidTime('00:00'), isTrue);
      expect(isValidTime('23:59'), isTrue);
      expect(isValidTime('9:30'), isFalse);
      expect(minutesOf('13:05'), 13 * 60 + 5);
    });
  });

  group('documents', () {
    test('a log id is date_itemId, so the same item twice is one log', () {
      const a = RoutineLog(
        date: '2026-10-24',
        itemId: 'i1',
        status: RoutineStatus.done,
        source: RoutineSource.widget,
      );
      expect(a.id, '2026-10-24_i1');
      expect(logId('2026-10-24', 'i1'), a.id);
    });

    test('catalog items store catalog_id, custom ones custom: true', () {
      final catalog = FirestoreRoutineRepository.itemData(item('i1'));
      expect(catalog['catalog_id'], 'drink_water');
      expect(catalog.containsKey('custom'), isFalse);
      final custom = FirestoreRoutineRepository.itemData(
        item('c1', catalogId: null),
      );
      expect(custom['custom'], true);
      expect(custom.containsKey('catalog_id'), isFalse);
      // No days key unless the item has its own days.
      expect(catalog.containsKey('days'), isFalse);
    });

    test('routines and items survive a round trip', () {
      final r = FirestoreRoutineRepository.routineFrom(
        'weekend',
        FirestoreRoutineRepository.routineData(weekend),
      )!;
      expect(r.name, 'Weekend');
      expect(r.days, {Weekday.sat, Weekday.sun});
      expect(r.active, isTrue);
      expect(FirestoreRoutineRepository.routineData(weekend)['days'], [
        'sat',
        'sun',
      ]);

      final original = item(
        'i1',
        days: {Weekday.sun, Weekday.mon},
        order: 3,
      ).copyWith(reminder: false);
      final back = FirestoreRoutineRepository.itemFrom(
        'i1',
        FirestoreRoutineRepository.itemData(original),
      )!;
      expect(back.routineId, 'weekdays');
      expect(back.catalogId, 'drink_water');
      expect(back.days, {Weekday.mon, Weekday.sun});
      expect(back.order, 3);
      expect(back.reminder, isFalse);
      expect(back.avatarAnnounce, isTrue);
      expect(back.time, '07:00');
    });

    test('a document this version cannot read is skipped, not a crash', () {
      expect(FirestoreRoutineRepository.itemFrom('i1', {'label': 3}), isNull);
      expect(FirestoreRoutineRepository.routineFrom('r', {}), isNull);
      expect(
        FirestoreRoutineRepository.logFrom({
          'date': '2026-10-24',
          'item_id': 'i1',
          'status': 'missed',
          'source': 'app',
        }),
        isNull,
      );
    });
  });

  group('the dev preview store', () {
    test('saves, lists, deletes and logs idempotently', () async {
      final repo = InMemoryRoutineRepository();
      await repo.saveRoutine(weekdays);
      await repo.saveItem(item('i1'));
      await repo.saveItem(item('i2'));
      expect(await repo.watchItems().first, hasLength(2));
      await repo.deleteItem('i2');
      expect(ids(await repo.watchItems().first), ['i1']);

      for (final s in [RoutineSource.app, RoutineSource.widget]) {
        await repo.saveLog(
          RoutineLog(
            date: '2026-10-24',
            itemId: 'i1',
            status: RoutineStatus.done,
            source: s,
          ),
        );
      }
      final logs = await repo.watchLogs('2026-10-24').first;
      expect(logs, hasLength(1));
      expect(logs.single.source, RoutineSource.widget);
      expect(await repo.watchLogs('2026-10-25').first, isEmpty);
      expect(isValidItemId(repo.newId()), isTrue);
    });

    test('refuses invalid items, as the rules would', () {
      final repo = InMemoryRoutineRepository();
      expect(
        () => repo.saveItem(item('i1').copyWith(time: '7')),
        throwsArgumentError,
      );
    });
  });
}
