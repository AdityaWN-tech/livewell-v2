import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';
import 'package:livewell/features/track/domain/track_models.dart';
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

  group('real account (prod)', () {
    testWidgets('header, empty streak, not-logged tiles', (tester) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      expect(find.text('PROGRESSION'), findsOneWidget);
      expect(find.byKey(const Key('track-weekly-wins')), findsOneWidget);
      expect(
        find.textContaining('Your streak starts with your first habit.'),
        findsOneWidget,
      );
      expect(find.text('Not logged'), findsNWidgets(4));
      // No sample data and no percentages or clinical wording.
      expect(find.textContaining('14-day'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('baseline'), findsNothing);
    });

    testWidgets("tiles show today's check-in as the 1 to 5 words", (
      tester,
    ) async {
      final h = signedIn();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 4,
        energy: 5,
        sleep: 2,
        gentleDay: false,
      );
      await h.boot(tester);
      await openTrack(tester);
      expect(find.text('Good'), findsOneWidget); // mood 4
      expect(find.text('High'), findsOneWidget); // energy 5
      expect(find.text('Badly'), findsOneWidget); // sleep 2
      expect(find.text('Not logged'), findsOneWidget); // stress skipped
    });

    testWidgets('a tile opens the check-in', (tester) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      await tester.tap(find.byKey(const Key('track-tile-energy')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckInSheet), findsOneWidget);
    });

    testWidgets('Weekly wins says it is coming soon', (tester) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      await tester.tap(find.byKey(const Key('track-weekly-wins')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('track-weekly-wins-soon')), findsOneWidget);
    });
  });

  group('evening reflection (FR-DLY-05)', () {
    testWidgets('saves for today; analytics gets the mode only', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openTrack(tester);
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
      await openTrack(tester);
      expect(find.text('Slept well'), findsOneWidget);
      expect(find.byKey(const Key('reflection-saved')), findsOneWidget);
      await writeReflection(tester, 'Slept well and walked');
      expect(h.reflections.days[today]!.text, 'Slept well and walked');
    });

    testWidgets('Save is off while the box is empty', (tester) async {
      await signedIn().boot(tester);
      await openTrack(tester);
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
      await openTrack(tester);
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
      await openTrack(tester);
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
      await openTrack(tester);
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
      await openTrack(tester);
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

  group('dev preview: sample streak', () {
    testWidgets('streak, personal best, and a calm rest day', (tester) async {
      final handle = tester.ensureSemantics();
      await bootPreview(tester);
      await openTrack(tester);
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
            find.bySemanticsLabel('Energy: not logged yet. Tap to check in.'),
            findsOneWidget,
          );
          expect(find.byTooltip('Speak instead'), findsOneWidget);
          handle.dispose();
        },
      );
    }
  });
}
