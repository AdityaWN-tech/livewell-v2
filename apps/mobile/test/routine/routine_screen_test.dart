import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';
import 'package:livewell/features/routine/presentation/routine_screen.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';
import 'package:livewell/features/routine/presentation/routine_sheets.dart';

import '../home/home_screen_test.dart' show signedIn, uid;
import '../plan/plan_screen_test.dart' show openPlan, scrollTo;
import '../support/app_harness.dart';

/// T-GOL-03b: the My Daily Routine screen. "Today" is Wednesday
/// 2026-10-14 in the harness.

Future<void> openRoutine(WidgetTester tester) async {
  await openPlan(tester);
  await scrollTo(tester, find.byKey(const Key('plan-routine')));
  await tester.tap(find.byKey(const Key('plan-routine')));
  await tester.pumpAndSettle();
  expect(find.byType(RoutineScreen), findsOneWidget);
}

Future<Harness> boot(
  WidgetTester tester, {
  bool? limited,
  List<RoutineItem> items = const [],
}) async {
  final h = signedIn(name: 'Priya Rao');
  if (limited != null) {
    h.profiles.focus[uid] = (
      choices: const ['move_more'],
      driver: 'Driver 2',
      limited: limited,
    );
  }
  if (items.isNotEmpty) {
    await h.routines.saveRoutine(
      const Routine(routineId: myRoutineId, name: 'My routine', days: everyDay),
    );
    for (final i in items) {
      await h.routines.saveItem(i);
    }
  }
  await h.boot(tester);
  return h;
}

RoutineItem water({
  String id = 'water',
  String time = '07:15',
  Set<Weekday>? days,
}) => RoutineItem(
  itemId: id,
  routineId: myRoutineId,
  catalogId: 'drink_water',
  label: 'Drink water',
  icon: 'water',
  time: time,
  durationMin: 2,
  days: days,
);

