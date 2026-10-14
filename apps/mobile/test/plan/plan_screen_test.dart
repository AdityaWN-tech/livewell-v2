import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/plan/domain/plan_models.dart';
import 'package:livewell/features/plan/presentation/framework_screen.dart';
import 'package:livewell/features/plan/presentation/plan_screen.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;

Future<void> openPlan(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Plan'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(PlanScreen), findsOneWidget);
}

PlanHabit habit(String id, HabitRole role) => PlanHabit(
  id: id,
  role: role,
  driver: 'Driver 1',
  title: id,
  status: HabitStatus.scheduled,
);

void main() {
  group('FR-GOL-01 limits: 1 daily habit + 2 supporting', () {
    test('room until each slot is used', () {
      expect(HabitLimits.isFull(const []), isFalse);
      final one = [habit('a', HabitRole.microhabit)];
      expect(HabitLimits.canAdd(one, HabitRole.microhabit), isFalse);
      expect(HabitLimits.canAdd(one, HabitRole.supporting), isTrue);
      final full = [
        ...one,
        habit('b', HabitRole.supporting),
        habit('c', HabitRole.supporting),
      ];
      expect(HabitLimits.canAdd(full, HabitRole.supporting), isFalse);
      expect(HabitLimits.isFull(full), isTrue);
    });
  });

  group('real account (prod)', () {
    testWidgets('header, framework chip, empty state, affirmation', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openPlan(tester);
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.text('MY GOAL DO IT Framework · 8 Drivers'), findsOneWidget);
      expect(find.text('No habits yet'), findsOneWidget);
      expect(find.byKey(const Key('plan-affirmation')), findsOneWidget);
      // No sample habits outside the dev preview.
      expect(find.textContaining('walk after lunch'), findsNothing);
      expect(find.textContaining(RegExp(r'Driver \d')), findsNothing);
    });

    testWidgets('the affirmation is the same all day, by date', (tester) async {
      final h = signedIn()..now = DateTime(2026, 10, 14, 7); // day 286
      await h.boot(tester);
      await openPlan(tester);
      expect(find.text('“Small steps still count.”'), findsOneWidget);
    });

    testWidgets('New habit with room: kind "coming soon" note', (tester) async {
      await signedIn().boot(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-new-habit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-add-soon')), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-add-soon')), findsNothing);
    });

    testWidgets('MY GOAL DO IT opens from Plan with all 10 letters', (
      tester,
    ) async {
      final h = signedIn(why: 'Energy to travel with my family');
      await h.boot(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-framework')));
      await tester.pumpAndSettle();
      expect(find.byType(FrameworkScreen), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await tester.scrollUntilVisible(
          find.byKey(Key('framework-$i')),
          100,
          scrollable: find.byType(Scrollable).last,
        );
      }
      expect(find.text('“Energy to travel with my family”'), findsOneWidget);
      // Tracking leads to the Track tab.
      await tester.tap(find.byKey(const Key('framework-9')));
      await tester.pumpAndSettle();
      expect(find.byType(TrackScreen), findsOneWidget);
    });
  });

  group('dev preview: sample plan', () {
    testWidgets('habit cards show driver, status words, times, microstep', (
      tester,
    ) async {
      await bootPreview(tester);
      await openPlan(tester);
      expect(find.text('Driver 2'), findsOneWidget);
      expect(
        find.text('Supporting habit · Done'),
        findsOneWidget,
        reason: 'status is in words, not colour only',
      );
      expect(find.text('Completed at 8:15 AM'), findsOneWidget);
      expect(find.text('Daily habit · In progress'), findsOneWidget);
      expect(find.text('Target: 1:30 PM'), findsOneWidget);
      expect(
        find.text('Microstep: Put your walking shoes on now'),
        findsOneWidget,
      );
      expect(find.text('Supporting habit · Scheduled'), findsOneWidget);
      final done = tester.widget<Text>(
        find.text('Glass of water with breakfast'),
      );
      expect(done.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('ticking a habit marks it done with the time', (tester) async {
      final h = await bootPreview(tester);
      h.now = DateTime(2026, 10, 14, 13, 40);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('habit-sample-walk-done')));
      await tester.pumpAndSettle();
      expect(find.text('Daily habit · Done'), findsOneWidget);
      expect(find.text('Completed at 1:40 PM'), findsOneWidget);
    });

    testWidgets('plan is full: New habit explains the limit kindly', (
      tester,
    ) async {
      await bootPreview(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-new-habit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-full')), findsOneWidget);
      expect(find.text('Your plan is full'), findsOneWidget);
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets(
        'labels, tap targets and contrast (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final handle = tester.ensureSemantics();
          await bootPreview(tester);
          await openPlan(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(
            find.bySemanticsLabel('Open the MY GOAL DO IT framework'),
            findsOneWidget,
          );
          expect(
            find.byTooltip('Mark "10-min walk after lunch" done'),
            findsOneWidget,
          );
          handle.dispose();
        },
      );
    }
  });
}
