import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/learn/domain/breathing.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/presentation/breathing_screen.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../support/app_harness.dart';
import 'learn_screen_test.dart' show openLearn, scrollTo;

Future<Harness> openGuide(WidgetTester tester, {Lesson? session}) async {
  final h = signedIn();
  if (session != null) h.learn.lessons = [session];
  await h.boot(tester);
  await openLearn(tester);
  final key = Key(
    session == null ? 'learn-breathe' : 'audio-${session.id}-play',
  );
  await scrollTo(tester, find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  expect(find.byType(BreathingScreen), findsOneWidget);
  return h;
}

String phase(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('breathe-phase'))).data!;

String seconds(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('breathe-seconds'))).data!;

double circle(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('breathe-circle'))).width;

void main() {
  group('patterns', () {
    test('box: in, hold, out, hold, 4 seconds each', () {
      const p = BreathingPattern.box;
      expect(p.cycleSeconds, 16);
      var s = p.stepAt(Duration.zero);
      expect((s.phase, s.secondsLeft, s.breath), (BreathPhase.breatheIn, 4, 1));
      s = p.stepAt(const Duration(milliseconds: 3100));
      expect((s.phase, s.secondsLeft), (BreathPhase.breatheIn, 1));
      s = p.stepAt(const Duration(seconds: 4));
      expect((s.phase, s.secondsLeft), (BreathPhase.holdIn, 4));
      expect(s.fullness, 1);
      s = p.stepAt(const Duration(seconds: 8));
      expect(s.phase, BreathPhase.breatheOut);
      s = p.stepAt(const Duration(milliseconds: 15900));
      expect((s.phase, s.secondsLeft), (BreathPhase.holdOut, 1));
      expect(s.fullness, 0);
      s = p.stepAt(const Duration(seconds: 16));
      expect((s.phase, s.breath), (BreathPhase.breatheIn, 2));
    });

    test('slow and sleep breathing have no holds', () {
      var s = BreathingPattern.calm.stepAt(const Duration(seconds: 4));
      expect((s.phase, s.secondsLeft), (BreathPhase.breatheOut, 6));
      s = BreathingPattern.sleep.stepAt(const Duration(seconds: 10));
      expect((s.phase, s.secondsLeft), (BreathPhase.breatheOut, 1));
      s = BreathingPattern.sleep.stepAt(const Duration(seconds: 11));
      expect((s.phase, s.breath), (BreathPhase.breatheIn, 2));
    });

    test('the circle grows breathing in and shrinks breathing out', () {
      const p = BreathingPattern.calm;
      expect(p.stepAt(const Duration(seconds: 2)).fullness, closeTo(0.5, 1e-9));
      expect(p.stepAt(const Duration(seconds: 7)).fullness, closeTo(0.5, 1e-9));
    });

    test('whole breaths per length, at least one; no long holds', () {
      expect(BreathingPattern.box.cyclesFor(1), 3);
      expect(BreathingPattern.calm.cyclesFor(1), 6);
      expect(BreathingPattern.sleep.cyclesFor(2), 10);
      expect(BreathingPattern.box.cyclesFor(0), 1);
      for (final p in BreathingPattern.values) {
        expect(p.holdIn, lessThanOrEqualTo(4), reason: p.id);
        expect(p.holdOut, lessThanOrEqualTo(4), reason: p.id);
        expect(BreathingPattern.byId(p.id), p);
      }
      expect(BreathingPattern.byId('478'), isNull);
    });
  });

  group('the guide', () {
    testWidgets('pick a pattern and length, breathe along, pause, resume, '
        'and finish', (tester) async {
      await openGuide(tester);
      expect(find.byKey(const Key('breathe-safety')), findsOneWidget);
      await tester.tap(find.byKey(const Key('breathe-pattern-box')));
      await tester.tap(find.byKey(const Key('breathe-length-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('breathe-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(phase(tester), 'Breathe in');
      expect(seconds(tester), '4');
      expect(find.text('Breath 1 of 3'), findsOneWidget);
      expect(find.byKey(const Key('breathe-safety')), findsOneWidget);
      final small = circle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(circle(tester), greaterThan(small), reason: 'it fills');

      await tester.pump(const Duration(seconds: 1));
      expect(phase(tester), 'Hold');

      await tester.tap(find.byKey(const Key('breathe-pause')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(phase(tester), 'Hold', reason: 'paused');
      await tester.tap(find.byKey(const Key('breathe-resume')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(phase(tester), 'Breathe out');

      await tester.pump(const Duration(seconds: 45));
      await tester.pump();
      expect(find.byKey(const Key('breathe-done')), findsOneWidget);
      expect(
        find.text('You took 3 calm breaths. Notice how you feel now.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('breathe-again')));
      await tester.pump();
      expect(find.byKey(const Key('breathe-setup')), findsOneWidget);
    });

    testWidgets('a breathing session uses its pattern and length and saves '
        'progress', (tester) async {
      final h = await openGuide(
        tester,
        session: const Lesson(
          id: 's1',
          category: 'D',
          title: 'Wind down',
          readMinutes: 8,
          kind: LessonKind.audio,
          breathing: BreathingPattern.sleep,
        ),
      );
      expect(find.text('Wind down'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('breathe-length-8')),
      );
      expect(chip.selected, isTrue);
      await tester.tap(find.byKey(const Key('breathe-start')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 44));
      await tester.tap(find.byKey(const Key('breathe-pause')));
      await tester.pump();
      expect(h.learn.progress['s1']!.completed, isFalse);
      expect(h.learn.progress['s1']!.progress, closeTo(44 / (43 * 11), 0.01));
      await tester.tap(find.byKey(const Key('breathe-resume')));
      await tester.pump();
      await tester.pump(const Duration(minutes: 8));
      await tester.pump();
      expect(h.learn.progress['s1']!.completed, isTrue);
    });

    testWidgets('reduced motion: the circle stays still, the words guide', (
      tester,
    ) async {
      await openGuide(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('breathe-start')));
      await tester.pump();
      final size = circle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(circle(tester), size);
      await tester.pump(const Duration(seconds: 2));
      expect(phase(tester), 'Breathe out');
    });

    testWidgets('leaving mid-session is fine (nothing left running)', (
      tester,
    ) async {
      await openGuide(tester);
      await tester.tap(find.byKey(const Key('breathe-start')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BreathingScreen), findsNothing);
    });
  });

  group('accessibility (NFR-06)', () {
    testWidgets('labels, tap targets and contrast, set up and running', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openGuide(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.byKey(const Key('breathe-start')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.byKey(const Key('breathe-pause')));
      await tester.pump();
      handle.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('iPhone SE, text $scale: no overflow', (tester) async {
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openGuide(tester);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const Key('breathe-start')),
          200,
          scrollable: find.descendant(
            of: find.byKey(const Key('breathe-setup')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('breathe-start')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('breathe-pause')));
        await tester.pump();
      });
    }
  });
}
