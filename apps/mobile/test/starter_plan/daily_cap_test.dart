import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/time/clock.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/moments/data/coach_faces.dart';
import 'package:livewell/features/routine/data/routine_repository.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';
import 'package:livewell/features/routine/domain/routine_reminders.dart';
import 'package:livewell/features/starter_plan/application/plan_scheduler.dart';
import 'package:livewell/features/starter_plan/data/plan_repository.dart';
import 'package:livewell/features/starter_plan/data/reminders.dart';
import 'package:livewell/features/starter_plan/domain/daily_cap.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';

import '../consent/consent_test.dart' show FakeConsentRepository;
import '../support/fakes.dart';
import 'starter_plan_test.dart' show plan, texts;

/// T-DLY-04 / FR-TCH-01 (D-71): one cap of 4 notifications a day across the
/// plan's touchpoints and the routine's reminders.

const mine = Routine(
  routineId: myRoutineId,
  name: 'My routine',
  days: everyDay,
);

RoutineItem item(String id, String time, {Set<Weekday>? days}) => RoutineItem(
  itemId: id,
  routineId: myRoutineId,
  catalogId: 'drink_water',
  label: id,
  icon: 'water',
  time: time,
  durationMin: 2,
  reminder: true,
  days: days,
);

/// Nine or ten reminders a day (under the 12-item limit), spread out so none bundle, and a few only on some
/// days (so each day has a different routine).
final manyItems = [
  for (final h in [7, 8, 9, 10, 11, 14, 15, 17, 19])
    item('every$h', '${h.toString().padLeft(2, '0')}:20'),
  item('weekend', '09:40', days: {Weekday.sat, Weekday.sun}),
  item('monwed', '11:40', days: {Weekday.mon, Weekday.wed}),
  item('friday', '16:40', days: {Weekday.fri}),
];

/// Wednesday 2026-10-14.
final week = [for (var d = 0; d < 7; d++) DateTime(2026, 10, 14 + d)];

CappedReminders scheduleAt(
  DateTime now, {
  List<RoutineItem>? items,
  QuietHours quiet = const QuietHours(),
  TouchpointTimes times = const TouchpointTimes(),
  Set<TouchpointKind> enabled = const {...TouchpointKind.values},
  int routinePerDay = routineRemindersMax,
  Map<String, Set<String>> logged = const {},
  Map<String, int> used = const {},
}) => capPerDay(
  plan: TouchpointScheduler.build(
    days: week,
    times: times,
    quiet: quiet,
    consent: true,
    now: now,
    enabled: enabled,
  ),
  routine: buildRoutineReminders(
    routines: const [mine],
    items: items ?? manyItems,
    logged: logged,
    mode: null,
    quiet: quiet,
    now: now,
    perDay: routinePerDay,
  ),
  used: used,
);

Map<String, int> perDate(CappedReminders c) {
  final out = <String, int>{};
  for (final t in c.times) {
    out.update(localDateKey(t), (n) => n + 1, ifAbsent: () => 1);
  }
  return out;
}

