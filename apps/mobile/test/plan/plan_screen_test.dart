import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/plan/domain/plan_models.dart';
import 'package:livewell/features/plan/presentation/framework_screen.dart';
import 'package:livewell/features/plan/presentation/live_well_map.dart';
import 'package:livewell/features/plan/presentation/plan_screen.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn, today;
import '../support/app_harness.dart';

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
  );
  await tester.pumpAndSettle();
}

Future<void> openPlan(WidgetTester tester) async {
  await openTab(tester, 'Plan');
  expect(find.byType(PlanScreen), findsOneWidget);
}

/// Scrolls [f] into view, clear of the bottom navigation bar.
Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

PlanHabit habit(String id, HabitRole role) => PlanHabit(
  id: id,
  role: role,
  driver: 'Driver 1',
  title: id,
  status: HabitStatus.scheduled,
);

/// A real account with today's starter-plan day (T-ONB-03e) saved.
Harness withStarterPlan() {
  final h = signedIn(name: 'Robert Hall');
  h.plans.days[today] = const PlanDay(
    date: today,
    dayNumber: 2,
    focus: FocusArea.moveMore,
    title: '10-min walk after lunch',
    reason: 'A short walk after a meal can help you feel less tired later.',
    anchor: 'After lunch',
    minutes: 10,
    smallerTitle: '5-min walk after lunch',
    smallerMinutes: 5,
    gentle: false,
    supporting: [
      SupportingHabit(
        id: 'water',
        title: 'Glass of water with breakfast',
        anchor: 'At breakfast',
        movement: false,
      ),
    ],
  );
  return h;
}

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

  group('the wheel', () {
    test('a tap is matched to its segment, clockwise from the top', () {
      const size = Size.square(200);
      // Just right of 12 o'clock is segment 0; just left is segment 7.
      expect(LiveWellMap.segmentAt(const Offset(110, 10), size, 8), 0);
      expect(LiveWellMap.segmentAt(const Offset(90, 10), size, 8), 7);
      expect(LiveWellMap.segmentAt(const Offset(190, 100), size, 8), 2);
      expect(LiveWellMap.segmentAt(const Offset(100, 190), size, 8), 4);
      // The centre and the corners are not segments.
      expect(LiveWellMap.segmentAt(const Offset(100, 100), size, 8), isNull);
      expect(LiveWellMap.segmentAt(const Offset(2, 2), size, 8), isNull);
    });
  });

  group('real account (prod)', () {
    testWidgets('no assessment, no plan: grey map, empty goal and habits', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openPlan(tester);
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.text('Your Live Well Map'), findsOneWidget);
      expect(
        find.text('Take your 10-minute check to fill your map.'),
        findsOneWidget,
      );
      await scrollTo(tester, find.byKey(const Key('plan-affirmation')));
      expect(
        find.text('Your 30-day goal is set after your 10-minute check.'),
        findsOneWidget,
      );
      expect(find.text('No habits yet'), findsOneWidget);
      // No sample data outside the dev preview.
      expect(find.textContaining('walk after lunch'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.byKey(const Key('plan-goal-edit')), findsNothing);
    });

    // Phone bug: Plan shows today's step, the same one Home shows.
    testWidgets('today\'s step from the starter plan is on Plan, like Home', (
      tester,
    ) async {
      await withStarterPlan().boot(tester);
      expect(find.text('10-min walk after lunch'), findsOneWidget);
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('habit-today-step')));
      expect(find.text('10-min walk after lunch'), findsOneWidget);
      expect(find.text('Daily habit · Scheduled'), findsOneWidget);
      expect(find.text('Glass of water with breakfast'), findsOneWidget);
      expect(find.text('Supporting habit · Scheduled'), findsOneWidget);
      expect(find.text('No habits yet'), findsNothing);
    });

    testWidgets('Done on Plan shows on Home, and the other way round', (
      tester,
    ) async {
      final h = withStarterPlan()..now = DateTime(2026, 10, 14, 13, 40);
      await h.boot(tester);
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('habit-today-step-done')));
      await tester.tap(find.byKey(const Key('habit-today-step-done')));
      await tester.pumpAndSettle();
      expect(find.text('Daily habit · Done'), findsOneWidget);
      expect(find.text('Completed at 1:40 PM'), findsOneWidget);
      await openTab(tester, 'Home');
      expect(find.byKey(const Key('step-done-message')), findsOneWidget);
    });

    testWidgets('"Make it smaller" on Home changes the step on Plan', (
      tester,
    ) async {
      await withStarterPlan().boot(tester);
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step-smaller')));
      await tester.pumpAndSettle();
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('habit-today-step')));
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      expect(find.text('10-min walk after lunch'), findsNothing);
    });

    testWidgets('"Make it smaller" from the habit menu, on both tabs', (
      tester,
    ) async {
      await withStarterPlan().boot(tester);
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('habit-today-step-menu')));
      await tester.tap(find.byKey(const Key('habit-today-step-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('habit-menu-smaller')));
      await tester.pumpAndSettle();
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      await openTab(tester, 'Home');
      expect(find.text('5-min walk after lunch'), findsOneWidget);
    });

    testWidgets('a gentle day: the smaller step on Plan too, as on Home', (
      tester,
    ) async {
      final h = withStarterPlan();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 1,
        gentleDay: true,
      );
      await h.boot(tester);
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('habit-today-step')));
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit-today-step-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('habit-menu-smaller')), findsNothing);
    });

    testWidgets('the calendar shows the plan\'s days, today first', (
      tester,
    ) async {
      await withStarterPlan().boot(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-week')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-week-sheet')), findsOneWidget);
      expect(find.text('Your week'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('plan-week-sheet')),
          matching: find.text('10-min walk after lunch'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no plan yet: the calendar says so kindly', (tester) async {
      await signedIn().boot(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-week')));
      await tester.pumpAndSettle();
      expect(find.text('Your plan’s days will show here.'), findsOneWidget);
    });

    testWidgets('a driver opens from the wheel and from its row', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-driver-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-driver-sheet-2')), findsOneWidget);
      expect(
        find.text('This part of your map fills in after your 10-minute check.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      // The top segment of the wheel is driver 1.
      final wheel = tester.getRect(find.byKey(const Key('plan-map-wheel')));
      await tester.tapAt(wheel.topCenter + Offset(wheel.width * 0.08, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-driver-sheet-0')), findsOneWidget);
    });

    testWidgets('the affirmation is the same all day, by date', (tester) async {
      final h = signedIn()..now = DateTime(2026, 10, 14, 7); // day 286
      await h.boot(tester);
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('plan-affirmation')));
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
      await scrollTo(tester, find.byKey(const Key('plan-framework')));
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
    testWidgets('filled map, goal, and the same step as Home', (tester) async {
      await bootPreview(tester);
      await openPlan(tester);
      expect(find.text('Driver 3 · 70%'), findsOneWidget);
      expect(find.byKey(const Key('plan-map-empty')), findsNothing);
      await scrollTo(tester, find.byKey(const Key('plan-goal')));
      expect(find.text('Feel more energetic every day'), findsOneWidget);
      expect(find.text('Day 12 of 30'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('habit-sample-screens')));
      expect(find.text('10-min walk after lunch'), findsOneWidget);
      expect(find.text('Daily habit · In progress'), findsOneWidget);
      expect(find.text('Target: 1:30 PM'), findsOneWidget);
      expect(
        find.text('Supporting habit · Done'),
        findsOneWidget,
        reason: 'status is in words, not colour only',
      );
      expect(find.text('Completed at 8:15 AM'), findsOneWidget);
      expect(find.text('Supporting habit · Scheduled'), findsOneWidget);
      final done = tester.widget<Text>(
        find.text('Glass of water with breakfast'),
      );
      expect(done.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('Edit goal: "coming soon", nothing changes', (tester) async {
      await bootPreview(tester);
      await openPlan(tester);
      await scrollTo(tester, find.byKey(const Key('plan-goal-edit')));
      await tester.tap(find.byKey(const Key('plan-goal-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-goal-edit-soon')), findsOneWidget);
    });

    testWidgets('ticking a supporting habit marks it done with the time', (
      tester,
    ) async {
      final h = await bootPreview(tester);
      h.now = DateTime(2026, 10, 14, 13, 40);
      await openPlan(tester);
      await scrollTo(
        tester,
        find.byKey(const Key('habit-sample-screens-done')),
      );
      await tester.tap(find.byKey(const Key('habit-sample-screens-done')));
      await tester.pumpAndSettle();
      expect(find.text('Supporting habit · Scheduled'), findsNothing);
      expect(find.text('Completed at 1:40 PM'), findsOneWidget);
    });

    testWidgets('a driver shows its 30-day completion', (tester) async {
      await bootPreview(tester);
      await openPlan(tester);
      await tester.tap(find.byKey(const Key('plan-driver-0')));
      await tester.pumpAndSettle();
      expect(
        find.text('60% of this driver’s steps done in the last 30 days.'),
        findsOneWidget,
      );
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
          expect(find.byTooltip('Open your week'), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              'Driver 1: 60% in the last 30 days. Opens details.',
            ),
            findsOneWidget,
          );
          await scrollTo(tester, find.byKey(const Key('plan-framework')));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(
            find.bySemanticsLabel('Open the MY GOAL DO IT framework'),
            findsOneWidget,
          );
          expect(
            find.byTooltip('Mark "10-min walk after lunch" done'),
            findsOneWidget,
          );
          expect(
            find.byTooltip('More options for 10-min walk after lunch'),
            findsOneWidget,
          );
          handle.dispose();
        },
      );
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('iPhone SE, text $scale: no overflow anywhere', (
        tester,
      ) async {
        await bootPreview(tester);
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openPlan(tester);
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.byKey(const Key('plan-affirmation')));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
