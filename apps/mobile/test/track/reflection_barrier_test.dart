import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/home/application/home_data.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/application/moment_context.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';
import 'package:livewell/features/track/domain/track_models.dart';

import '../home/home_screen_test.dart'
    show expectActionLimit, scrollHomeTo, signedIn, today;
import 'track_screen_test.dart' show openReflection;

/// T-DLY-05, D-119: "What got in the way?" in the evening reflection, and
/// tomorrow's step reflects it (FR-DLY-05) by a fixed rule, with no AI.
const yesterday = '2026-10-13';

const step = PlanDay(
  date: today,
  dayNumber: 2,
  focus: FocusArea.moveMore,
  title: '10-min walk after lunch',
  reason: 'A short walk helps.',
  anchor: 'after lunch',
  minutes: 10,
  smallerTitle: '5-min walk after lunch',
  smallerMinutes: 5,
  gentle: false,
);

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('reflection-save')));
  await tester.tap(find.byKey(const Key('reflection-save')));
  await tester.pumpAndSettle();
}

void main() {
  test('barrier ids round-trip; anything else is no barrier', () {
    for (final b in ReflectionBarrier.values) {
      expect(ReflectionBarrier.fromId(b.id), b);
    }
    expect(ReflectionBarrier.fromId('my boss'), isNull);
    expect(ReflectionBarrier.fromId(null), isNull);
  });

  group('the reflection card', () {
    testWidgets('a barrier alone can be saved; analytics never gets it', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      Finder save() => find.byKey(const Key('reflection-save'));
      expect(tester.widget<FilledButton>(save()).onPressed, isNull);

      await tester.ensureVisible(find.byKey(const Key('barrier-tired')));
      await tester.tap(find.byKey(const Key('barrier-tired')));
      await tester.pump();
      expect(tester.widget<FilledButton>(save()).onPressed, isNotNull);
      await tapSave(tester);

      final saved = h.reflections.days[today]!;
      expect(saved.barrier, ReflectionBarrier.tired);
      expect(saved.text, isEmpty);
      expect(
        find.text("Saved. Tomorrow's step will be a smaller one."),
        findsOneWidget,
      );
      expect(h.analytics.events.single, {
        'name': 'reflection_submitted',
        'mode': 'text',
      });
    });

    testWidgets('text and a barrier together; tapping again unselects', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openReflection(tester);
      await tester.enterText(
        find.byKey(const Key('reflection-field')),
        'Walked in the morning',
      );
      final noTime = find.byKey(const Key('barrier-no_time'));
      await tester.ensureVisible(noTime);
      await tester.tap(noTime);
      await tester.pump();
      await tester.tap(find.byKey(const Key('barrier-forgot')));
      await tester.pump();
      expect(tester.widget<ChoiceChip>(noTime).selected, isFalse);
      await tapSave(tester);
      expect(h.reflections.days[today]!.text, 'Walked in the morning');
      expect(h.reflections.days[today]!.barrier, ReflectionBarrier.forgot);

      // Unselect it and save again: no barrier any more.
      await tester.tap(find.byKey(const Key('barrier-forgot')));
      await tester.pump();
      await tapSave(tester);
      expect(h.reflections.days[today]!.barrier, isNull);
      expect(find.text('Saved. Thanks for taking a moment.'), findsOneWidget);
    });

    testWidgets("today's saved barrier shows as selected", (tester) async {
      final h = signedIn();
      h.reflections.days[today] = const Reflection(
        date: today,
        barrier: ReflectionBarrier.plansChanged,
      );
      await h.boot(tester);
      await openReflection(tester);
      final chip = find.byKey(const Key('barrier-plans_changed'));
      await tester.ensureVisible(chip);
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      expect(find.byKey(const Key('reflection-saved')), findsOneWidget);
    });
  });

  group("tomorrow's step (FR-DLY-05)", () {
    for (final barrier in ReflectionBarrier.values) {
      testWidgets('after "${barrier.id}": the smaller step, with why', (
        tester,
      ) async {
        final h = signedIn();
        h.plans.days[today] = step;
        h.reflections.days[yesterday] = Reflection(
          date: yesterday,
          barrier: barrier,
        );
        await h.boot(tester);
        await tester.pumpAndSettle();
        await scrollHomeTo(tester, find.byKey(const Key('step-open')));
        expect(find.text('5-min walk after lunch'), findsOneWidget);
        expect(
          find.text("A smaller step today, after last night's reflection."),
          findsOneWidget,
        );
        expectActionLimit();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        expect(container.read(stepProgressProvider).afterBarrier, barrier);
        // The coach names the same smaller step.
        expect(
          container.read(momentContextProvider).step?.title,
          '5-min walk after lunch',
        );
      });
    }

    testWidgets('no barrier (or only text): the planned step', (tester) async {
      final h = signedIn();
      h.plans.days[today] = step;
      h.reflections.days[yesterday] = const Reflection(
        date: yesterday,
        text: 'A good day',
      );
      await h.boot(tester);
      await tester.pumpAndSettle();
      await scrollHomeTo(tester, find.byKey(const Key('step-open')));
      expect(find.text('10-min walk after lunch'), findsOneWidget);
      expect(find.text('A short walk helps.'), findsOneWidget);
    });

    testWidgets("a barrier two days ago doesn't count", (tester) async {
      final h = signedIn();
      h.plans.days[today] = step;
      h.reflections.days['2026-10-12'] = const Reflection(
        date: '2026-10-12',
        barrier: ReflectionBarrier.noTime,
      );
      await h.boot(tester);
      await tester.pumpAndSettle();
      await scrollHomeTo(tester, find.byKey(const Key('step-open')));
      expect(find.text('10-min walk after lunch'), findsOneWidget);
    });
  });
}
