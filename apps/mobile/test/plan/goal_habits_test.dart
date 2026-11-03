import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/goals/data/goal_repository.dart';
import 'package:livewell/features/goals/domain/goal.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../home/home_screen_test.dart' show signedIn, today;
import '../support/app_harness.dart';
import 'plan_screen_test.dart' show openPlan, scrollTo, withStarterPlan;

/// Step 4a (FR-GOL-01/02, D-53): the 30-day goal and the person's own
/// supporting habits, saved; no "coming soon" on Plan.

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  // The Plan list builds lazily: scroll until the row exists.
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

Goal goal({GoalStatus status = GoalStatus.active, String start = today}) =>
    Goal(
      action: 'Walk after dinner',
      daysPerWeek: 5,
      minutes: 10,
      anchor: HabitAnchor.dinner,
      barrierPlan: 'Walk indoors if it rains',
      status: status,
      startDate: start,
    );

Future<Harness> bootPlan(WidgetTester tester, [Harness? harness]) async {
  final h = harness ?? signedIn();
  await h.boot(tester);
  await openPlan(tester);
  return h;
}

void main() {
  group('domain', () {
    test('day X of 30 counts from the start date and stops at 30', () {
      final g = goal(start: '2026-10-01');
      expect(g.dayOn('2026-10-01'), 1);
      expect(g.dayOn('2026-10-12'), 12);
      expect(g.progressOn('2026-10-12'), 12 / 30);
      expect(g.dayOn('2026-12-01'), 30);
    });

    test('only valid goals and habits (short words, fixed choices)', () {
      expect(goal().isValid, isTrue);
      expect(goal().copyWith(action: ' ').isValid, isFalse);
      expect(goal().copyWith(daysPerWeek: 8).isValid, isFalse);
      expect(goal().copyWith(minutes: 7).isValid, isFalse);
      expect(goal().copyWith(action: 'x' * 61).isValid, isFalse);
      const h = UserHabit(
        id: 'support_1',
        title: 'Glass of water',
        anchor: HabitAnchor.wakeUp,
        minutes: 2,
      );
      expect(h.isValid, isTrue);
      expect(
        const UserHabit(
          id: 'support_3',
          title: 'x',
          anchor: HabitAnchor.wakeUp,
          minutes: 2,
        ).isValid,
        isFalse,
        reason: 'two own habits at most: only two ids exist',
      );
    });

    test('FR-GOL-01: a free slot only while fewer than 2 supporting', () {
      const a = UserHabit(
        id: 'support_1',
        title: 'a',
        anchor: HabitAnchor.lunch,
        minutes: 5,
      );
      expect(freeHabitSlot(const [], 0), 'support_1');
      expect(freeHabitSlot(const [a], 1), 'support_2');
      // The plan's own supporting habit counts too.
      expect(freeHabitSlot(const [a], 2), isNull);
      // A stopped habit frees its slot.
      expect(freeHabitSlot([a.copyWith(active: false)], 1), 'support_1');
    });

    test('Firestore fields round-trip', () {
      final g = goal();
      expect(
        FirestoreGoalRepository.goalFrom(FirestoreGoalRepository.goalData(g)),
        g,
      );
      expect(FirestoreGoalRepository.goalFrom({'action': 'x'}), isNull);
    });
  });

  group('the 30-day goal (FR-GOL-02)', () {
    testWidgets('set a goal: card shows it on day 1', (tester) async {
      final h = await bootPlan(tester);
      await tapKey(tester, 'plan-goal-set');
      expect(find.byKey(const Key('goal-sheet')), findsOneWidget);
      await type(tester, 'goal-action', 'Walk after dinner');
      await tapKey(tester, 'goal-days-4');
      await tapKey(tester, 'goal-minutes-15');
      await tapKey(tester, 'goal-anchor-dinner');
      await type(tester, 'goal-barrier', 'Walk indoors if it rains');
      await tapKey(tester, 'goal-save');
      final saved = h.goals.goal!;
      expect(saved.action, 'Walk after dinner');
      expect(saved.daysPerWeek, 4);
      expect(saved.minutes, 15);
      expect(saved.anchor, HabitAnchor.dinner);
      expect(saved.barrierPlan, 'Walk indoors if it rains');
      expect(saved.linkWhy, isTrue);
      expect(saved.startDate, today);
      expect(find.text('Walk after dinner'), findsOneWidget);
      expect(find.text('Day 1 of 30'), findsOneWidget);
      expect(find.text('Your goal is saved.'), findsOneWidget);
    });

    testWidgets('edit keeps the start day; pause and restart', (tester) async {
      final h = signedIn();
      h.goals.goal = goal(start: '2026-10-05');
      await bootPlan(tester, h);
      await scrollTo(tester, find.byKey(const Key('plan-goal')));
      expect(find.text('Day 10 of 30'), findsOneWidget);
      await tapKey(tester, 'plan-goal-edit');
      await type(tester, 'goal-action', 'Walk after lunch');
      await tapKey(tester, 'goal-save');
      expect(h.goals.goal!.action, 'Walk after lunch');
      expect(h.goals.goal!.startDate, '2026-10-05', reason: 'not restarted');

      await tapKey(tester, 'plan-goal-edit');
      await tapKey(tester, 'goal-pause');
      expect(h.goals.goal!.status, GoalStatus.paused);
      expect(find.byKey(const Key('plan-goal-paused')), findsOneWidget);

      await tapKey(tester, 'plan-goal-edit');
      expect(find.byKey(const Key('goal-pause')), findsNothing);
      await tapKey(tester, 'goal-restart');
      expect(h.goals.goal!.status, GoalStatus.active);
      expect(h.goals.goal!.startDate, today);
      expect(find.text('Day 1 of 30'), findsOneWidget);
    });

    testWidgets('weight goals get a kind message; reworded, it saves', (
      tester,
    ) async {
      final h = await bootPlan(tester);
      await tapKey(tester, 'plan-goal-set');
      await type(tester, 'goal-action', 'Count calories');
      await tapKey(tester, 'goal-save');
      expect(find.byKey(const Key('goal-error')), findsOneWidget);
      expect(
        find.textContaining('not weight, calories or diets'),
        findsOneWidget,
      );
      expect(h.goals.goal, isNull);
      await type(tester, 'goal-action', 'Cook dinner at home');
      await tapKey(tester, 'goal-save');
      expect(h.goals.goal!.action, 'Cook dinner at home');
    });

    testWidgets('the barrier plan is checked too', (tester) async {
      final h = await bootPlan(tester);
      await tapKey(tester, 'plan-goal-set');
      await type(tester, 'goal-action', 'Walk after dinner');
      await type(tester, 'goal-barrier', 'Fish oil instead');
      await tapKey(tester, 'goal-save');
      expect(find.textContaining("can't be a goal or habit"), findsOneWidget);
      expect(h.goals.goal, isNull);
    });

    testWidgets('a red flag shows the safety screen; nothing is saved', (
      tester,
    ) async {
      final h = await bootPlan(tester);
      await tapKey(tester, 'plan-goal-set');
      await type(tester, 'goal-action', 'I want to die');
      await tapKey(tester, 'goal-save');
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      expect(h.goals.goal, isNull);
    });
  });

  group('own supporting habits (FR-GOL-01)', () {
    Future<void> addHabit(WidgetTester tester, String title) async {
      await tapKey(tester, 'plan-new-habit');
      await type(tester, 'habit-title', title);
      await tapKey(tester, 'habit-anchor-wakeUp');
      await tapKey(tester, 'habit-minutes-2');
      await tapKey(tester, 'habit-save');
    }

    testWidgets('add, tick done (saved with the time), change, stop', (
      tester,
    ) async {
      final h = signedIn()..now = DateTime(2026, 10, 14, 7, 30);
      await bootPlan(tester, h);
      await addHabit(tester, 'Drink a glass of water');
      final saved = h.goals.habits['support_1']!;
      expect(saved.title, 'Drink a glass of water');
      expect(saved.anchor, HabitAnchor.wakeUp);
      expect(saved.minutes, 2);
      expect(find.text('Drink a glass of water is in your plan.'), findsOne);
      await scrollTo(tester, find.byKey(const Key('habit-support_1')));
      expect(find.text('Supporting habit · Scheduled'), findsOneWidget);

      await tapKey(tester, 'habit-support_1-done');
      expect(h.goals.logs.keys, ['2026-10-14_support_1']);
      expect(find.text('Supporting habit · Done'), findsOneWidget);
      expect(find.text('Completed at 7:30 AM'), findsOneWidget);

      await tapKey(tester, 'habit-support_1-menu');
      await tapKey(tester, 'habit-menu-change');
      expect(find.text('Change this habit'), findsOneWidget);
      await type(tester, 'habit-title', 'Two glasses of water');
      await tapKey(tester, 'habit-save');
      expect(h.goals.habits['support_1']!.title, 'Two glasses of water');

      await tapKey(tester, 'habit-support_1-menu');
      await tapKey(tester, 'habit-menu-change');
      await tapKey(tester, 'habit-stop');
      expect(h.goals.habits['support_1']!.active, isFalse, reason: 'kept');
      expect(find.text('Two glasses of water'), findsNothing);
    });

    testWidgets("the plan's supporting habit counts: one more, then full", (
      tester,
    ) async {
      final h = withStarterPlan();
      await bootPlan(tester, h);
      await addHabit(tester, 'Stretch for a minute');
      expect(h.goals.habits.keys, ['support_1']);
      await tapKey(tester, 'plan-new-habit');
      expect(find.byKey(const Key('plan-full')), findsOneWidget);
      expect(find.byKey(const Key('habit-sheet')), findsNothing);
    });

    testWidgets("the plan's supporting habit is ticked and saved too", (
      tester,
    ) async {
      final h = withStarterPlan();
      await bootPlan(tester, h);
      await tapKey(tester, 'habit-support-water-done');
      expect(h.goals.logs.keys.single, endsWith('_support-water'));
      expect(find.byKey(const Key('habit-menu-change')), findsNothing);
    });

    testWidgets('habit words are checked like routine labels', (tester) async {
      final h = await bootPlan(tester);
      await tapKey(tester, 'plan-new-habit');
      await type(tester, 'habit-title', 'No excuses');
      await tapKey(tester, 'habit-save');
      expect(find.textContaining("Let's word it kindly"), findsOneWidget);
      await type(tester, 'habit-title', 'Skip dinner');
      await tapKey(tester, 'habit-save');
      expect(find.byType(SafetyNoticeSheet), findsOneWidget);
      expect(h.goals.habits, isEmpty);
    });
  });
}
