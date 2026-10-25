import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';
import 'package:livewell/features/routine/domain/routine_reminders.dart';
import 'package:livewell/features/routine/presentation/routine_screen.dart';

import '../home/home_screen_test.dart' show signedIn, uid;
import '../support/app_harness.dart';
import 'routine_screen_test.dart' show openRoutine, tapKey;

/// T-GOL-03d: routine reminders, the coach's moment, and asking once about
/// an ignored item. "Now" is Wednesday 2026-10-14, 8:30.

const water = RoutineItem(
  itemId: 'water',
  routineId: myRoutineId,
  catalogId: 'drink_water',
  label: 'Drink water',
  icon: 'water',
  time: '09:00',
  durationMin: 2,
);

const call = RoutineItem(
  itemId: 'call',
  routineId: myRoutineId,
  label: 'Call mom about the test results',
  icon: 'heart',
  time: '09:10',
  durationMin: 10,
);

final payload = routinePayload('2026-10-14', ['water', 'call']);

Future<Harness> setUp(
  WidgetTester tester, {
  Flavor flavor = Flavor.dev,
  List<RoutineItem> items = const [water, call],
  bool consent = true,
  String? launch,
}) async {
  final h = signedIn(name: 'Priya Rao', flavor: flavor);
  await h.routines.saveRoutine(
    const Routine(routineId: myRoutineId, name: 'My routine', days: everyDay),
  );
  for (final i in items) {
    await h.routines.saveItem(i);
  }
  if (consent) {
    await h.consents.record(ConsentType.notifications, granted: true);
  }
  h.reminders.launch = launch;
  await h.boot(tester);
  return h;
}

Future<void> tapReminder(WidgetTester tester, Harness h, String p) async {
  h.reminders.tapPayload(p);
  await tester.pumpAndSettle();
}