Finder inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, String itemId, String option) async {
  await tapKey(tester, 'routine-item-$itemId-menu');
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<List<RoutineItem>> saved(Harness h) => h.routines.watchItems().first;

void main() {
  group('reaching it', () {
    testWidgets('Plan shows the routine card; it opens on today', (
      tester,
    ) async {
      await boot(tester);
      await openRoutine(tester);
      expect(find.text('My Daily Routine'), findsWidgets);
      final today = tester.widget<ChoiceChip>(
        find.byKey(const Key('routine-tab-wed')),
      );
      expect(today.selected, isTrue);
      expect(find.text('Today'), findsOneWidget);
      // Empty: the kind invitation and the templates.
      expect(
        find.text('Build your day, one small step at a time'),
        findsOneWidget,
      );
      expect(find.text('Workday'), findsOneWidget);
      expect(find.byKey(const Key('routine-add')), findsOneWidget);
    });
  });

  group('templates', () {
    testWidgets('Workday fills Monday to Friday, not the weekend', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await tapKey(tester, 'routine-empty-template-workday');
      expect(find.textContaining('Workday added.'), findsOneWidget);
      expect(find.byKey(const Key('routine-timeline')), findsOneWidget);
      expect(find.text('Work break'), findsOneWidget);
      expect(await saved(h), hasLength(8));

      await tapKey(tester, 'routine-tab-sat');
      expect(find.byKey(const Key('routine-empty')), findsOneWidget);
    });

    testWidgets('limited activity: templates leave movement out', (
      tester,
    ) async {
      final h = await boot(tester, limited: true);
      await openRoutine(tester);
      await tapKey(tester, 'routine-empty-template-workday');
      final items = await saved(h);
      expect(items.map((i) => i.catalogId), isNot(contains('walk_after_meal')));
      expect(items, hasLength(7));
    });
  });

  group('adding', () {
    testWidgets('from the catalog: pick, adjust, save, then mark done', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await tapKey(tester, 'routine-add');
      expect(find.byKey(const Key('routine-add-sheet')), findsOneWidget);
      await tapKey(tester, 'routine-add-drink_water');
      expect(find.byKey(const Key('routine-item-sheet')), findsOneWidget);
      // A catalog label can't be changed; only custom items have a field.
      expect(find.byKey(const Key('routine-item-label')), findsNothing);
      await tapKey(tester, 'routine-length-5');
      await tapKey(tester, 'routine-item-save');

      final items = await saved(h);
      expect(items.single.catalogId, 'drink_water');
      expect(items.single.durationMin, 5);
      expect(items.single.days, {Weekday.wed});
      expect(find.text('Drink water'), findsOneWidget);

      await tapKey(tester, 'routine-item-${items.single.itemId}-done');
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      final logs = await h.routines.watchLogs('2026-10-14').first;
      expect(logs.single.status, RoutineStatus.done);
      expect(logs.single.source, RoutineSource.app);

      // Plan's card counts it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 done today'), findsOneWidget);
    });

    testWidgets('custom: needs words, saves the label and icon', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await tapKey(tester, 'routine-add');
      await tapKey(tester, 'routine-add-custom');
      await tapKey(tester, 'routine-item-save');
      expect(find.text('Add a few words.'), findsOneWidget);
      expect(await saved(h), isEmpty);

      await tester.enterText(
        find.byKey(const Key('routine-item-label')),
        'Call a friend',
      );
      await tapKey(tester, 'routine-icon-heart');
      // The coach never reads custom words aloud, and says so.
      expect(find.textContaining('show as text only'), findsOneWidget);
      await tapKey(tester, 'routine-item-save');
      final item = (await saved(h)).single;
      expect(item.custom, isTrue);
      expect(item.label, 'Call a friend');
      expect(item.icon, 'heart');
    });

    testWidgets('a red-flag label shows the safety card and is not saved', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await tapKey(tester, 'routine-add');
      await tapKey(tester, 'routine-add-custom');
      await tester.enterText(
        find.byKey(const Key('routine-item-label')),
        'I want to die',
      );
      await tapKey(tester, 'routine-item-save');
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      expect(await saved(h), isEmpty);
    });

    testWidgets('medication steps are not kept (not in v2)', (tester) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await tapKey(tester, 'routine-add');
      await tapKey(tester, 'routine-add-custom');
      await tester.enterText(
        find.byKey(const Key('routine-item-label')),
        'Stop my blood pressure pills',
      );
      await tapKey(tester, 'routine-item-save');
      expect(await saved(h), isEmpty);
    });

    Future<void> customLabel(WidgetTester tester, String label) async {
      await tapKey(tester, 'routine-add');
      await tapKey(tester, 'routine-add-custom');
      await tester.enterText(
        find.byKey(const Key('routine-item-label')),
        label,
      );
      await tapKey(tester, 'routine-item-save');
    }

    testWidgets('an eating-disorder label shows its card, not saved', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await customLabel(tester, 'Skip dinner');
      expect(find.byType(SafetyNoticeSheet), findsOneWidget);
      expect(await saved(h), isEmpty);
    });

    testWidgets('weight goals: a kind message, reword, then it saves', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await customLabel(tester, 'Weigh myself');
      // The sheet stays open with a kind message.
      expect(find.byType(ItemSheet), findsOneWidget);
      expect(
        find.textContaining('not weight, calories or diets'),
        findsOneWidget,
      );
      expect(await saved(h), isEmpty);
      await tester.enterText(
        find.byKey(const Key('routine-item-label')),
        'Walk the dog',
      );
      await tapKey(tester, 'routine-item-save');
      expect((await saved(h)).single.label, 'Walk the dog');
    });

    testWidgets('supplements and unkind words get their own message', (
      tester,
    ) async {
      final h = await boot(tester);
      await openRoutine(tester);
      await customLabel(tester, 'Fish oil');
      expect(
        find.textContaining("can't go in your routine yet"),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('routine-item-label')),
        'No excuses',
      );
      await tapKey(tester, 'routine-item-save');
      expect(find.textContaining("Let's word it kindly"), findsOneWidget);
      expect(await saved(h), isEmpty);
    });

    testWidgets('limited activity: walks say to check first, reminders off', (
      tester,
    ) async {
      final h = await boot(tester, limited: true);
      await openRoutine(tester);
      await tapKey(tester, 'routine-add');
      expect(
        find.descendant(
          of: find.byKey(const Key('routine-add-morning_walk')),
          matching: find.text('Check with your clinician first'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'routine-add-morning_walk');
      expect(find.byKey(const Key('routine-clinician-note')), findsOneWidget);
      await tapKey(tester, 'routine-item-save');
      final item = (await saved(h)).single;
      expect(item.reminder, isFalse);
      expect(item.avatarAnnounce, isFalse);
    });
  });

  group('changing a day', () {
    testWidgets('delete, then undo', (tester) async {
      final h = await boot(tester, items: [water()]);
      await openRoutine(tester);
      await openMenu(tester, 'water', 'Delete');
      expect(await saved(h), isEmpty);
      expect(find.text('Drink water deleted'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await saved(h)).single.itemId, 'water');
    });

    testWidgets('remove from one day keeps it on the others', (tester) async {
      final h = await boot(
        tester,
        items: [
          water(days: {Weekday.wed, Weekday.thu}),
        ],
      );
      await openRoutine(tester);
      await openMenu(tester, 'water', 'Remove from Wednesday');
      expect((await saved(h)).single.days, {Weekday.thu});
      expect(find.byKey(const Key('routine-empty')), findsOneWidget);
    });

    testWidgets('skip today', (tester) async {
      final h = await boot(tester, items: [water()]);
      await openRoutine(tester);
      await openMenu(tester, 'water', 'Skip today');
      final logs = await h.routines.watchLogs('2026-10-14').first;
      expect(logs.single.status, RoutineStatus.skipped);
      expect(find.textContaining('Skipped today'), findsOneWidget);
    });

    testWidgets('edit which days it repeats', (tester) async {
      // Every day to start with (the routine's days).
      final h = await boot(tester, items: [water()]);
      await openRoutine(tester);
      await openMenu(tester, 'water', 'Edit');
      expect(find.byKey(const Key('routine-item-label')), findsNothing);
      await tapKey(tester, 'routine-day-sat');
      await tapKey(tester, 'routine-day-sun');
      await tapKey(tester, 'routine-item-save');
      expect((await saved(h)).single.days, {
        Weekday.mon,
        Weekday.tue,
        Weekday.wed,
        Weekday.thu,
        Weekday.fri,
      });
    });

    testWidgets('copy this day to Saturday', (tester) async {
      final h = await boot(
        tester,
        items: [
          water(days: {Weekday.wed}),
        ],
      );
      await openRoutine(tester);
      await tapKey(tester, 'routine-more');
      await tester.tap(find.byKey(const Key('routine-menu-copy')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'routine-copy-sat');
      await tapKey(tester, 'routine-copy-confirm');
      expect(find.text('Copied.'), findsOneWidget);
      expect((await saved(h)).single.days, {Weekday.wed, Weekday.sat});
      await tapKey(tester, 'routine-tab-sat');
      expect(find.text('Drink water'), findsOneWidget);
    });

    testWidgets('two things at one time get a gentle hint', (tester) async {
      await boot(
        tester,
        items: [
          water(),
          water(id: 'stretch', time: '07:15'),
        ],
      );
      await openRoutine(tester);
      expect(find.textContaining('Two things at'), findsOneWidget);
    });

    testWidgets('a full day (12) turns Add off', (tester) async {
      await boot(
        tester,
        items: [
          for (var n = 0; n < 12; n++)
            water(id: 'w$n', time: '0${n % 10}:30'.substring(0, 5)),
        ],
      );
      await openRoutine(tester);
      expect(find.byKey(const Key('routine-full')), findsOneWidget);
      final add = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('routine-add')),
      );
      expect(add.onPressed, isNull);
    });
  });

  group('life-event modes (FR-DLY-09)', () {
    testWidgets('sick day rests the routine; End brings it back', (
      tester,
    ) async {
      final h = await boot(tester, items: [water()]);
      await openRoutine(tester);
      await tapKey(tester, 'routine-more');
      await tester.tap(find.byKey(const Key('routine-menu-modes')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'routine-mode-sick');

      expect(find.byKey(const Key('routine-mode-banner')), findsOneWidget);
      expect(find.textContaining('Resting today'), findsOneWidget);
      expect(find.byKey(const Key('routine-item-water-done')), findsNothing);
      expect(h.profiles.settings[uid]?['routine_mode'], {
        'kind': 'sick',
        'until': '2026-10-14',
      });

      await tapKey(tester, 'routine-mode-end');
      expect(find.byKey(const Key('routine-mode-banner')), findsNothing);
      expect(find.byKey(const Key('routine-item-water-done')), findsOneWidget);
      expect(h.profiles.settings[uid]?['routine_mode'], {'kind': 'none'});
    });

    testWidgets('travel keeps the first 3 steps', (tester) async {
      await boot(
        tester,
        items: [
          for (var n = 0; n < 4; n++) water(id: 'w$n', time: '0${n + 6}:00'),
        ],
      );
      await openRoutine(tester);
      await tapKey(tester, 'routine-more');
      await tester.tap(find.byKey(const Key('routine-menu-modes')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'routine-mode-travel');
      expect(find.textContaining('Travel mode until'), findsOneWidget);
      expect(find.textContaining('Resting today'), findsOneWidget);
      expect(find.byKey(const Key('routine-item-w3-done')), findsNothing);
      expect(find.byKey(const Key('routine-item-w0-done')), findsOneWidget);
    });
  });

  group('layout', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('small phone at text size $scale', (tester) async {
        final h = signedIn(name: 'Priya Rao');
        await h.routines.saveRoutine(
          const Routine(
            routineId: myRoutineId,
            name: 'My routine',
            days: everyDay,
          ),
        );
        await h.routines.saveItem(water());
        await h.boot(tester);
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await openRoutine(tester);
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'routine-add');
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'routine-add-drink_water');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