void main() {
  group('capPerDay', () {
    test('plan first, then the earliest routine reminders, 4 in all', () {
      final c = scheduleAt(DateTime(2026, 10, 14, 6));
      final wed = c.times.where((t) => t.day == 14).toList()..sort();
      expect(wed, hasLength(NotificationCaps.perDay));
      // Greeting 7:00, nudge 13:00, reflection 20:30 and the 7:20 routine.
      expect(c.plan.where((p) => p.when.day == 14).map((p) => p.kind), [
        TouchpointKind.greeting,
        TouchpointKind.nudge,
        TouchpointKind.reflection,
      ]);
      expect(
        c.routine.where((r) => r.when.day == 14).single.when,
        DateTime(2026, 10, 14, 7, 20),
      );
    });

    test('Sunday: the plan already has 4 (weekly review), so no routine', () {
      final c = scheduleAt(DateTime(2026, 10, 14, 6));
      expect(c.plan.where((p) => p.when.day == 18), hasLength(4));
      expect(c.routine.where((r) => r.when.day == 18), isEmpty);
    });

    test('no day ever passes 4: many items, quiet hours, every hour of the '
        'day as "now", category toggles, different routines per day', () {
      const quiets = [
        QuietHours(),
        QuietHours(start: ClockTime(20, 0), end: ClockTime(9, 0)),
        QuietHours(start: ClockTime(12, 0), end: ClockTime(14, 0)),
        QuietHours(start: ClockTime(23, 30), end: ClockTime(5, 0)),
      ];
      final toggles = [
        {...TouchpointKind.values},
        <TouchpointKind>{},
        {TouchpointKind.nudge},
        {TouchpointKind.greeting, TouchpointKind.weekly},
      ];
      var checked = 0;
      for (final q in quiets) {
        for (final on in toggles) {
          for (var h = 0; h < 24; h += 3) {
            final now = DateTime(2026, 10, 14, h, 10);
            final c = scheduleAt(now, quiet: q, enabled: on);
            for (final n in perDate(c).values) {
              expect(n, lessThanOrEqualTo(NotificationCaps.perDay));
            }
            for (final t in c.times) {
              expect(q.contains(ClockTime(t.hour, t.minute)), isFalse);
              expect(t.isAfter(now), isTrue);
            }
            checked++;
          }
        }
      }
      expect(checked, quiets.length * toggles.length * 8);
    });

    test('with the plan switched off, routine reminders fill up to 4', () {
      final c = scheduleAt(DateTime(2026, 10, 14, 6), enabled: const {});
      expect(c.plan, isEmpty);
      for (final d in week) {
        expect(perDate(c)[localDateKey(d)], NotificationCaps.perDay);
      }
      // The earliest four, in time order.
      expect(c.routine.where((r) => r.when.day == 14).map((r) => r.when.hour), [
        7,
        8,
        9,
        10,
      ]);
    });

    test('a day short of room keeps the greeting before the nudge, the '
        'reflection and the weekly review', () {
      final c = scheduleAt(DateTime(2026, 10, 14, 6), used: {'2026-10-18': 2});
      expect(c.plan.where((p) => p.when.day == 18).map((p) => p.kind), [
        TouchpointKind.greeting,
        TouchpointKind.nudge,
      ]);
    });

    test('notifications already shown today count toward the cap', () {
      for (var used = 0; used <= 6; used++) {
        final c = scheduleAt(
          DateTime(2026, 10, 14, 6),
          used: {'2026-10-14': used},
        );
        expect(
          perDate(c)['2026-10-14'] ?? 0,
          (NotificationCaps.perDay - used).clamp(0, NotificationCaps.perDay),
        );
        // Other days are untouched.
        expect(perDate(c)['2026-10-15'], NotificationCaps.perDay);
      }
    });

    test('the routine setting still limits routine reminders on its own', () {
      final c = scheduleAt(
        DateTime(2026, 10, 14, 6),
        enabled: const {},
        routinePerDay: 2,
      );
      expect(perDate(c)['2026-10-14'], 2);
    });
  });

  group('ReminderLedger', () {
    test('counts only today and only what is due by now', () {
      final l = ReminderLedger('2026-10-14', [
        DateTime(2026, 10, 14, 7),
        DateTime(2026, 10, 14, 9),
        DateTime(2026, 10, 14, 13),
      ]);
      expect(l.shownBy(DateTime(2026, 10, 14, 9)), hasLength(2));
      expect(l.shownBy(DateTime(2026, 10, 15, 9)), isEmpty);
    });

    test('a day of reschedules never shows more than 4 in all', () {
      // Plan off, so routine reminders fill the day. Each hour something
      // changes (an item done), the day is rescheduled, and what was
      // scheduled before now has been shown.
      ReminderLedger? ledger;
      final shown = <DateTime>{};
      final logged = <String, Set<String>>{'2026-10-14': {}};
      CappedReminders? last;
      for (var h = 6; h <= 22; h++) {
        final now = DateTime(2026, 10, 14, h);
        // Everything the last pass scheduled up to now was shown.
        for (final t in last?.times ?? const <DateTime>[]) {
          if (t.day == 14 && !t.isAfter(now)) shown.add(t);
        }
        // The person marks the items just shown as done.
        for (final r in last?.routine ?? const <RoutineReminder>[]) {
          if (!r.when.isAfter(now)) logged['2026-10-14']!.addAll(r.itemIds);
        }
        last = scheduleAt(
          now,
          enabled: const {},
          logged: logged,
          used: {'2026-10-14': ledger?.shownBy(now).length ?? 0},
        );
        ledger = ReminderLedger.next(ledger, now, last);
        final upcoming = last.times.where((t) => t.day == 14);
        expect(
          shown.length + upcoming.length,
          lessThanOrEqualTo(NotificationCaps.perDay),
        );
      }
      expect(shown, hasLength(NotificationCaps.perDay));
      // Without the ledger the same day would have shown many more.
    });
  });

  group('PlanScheduler', () {
    late FakeReminders reminders;
    late FakeReminderLedgerStore ledger;
    late FakeConsentRepository consents;
    late InMemoryRoutineRepository routines;
    late DateTime now;
    late ProviderContainer c;

    setUp(() async {
      final plans = FakePlanRepository();
      await plans.save(plan(), const TouchpointTimes());
      reminders = FakeReminders();
      ledger = FakeReminderLedgerStore();
      consents = FakeConsentRepository();
      routines = InMemoryRoutineRepository();
      await routines.saveRoutine(mine);
      for (final i in manyItems) {
        await routines.saveItem(i);
      }
      now = DateTime(2026, 10, 15, 6);
      c = ProviderContainer(
        overrides: [
          planRepositoryProvider.overrideWithValue(plans),
          remindersProvider.overrideWithValue(reminders),
          reminderZoneStoreProvider.overrideWithValue(FakeReminderZoneStore()),
          reminderLedgerStoreProvider.overrideWithValue(ledger),
          consentRepositoryProvider.overrideWithValue(consents),
          avatarRepositoryProvider.overrideWithValue(FakeAvatarRepository()),
          coachFacesProvider.overrideWithValue(FakeCoachFaces()),
          routineRepositoryProvider.overrideWithValue(routines),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      await consents.record(ConsentType.notifications, granted: true);
    });
    tearDown(() => c.dispose());

    Map<String, int> scheduledPerDate() {
      final out = <String, int>{};
      for (final t in [
        for (final p in reminders.scheduled) p.when,
        for (final r in reminders.routine) r.when,
      ]) {
        out.update(localDateKey(t), (n) => n + 1, ifAbsent: () => 1);
      }
      return out;
    }

    test('plan + routine together: at most 4 on every day', () async {
      await c.read(planSchedulerProvider).reschedule(texts);
      expect(reminders.routine, isNotEmpty);
      final counts = scheduledPerDate();
      expect(counts, isNotEmpty);
      for (final n in counts.values) {
        expect(n, lessThanOrEqualTo(NotificationCaps.perDay));
      }
      // Thursday: the plan's 3 and the earliest routine reminder.
      expect(counts['2026-10-15'], 4);
      expect(
        reminders.routine.where((r) => r.date == '2026-10-15').single.when,
        DateTime(2026, 10, 15, 7, 20),
      );
      // Today's times are remembered for later reschedules.
      expect(ledger.ledger?.date, '2026-10-15');
      expect(ledger.ledger?.times, hasLength(4));
    });

    test('a reschedule late in the day does not top today up past 4', () async {
      await c.read(planSchedulerProvider).reschedule(texts);
      // 7:00 greeting and 7:20 routine shown; at 14:00 the nudge too.
      now = DateTime(2026, 10, 15, 14);
      await c.read(planSchedulerProvider).reschedule(texts);
      final today = scheduledPerDate()['2026-10-15'] ?? 0;
      expect(today, 1, reason: 'only the evening reflection is left');
      expect(ledger.ledger?.shownBy(now).length, 3);
    });
  });
}