void main() {
  group('the coach announces routine items', () {
    testWidgets('approved lines spoken; custom words shown, never spoken', (
      tester,
    ) async {
      final h = await setUp(tester);
      await tapReminder(tester, h, payload);
      expect(find.byType(MomentScreen), findsOneWidget);
      final said = h.speaker.spoken.single.$1;
      expect(said.text, contains('Priya'));
      expect(said.text, contains('glass of water'));
      expect(said.text, contains('next routine step'));
      // The closed-script rule: the custom label is never in what is said.
      expect(said.text, isNot(contains('Call mom')));
      expect(said.text, isNot(contains('test results')));
      expect(said.messageId, startsWith('routine.drink_water.'));
      expect(said.messageId, contains('+custom.'));
      expect(said.containsUserText, isTrue);
      // Both items show by name, as text.
      final list = find.byKey(const Key('moment-routine-items'));
      expect(
        find.descendant(of: list, matching: find.text('Drink water')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: list,
          matching: find.text('Call mom about the test results'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Done marks both from the notification and cancels them', (
      tester,
    ) async {
      final h = await setUp(tester);
      await tapReminder(tester, h, payload);
      await tester.tap(find.byKey(const Key('moment-action-done')));
      await tester.pumpAndSettle();
      final logs = await h.routines.watchLogs('2026-10-14').first;
      expect(logs.map((l) => l.itemId), unorderedEquals(['water', 'call']));
      expect(logs.every((l) => l.status == RoutineStatus.done), isTrue);
      expect(logs.every((l) => l.source == RoutineSource.notification), isTrue);
      // Rescheduled: nothing left for them today.
      expect(h.reminders.routine.where((r) => r.date == '2026-10-14'), isEmpty);
      expect(
        h.reminders.routine.where((r) => r.date == '2026-10-15'),
        isNotEmpty,
      );
    });

    testWidgets('Not today skips them', (tester) async {
      final h = await setUp(tester);
      await tapReminder(tester, h, payload);
      await tester.tap(find.byKey(const Key('moment-action-notToday')));
      await tester.pumpAndSettle();
      final logs = await h.routines.watchLogs('2026-10-14').first;
      expect(logs.every((l) => l.status == RoutineStatus.skipped), isTrue);
    });

    testWidgets('a reminder that started the app opens its moment', (
      tester,
    ) async {
      await setUp(tester, launch: payload);
      expect(find.byType(MomentScreen), findsOneWidget);
      expect(find.byKey(const Key('moment-routine-items')), findsOneWidget);
    });

    testWidgets('outside dev, unapproved lines: the routine opens instead', (
      tester,
    ) async {
      final h = await setUp(tester, flavor: Flavor.prod);
      await tapReminder(tester, h, payload);
      expect(find.byType(MomentScreen), findsNothing);
      expect(find.byType(RoutineScreen), findsOneWidget);
      expect(h.speaker.spoken, isEmpty);
    });
  });

  group('scheduling', () {
    testWidgets('with the plan, bundled, generic on the lock screen', (
      tester,
    ) async {
      final h = await setUp(tester);
      await openRoutine(tester);
      // Opening the app scheduled the week.
      final r = h.reminders.routine.where((x) => x.date == '2026-10-14');
      expect(r.map((x) => x.itemIds), [
        ['water', 'call'],
      ]);
      expect(h.reminders.texts!.routineTitle, 'Your routine');
      expect(h.reminders.texts!.routineBundleBody, isNot(contains('water')));
    });

    testWidgets('marking an item done cancels its pending reminder', (
      tester,
    ) async {
      final h = await setUp(tester, items: [water]);
      await openRoutine(tester);
      expect(
        h.reminders.routine.where((x) => x.date == '2026-10-14'),
        isNotEmpty,
      );
      await tapKey(tester, 'routine-item-water-done');
      expect(h.reminders.routine.where((x) => x.date == '2026-10-14'), isEmpty);
    });

    testWidgets('"Routine reminders per day" off: none scheduled', (
      tester,
    ) async {
      final h = await setUp(tester, items: [water]);
      await h.profiles.updateSettings(uid, {'routine_reminders_per_day': 0});
      await openRoutine(tester);
      await tapKey(tester, 'routine-item-water-done');
      expect(h.reminders.routine, isEmpty);
    });

    testWidgets('no notification consent: nothing scheduled', (tester) async {
      final h = await setUp(tester, items: [water], consent: false);
      await openRoutine(tester);
      await tapKey(tester, 'routine-item-water-done');
      expect(h.reminders.routine, isEmpty);
    });
  });

  group('asking once about an ignored item', () {
    final old = water.copyWith().copyWithAdded(DateTime(2026, 10, 1));

    testWidgets('Pause reminder turns it off and is not asked again', (
      tester,
    ) async {
      final h = await setUp(tester, items: [old]);
      await openRoutine(tester);
      expect(find.byKey(const Key('routine-ignored')), findsOneWidget);
      expect(find.textContaining('Drink water'), findsWidgets);
      await tapKey(tester, 'routine-ignored-pause');
      expect((await h.routines.watchItems().first).single.reminder, isFalse);
      expect(h.routineAsked.ids, {'water'});
      expect(find.byKey(const Key('routine-ignored')), findsNothing);
    });

    testWidgets('Keep it just closes the question', (tester) async {
      final h = await setUp(tester, items: [old]);
      await openRoutine(tester);
      await tapKey(tester, 'routine-ignored-keep');
      expect(find.byKey(const Key('routine-ignored')), findsNothing);
      expect((await h.routines.watchItems().first).single.reminder, isTrue);
    });

    testWidgets('marked recently: not asked', (tester) async {
      final h = signedIn(name: 'Priya Rao');
      await h.routines.saveRoutine(
        const Routine(
          routineId: myRoutineId,
          name: 'My routine',
          days: everyDay,
        ),
      );
      await h.routines.saveItem(old);
      await h.routines.saveLog(
        const RoutineLog(
          date: '2026-10-12',
          itemId: 'water',
          status: RoutineStatus.done,
          source: RoutineSource.app,
        ),
      );
      await h.boot(tester);
      await openRoutine(tester);
      expect(find.byKey(const Key('routine-ignored')), findsNothing);
    });
  });
}

extension on RoutineItem {
  /// The item as if first saved on [at].
  RoutineItem copyWithAdded(DateTime at) => RoutineItem(
    itemId: itemId,
    routineId: routineId,
    catalogId: catalogId,
    label: label,
    icon: icon,
    time: time,
    durationMin: durationMin,
    days: days,
    reminder: reminder,
    avatarAnnounce: avatarAnnounce,
    order: order,
    addedAt: at,
  );
}
