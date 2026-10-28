import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/goals/domain/goal.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/learn/presentation/learn_screen.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';
import 'package:livewell/features/plan/presentation/framework_screen.dart';
import 'package:livewell/features/plan/presentation/plan_screen.dart';
import 'package:livewell/features/routine/presentation/routine_screen.dart';
import 'package:livewell/features/track/domain/weekly_wins.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';
import 'package:livewell/features/track/presentation/weekly_wins_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn, today, uid;
import '../plan/plan_screen_test.dart' show openPlan, openTab, scrollTo;

/// Step 4b (D-54): weekly wins from the phone's data, and every MY GOAL DO
/// IT letter opening something real. No "coming soon".

Future<void> openWins(WidgetTester tester) async {
  await openTab(tester, 'Track');
  await scrollTo(tester, find.byKey(const Key('track-weekly-wins')));
  await tester.tap(find.byKey(const Key('track-weekly-wins')));
  await tester.pumpAndSettle();
  expect(find.byType(WeeklyWinsScreen), findsOneWidget);
}

Future<void> openFramework(WidgetTester tester) async {
  await openPlan(tester);
  await scrollTo(tester, find.byKey(const Key('plan-framework')));
  await tester.tap(find.byKey(const Key('plan-framework')));
  await tester.pumpAndSettle();
  expect(find.byType(FrameworkScreen), findsOneWidget);
}

