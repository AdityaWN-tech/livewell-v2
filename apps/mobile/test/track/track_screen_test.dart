import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';
import 'package:livewell/features/track/presentation/weekly_wins_screen.dart';
import 'package:livewell/features/track/domain/track_models.dart';
import 'package:livewell/features/track/domain/track_stats.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn, today;
import '../support/app_harness.dart';

Future<void> openTrack(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Track'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(TrackScreen), findsOneWidget);
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

Future<void> openReflection(WidgetTester tester) async {
  await openTrack(tester);
  await scrollTo(tester, find.byKey(const Key('reflection-field')));
}

String text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

/// 2026-10-14 is a Wednesday: Monday 12th to Sunday 18th.
CheckIn day(String date, int mood, {int? sleep, int? stress}) => CheckIn(
  date: date,
  mood: mood,
  sleep: sleep,
  stress: stress,
  gentleDay: isGentleDay(mood: mood, stress: stress),
);

Future<void> writeReflection(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('reflection-field')), text);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('reflection-save')));
  await tester.tap(find.byKey(const Key('reflection-save')));
  await tester.pumpAndSettle();
}

void main() {
  test('personal best only when the streak reaches the best', () {
    const week = [StreakDay.upcoming];
    expect(
      const StreakSummary(length: 14, best: 14, week: week).isPersonalBest,
      isTrue,
    );
    expect(
      const StreakSummary(length: 3, best: 14, week: week).isPersonalBest,
      isFalse,
    );
    expect(
      const StreakSummary(length: 0, best: 0, week: week).isPersonalBest,
      isFalse,
    );
  });

  group('periods', () {
    test('This Week starts Monday, This Month the 1st, 90 days back', () {
      final wed = DateTime(2026, 10, 14, 8);
      expect(TrackPeriod.week.start(wed), DateTime(2026, 10, 12));
      expect(TrackPeriod.month.start(wed), DateTime(2026, 10));
      expect(TrackPeriod.quarter.start(wed), DateTime(2026, 7, 17));
      expect(weekDates(wed).first, '2026-10-12');
      expect(weekDates(wed).last, '2026-10-18');
    });

    test('a daylight-saving change never shifts a day', () {
      // US clocks go back on 2026-11-01 (a Sunday).
      expect(weekDates(DateTime(2026, 11, 2)), [
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
        '2026-11-08',
      ]);
      expect(
        TrackPeriod.week.start(DateTime(2026, 11, 1)),
        DateTime(2026, 10, 26),
      );
    });

    test('averages use the nearest answer word, never clinical terms', () {
      final s = TrackStats([
        day('2026-10-12', 4, stress: 2),
        day('2026-10-13', 5, stress: 3),
        day('2026-10-14', 4),
      ]);
      expect(s.mood, closeTo(4.33, 0.01));
      expect(TrackStats.nearest(s.mood!), 4);
      expect(s.stress, 2.5);
      expect(TrackStats.nearest(s.stress!), 3);
      expect(s.sleep, isNull);
      expect(s.recent((c) => c.mood), [4, 5, 4]);
    });
  });

  group('real account (prod)', () {
    testWidgets('no check-ins: kind empty states, no sample data', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      expect(find.text('PROGRESSION'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      // Steps need Apple Health / Health Connect (not built yet).
      expect(text(tester, 'track-steps-value'), 'Connect Health');
      expect(text(tester, 'track-sleep-value'), 'No check-ins yet');
      expect(text(tester, 'track-mood-value'), 'No check-ins yet');
      expect(text(tester, 'track-stress-value'), 'No check-ins yet');
      await scrollTo(tester, find.byKey(const Key('track-chart-empty')));
      expect(find.text('Check in to see your week here.'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('track-weekly-wins')));
      expect(
        find.textContaining('Your streak starts with your first habit.'),
        findsOneWidget,
      );
      // No sample data and no percentages or clinical wording.
      expect(find.textContaining('14-day'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('6,432'), findsNothing);
      expect(find.textContaining('baseline'), findsNothing);
    });

    testWidgets('averages and words from this week\'s check-ins', (
      tester,
    ) async {
      final h = signedIn();
      for (final c in [
        day('2026-10-05', 1, sleep: 1, stress: 5), // last week: not counted
        day('2026-10-12', 4, sleep: 4, stress: 2),
        day('2026-10-13', 5, sleep: 3, stress: 3),
        day(today, 4, sleep: 5, stress: 2),
      ]) {
        h.checkIns.days[c.date] = c;
      }
      await h.boot(tester);
      await openTrack(tester);
      expect(text(tester, 'track-mood-value'), '4.3 / 5');
      expect(text(tester, 'track-mood-detail'), 'Good');
      expect(text(tester, 'track-stress-value'), '2.3 / 5');
      // Full words (phone bug): "Low", never a cut-off word.
      expect(text(tester, 'track-stress-detail'), 'Low');
      expect(text(tester, 'track-sleep-value'), 'Well');
      expect(text(tester, 'track-sleep-detail'), 'From your check-ins');
    });

    testWidgets('This Month and 90 days include older check-ins', (
      tester,
    ) async {
      final h = signedIn();
      for (final c in [
        day('2026-08-01', 1, stress: 5),
        day('2026-10-02', 2, stress: 4),
        day(today, 5, stress: 1),
      ]) {
        h.checkIns.days[c.date] = c;
      }
      await h.boot(tester);
      await openTrack(tester);
      expect(text(tester, 'track-mood-value'), '5.0 / 5');
      for (final (period, mood) in [
        ('month', '3.5 / 5'),
        ('quarter', '2.7 / 5'),
      ]) {
        await tester.tap(find.byKey(const Key('track-period')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('track-period-$period')).last);
        await tester.pumpAndSettle();
        expect(text(tester, 'track-mood-value'), mood, reason: period);
      }
      expect(find.text('90 days'), findsOneWidget);
    });

    testWidgets('the chart: this week by day, today selected with a bubble', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = signedIn();
      for (final c in [
        day('2026-10-12', 4, sleep: 4),
        day(today, 2, sleep: 1),
      ]) {
        h.checkIns.days[c.date] = c;
      }
      await h.boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-bar-6')));
      // Mood is first; today (Wednesday) is selected.
      expect(
        find.descendant(
          of: find.byKey(const Key('track-bar-2')),
          matching: find.byKey(const Key('track-bubble')),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Wednesday: Low. Selected.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Monday: Good'), findsOneWidget);
      expect(find.bySemanticsLabel('Tuesday: nothing logged'), findsOneWidget);
      // Tap Monday: its value shows in the bubble.
      await tester.tap(find.byKey(const Key('track-bar-0')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Monday: Good. Selected.'), findsOneWidget);
      // Sleep uses the sleep words; a new chip starts on today again.
      await tester.ensureVisible(find.byKey(const Key('track-chip-sleep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track-chip-sleep')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Wednesday: Very badly. Selected.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Monday: Well'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('nothing today yet: the latest day with an answer is shown', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = signedIn();
      h.checkIns.days['2026-10-12'] = day('2026-10-12', 5);
      await h.boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-bar-6')));
      expect(find.bySemanticsLabel('Monday: Great. Selected.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Steps and Habits: kind notes until Health and habits exist', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-chip-steps')));
      await tester.tap(find.byKey(const Key('track-chip-steps')));
      await tester.pumpAndSettle();
      expect(
        find.text('Connect Health to see your steps here.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('track-chip-habits')));
      await tester.pumpAndSettle();
      expect(
        find.text('Your habits will show here once you start one.'),
        findsOneWidget,
      );
    });

    testWidgets('Connect Health says it is coming soon', (tester) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      await tester.tap(find.byKey(const Key('track-card-steps')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('track-health-soon')), findsOneWidget);
    });

    testWidgets('Weekly Reflection: "How was your week?" opens weekly wins', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-weekly-wins')));
      expect(find.text('How was your week?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('track-weekly-wins')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyWinsScreen), findsOneWidget);
    });

    testWidgets('a new check-in updates Track', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openTrack(tester);
      expect(text(tester, 'track-mood-value'), 'No check-ins yet');
      await h.checkIns.save(day(today, 3, stress: 4));
      await tester.pumpAndSettle();
      expect(text(tester, 'track-mood-value'), '3.0 / 5');
      expect(text(tester, 'track-stress-detail'), 'High');
    });
  });

  group('evening reflection (FR-DLY-05)', () {
    testWidgets('saves for today; analytics gets the mode only', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      await writeReflection(tester, 'Walked after lunch with my sister');
      expect(
        h.reflections.days[today]!.text,
        'Walked after lunch with my sister',
      );
      expect(find.byKey(const Key('reflection-saved')), findsOneWidget);
      expect(h.analytics.events.single, {
        'name': 'reflection_submitted',
        'mode': 'text',
      });
    });

    testWidgets("today's saved reflection shows again, and can be edited", (
      tester,
    ) async {
      final h = signedIn();
      h.reflections.days[today] = const Reflection(
        date: today,
        text: 'Slept well',
      );
      await h.boot(tester);
      await openReflection(tester);
      expect(find.text('Slept well'), findsOneWidget);
      expect(find.byKey(const Key('reflection-saved')), findsOneWidget);
      await writeReflection(tester, 'Slept well and walked');
      expect(h.reflections.days[today]!.text, 'Slept well and walked');
    });

    testWidgets('Save is off while the box is empty', (tester) async {
      await signedIn().boot(tester);
      await openReflection(tester);
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('reflection-save')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('crisis text: the crisis card, and nothing is saved', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      await writeReflection(tester, 'I want to end my life');
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      await tapText(tester, 'Go back');
      expect(h.reflections.days, isEmpty);
      expect(h.reflections.saves, 0);
      expect(find.text('This was not saved.'), findsOneWidget);
      expect(h.analytics.events, isEmpty);
    });

    testWidgets('emergency text: the emergency card, nothing saved', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      await writeReflection(tester, 'I have crushing chest pain');
      expect(find.text('This could be an emergency'), findsOneWidget);
      await tapText(tester, 'Go back');
      expect(h.reflections.days, isEmpty);
    });

    testWidgets('medication note: a note first, then it may be saved', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      await writeReflection(tester, 'Should I stop my metformin?');
      expect(find.byType(SafetyNoticeSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SafetyNoticeSheet),
          matching: find.text('Save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.reflections.days[today]!.text, 'Should I stop my metformin?');
    });

    testWidgets('voice asks for the microphone consent, then fills the box', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      await tester.ensureVisible(find.byKey(const Key('reflection-mic')));
      await tester.tap(find.byKey(const Key('reflection-mic')));
      await tester.pumpAndSettle();
      expect(find.text('Use your microphone?'), findsOneWidget);
      await tapText(tester, 'Allow');
      expect(h.consents.records.single.type, ConsentType.microphone);
      h.dictation.say('A calm evening walk');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reflection-save')));
      await tester.pumpAndSettle();
      expect(h.reflections.days[today]!.text, 'A calm evening walk');
      expect(h.analytics.events.single['mode'], 'voice');
    });
  });

  group('dev preview: sample data', () {
    testWidgets('Health samples, streak, personal best and a rest day', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await bootPreview(tester);
      await openTrack(tester);
      // Wednesday's sample steps.
      expect(text(tester, 'track-steps-value'), '4,800');
      expect(text(tester, 'track-steps-detail'), 'of 8,000');
      expect(text(tester, 'track-sleep-value'), '7h 20m');
      await scrollTo(tester, find.byKey(const Key('track-streak')));
      expect(find.text('14-day streak'), findsOneWidget);
      expect(find.text('Personal best'), findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday: rest day'), findsOneWidget);
      expect(find.bySemanticsLabel('Monday: done'), findsOneWidget);
      expect(
        find.text(
          'Rest days are part of the plan. One each week keeps your streak going.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Steps chart: the selected day\'s count in the bubble', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await bootPreview(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-chip-steps')));
      await tester.tap(find.byKey(const Key('track-chip-steps')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Wednesday: 4,800. Selected.'),
        findsOneWidget,
      );
      // Days after today have nothing yet.
      expect(find.bySemanticsLabel('Friday: nothing logged'), findsOneWidget);
      handle.dispose();
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
          await openTrack(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(
            find.bySemanticsLabel('Showing This Week. Opens the choices.'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp(r'^Mood: \d\.\d / 5\. ')),
            findsOneWidget,
          );
          await scrollTo(tester, find.byKey(const Key('track-bar-6')));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await scrollTo(tester, find.byKey(const Key('reflection-mic')));
          expect(find.byTooltip('Speak instead'), findsOneWidget);
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
        await openTrack(tester);
        expect(tester.takeException(), isNull);
        for (final key in [
          'track-bar-6',
          'track-weekly-wins',
          'reflection-save',
        ]) {
          await scrollTo(tester, find.byKey(Key(key)));
          expect(tester.takeException(), isNull, reason: key);
        }
      });
    }
  });
}
