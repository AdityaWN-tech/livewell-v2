import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';
import 'package:livewell/features/routine/presentation/routine_screen.dart';
import 'package:livewell/features/widget/data/widget_inbox.dart';
import 'package:livewell/features/widget/domain/widget_snapshot.dart'
    hide RoutineStatus;

import '../home/home_screen_test.dart' show signedIn;
import '../plan/plan_screen_test.dart' show scrollTo;
import '../support/app_harness.dart';
import '../track/track_screen_test.dart' show openTrack;

/// T-GOL-03e: My Daily Routine on Home, the widget and Track. "Now" is
/// Wednesday 2026-10-14, 8:30, and the person has no plan today, so the
/// widget has room for the routine.

RoutineItem item(String id, String label, String time, {String? catalogId}) =>
    RoutineItem(
      itemId: id,
      routineId: myRoutineId,
      catalogId: catalogId,
      label: label,
      icon: 'water',
      time: time,
      durationMin: 2,
    );

final water = item('water', 'Drink water', '09:00', catalogId: 'drink_water');
final call = item('call', 'Call mom about the test results', '18:30');

Future<Harness> boot(
  WidgetTester tester, {
  required List<RoutineItem> items,
  List<RoutineLog> logs = const [],
}) async {
  final h = signedIn(name: 'Priya Rao');
  await h.routines.saveRoutine(
    const Routine(routineId: myRoutineId, name: 'My routine', days: everyDay),
  );
  for (final i in items) {
    await h.routines.saveItem(i);
  }
  for (final l in logs) {
    await h.routines.saveLog(l);
  }
  await h.boot(tester);
  return h;
}

Future<void> settleWidget(WidgetTester tester) async {
  // The widget sync waits a moment to group changes.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('"Next in your routine" shows the next item; Done marks it', (
      tester,
    ) async {
      final h = await boot(tester, items: [water, call]);
      await scrollTo(tester, find.byKey(const Key('home-routine-next')));
      expect(find.text('NEXT IN YOUR ROUTINE'), findsOneWidget);
      expect(find.text('Drink water'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-routine-done')));
      await tester.pumpAndSettle();
      final logs = await h.routines.watchLogs('2026-10-14').first;
      expect(logs.single.itemId, 'water');
      expect(logs.single.source, RoutineSource.app);
      // On to the next one.
      expect(find.text('Call mom about the test results'), findsOneWidget);
    });

    testWidgets('tapping the row opens the routine', (tester) async {
      await boot(tester, items: [water]);
      await scrollTo(tester, find.byKey(const Key('home-routine-next')));
      await tester.tap(find.text('Drink water'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineScreen), findsOneWidget);
    });

    testWidgets('nothing left today: no row', (tester) async {
      await boot(
        tester,
        items: [water],
        logs: [
          const RoutineLog(
            date: '2026-10-14',
            itemId: 'water',
            status: RoutineStatus.done,
            source: RoutineSource.app,
          ),
        ],
      );
      expect(find.byKey(const Key('home-routine-next')), findsNothing);
    });
  });

  group('the widget', () {
    testWidgets('a catalog item by name, with Done and My routine', (
      tester,
    ) async {
      final h = await boot(tester, items: [water]);
      await settleWidget(tester);
      final e = h.widget.last!.current;
      expect(e.slot, WidgetSlot.routineItem);
      expect(e.headline, 'Drink water');
      expect(e.subline, contains('9:00'));
      // Lock screen: generic (details hidden by default).
      expect(e.lockHeadline, 'A small step from your routine');
    });

    testWidgets("a custom item's words never reach the widget", (tester) async {
      final h = await boot(tester, items: [call]);
      await settleWidget(tester);
      final s = h.widget.last!;
      expect(s.current.headline, 'Your next routine step');
      expect(jsonEncode(s.toJson()), isNot(contains('Call mom')));
      expect(jsonEncode(s.toJson()), isNot(contains('test results')));
    });

    testWidgets("the widget's Done logs the item from the widget", (
      tester,
    ) async {
      final h = await boot(tester, items: [water]);
      h.widgetInbox.routinePayload = 'routine:2026-10-14:water';
      h.widgetInbox.tap(WidgetLink.routineDone);
      await tester.pumpAndSettle();
      final logs = await h.routines.watchLogs('2026-10-14').first;
      expect(logs.single.status, RoutineStatus.done);
      expect(logs.single.source, RoutineSource.widget);
    });

    testWidgets('My routine on the widget opens the routine', (tester) async {
      final h = await boot(tester, items: [water]);
      h.widgetInbox.tap(WidgetLink.routine);
      await tester.pumpAndSettle();
      expect(find.byType(RoutineScreen), findsOneWidget);
    });
  });

  group('Track', () {
    testWidgets('the Routine chip: items done per day, gentle when none', (
      tester,
    ) async {
      await boot(
        tester,
        items: [water, call],
        logs: [
          for (final (date, id) in [
            ('2026-10-12', 'water'),
            ('2026-10-12', 'call'),
            ('2026-10-14', 'water'),
          ])
            RoutineLog(
              date: date,
              itemId: id,
              status: RoutineStatus.done,
              source: RoutineSource.app,
            ),
        ],
      );
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-chip-routine')));
      await tester.tap(find.byKey(const Key('track-chip-routine')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Wednesday: 1 done. Selected.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Monday: 2 done'), findsOneWidget);
      // Tuesday: no bar and no "missed".
      expect(find.bySemanticsLabel('Tuesday: nothing logged'), findsOneWidget);
    });

    testWidgets('no routine yet: an invitation to build one', (tester) async {
      final h = signedIn(name: 'Priya Rao');
      await h.boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-chip-routine')));
      await tester.tap(find.byKey(const Key('track-chip-routine')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Build your routine'), findsOneWidget);
    });
  });
}