Future<void> tapLetter(WidgetTester tester, int i) async {
  final f = find.byKey(Key('framework-$i'));
  await tester.scrollUntilVisible(
    f,
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

CheckIn checkIn(String date, int mood) =>
    CheckIn(date: date, mood: mood, gentleDay: false);

void main() {
  group('the rules', () {
    WeeklyWins wins({
      int checkIns = 0,
      int ticks = 0,
      int routine = 0,
      bool habits = false,
    }) => WeeklyWins(
      checkInDays: checkIns,
      habitTicks: ticks,
      routineDone: routine,
      hasHabits: habits,
    );

    test('one small change, in a fixed order', () {
      expect(wins().change, NextWeekChange.firstCheckIn);
      expect(wins(routine: 3).change, NextWeekChange.moreCheckIns);
      expect(wins(checkIns: 2).change, NextWeekChange.moreCheckIns);
      expect(
        wins(checkIns: 5, habits: true).change,
        NextWeekChange.smallerHabit,
      );
      expect(
        wins(checkIns: 5, ticks: 4, habits: true).change,
        NextWeekChange.keepGoing,
      );
      expect(wins(checkIns: 4).change, NextWeekChange.keepGoing);
    });

    test('the usual mood: most often, the kinder one on a tie', () {
      expect(WeeklyWins.usualOf(const []), isNull);
      expect(WeeklyWins.usualOf([3, 4, 4, 2]), 4);
      expect(WeeklyWins.usualOf([2, 2, 4, 4]), 4);
    });
  });

  group('weekly wins (Track > Weekly Reflection)', () {
    testWidgets('a new account: a kind fresh-week card, never zeros', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openWins(tester);
      expect(find.byKey(const Key('wins-empty')), findsOneWidget);
      expect(find.byKey(const Key('wins-change-firstCheckIn')), findsOne);
      expect(find.textContaining(RegExp(r'\b0\b')), findsNothing);
      expect(find.textContaining('coming soon'), findsNothing);
    });

    testWidgets('the last 7 days from check-ins and habit ticks', (
      tester,
    ) async {
      final h = signedIn();
      for (final (date, mood) in [
        ('2026-10-14', 4),
        ('2026-10-13', 4),
        ('2026-10-11', 3),
        // Older than 7 days: not counted.
        ('2026-10-01', 1),
      ]) {
        h.checkIns.days[date] = checkIn(date, mood);
      }
      for (final date in ['2026-10-12', '2026-10-13', '2026-10-14']) {
        await h.goals.saveLog(HabitLog(date: date, habitId: 'support_1'));
      }
      await h.goals.saveHabit(
        const UserHabit(
          id: 'support_1',
          title: 'Glass of water',
          anchor: HabitAnchor.wakeUp,
          minutes: 2,
        ),
      );
      await h.boot(tester);
      await openWins(tester);
      expect(find.text('You checked in on 3 days.'), findsOneWidget);
      expect(find.text('Your mood was mostly “Good”.'), findsOneWidget);
      expect(find.text('You did your habits 3 times.'), findsOneWidget);
      expect(find.byKey(const Key('wins-change-keepGoing')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wins-open-plan')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScreen), findsOneWidget);
    });

    testWidgets('a low week: no mood listed as a "win"', (tester) async {
      final h = signedIn();
      for (final date in ['2026-10-13', '2026-10-14']) {
        h.checkIns.days[date] = checkIn(date, 1);
      }
      await h.boot(tester);
      await openWins(tester);
      expect(find.byKey(const Key('wins-checkins')), findsOneWidget);
      expect(find.byKey(const Key('wins-mood')), findsNothing);
      expect(find.byKey(const Key('wins-change-moreCheckIns')), findsOne);
    });

    testWidgets('dev preview: sample week', (tester) async {
      await bootPreview(tester);
      await openWins(tester);
      expect(find.text('You checked in on 5 days.'), findsOneWidget);
      expect(
        find.text('You kept up a morning walk on 5 days.'),
        findsOneWidget,
      );
    });
  });

  group('MY GOAL DO IT: every letter opens something', () {
    testWidgets('no "Coming soon" and every row has a way in', (tester) async {
      await signedIn().boot(tester);
      await openFramework(tester);
      for (var i = 0; i < 10; i++) {
        final f = find.byKey(Key('framework-$i'));
        await tester.scrollUntilVisible(
          f,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.descendant(of: f, matching: find.byIcon(Icons.chevron_right)),
          findsOneWidget,
          reason: 'letter $i',
        );
      }
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('Mindset shows the day\'s thought', (tester) async {
      await signedIn().boot(tester);
      await openFramework(tester);
      await tapLetter(tester, 0);
      expect(find.byKey(const Key('framework-thought')), findsOneWidget);
    });

    for (final (i, screen, name) in [
      (2, PlanScreen, 'Goals'),
      (3, RoutineScreen, 'Organization'),
      (5, LearnScreen, 'Lifestyle'),
      (6, PlanScreen, 'Discipline'),
      (7, WeeklyWinsScreen, 'Optimism'),
      (8, HomeScreen, 'Implementation'),
      (9, TrackScreen, 'Tracking'),
    ]) {
      testWidgets('$name opens $screen', (tester) async {
        await signedIn().boot(tester);
        await openFramework(tester);
        await tapLetter(tester, i);
        expect(find.byType(screen), findsOneWidget);
      });
    }

    testWidgets('Accountability opens today\'s check-in', (tester) async {
      await signedIn().boot(tester);
      await openFramework(tester);
      await tapLetter(tester, 4);
      expect(find.byType(CheckInSheet), findsOneWidget);
    });

    testWidgets('Accountability, already checked in today: Track', (
      tester,
    ) async {
      final h = signedIn();
      h.checkIns.days[today] = checkIn(today, 4);
      await h.boot(tester);
      await openFramework(tester);
      await tapLetter(tester, 4);
      expect(find.byType(TrackScreen), findsOneWidget);
    });

    testWidgets('Your Why: change it, saved, back; onboarding step kept', (
      tester,
    ) async {
      final h = signedIn(why: 'Energy for my family');
      await h.boot(tester);
      await openFramework(tester);
      expect(find.text('“Energy for my family”'), findsOneWidget);
      await tapLetter(tester, 1);
      expect(find.byType(WhyScreen), findsOneWidget);
      expect(find.text('Energy for my family'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Energy to travel with my family',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(h.profiles.whys[uid], 'Energy to travel with my family');
      expect(h.profiles.existing[uid], ProfileStep.assessment);
      expect(find.byType(FrameworkScreen), findsOneWidget);
      expect(find.text('Your Why is saved.'), findsOneWidget);
    });
  });
}
