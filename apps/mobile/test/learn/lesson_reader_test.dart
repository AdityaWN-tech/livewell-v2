import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/presentation/learn_screen.dart';
import 'package:livewell/features/learn/presentation/lesson_reader_screen.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../support/app_harness.dart';
import 'learn_screen_test.dart' show openLearn;

const _lesson = Lesson(
  id: 'l1',
  category: 'Driver 1',
  title: 'Microhabits',
  summary: 'Why small steps work.',
  readMinutes: 3,
  version: 2,
  cards: ['Small habits need less willpower.', 'Start with 2 minutes.'],
  microhabit: LessonMicrohabit(title: 'Walk for 2 minutes', minutes: 2),
);

Future<Harness> openReader(
  WidgetTester tester, {
  Lesson lesson = _lesson,
}) async {
  final h = signedIn();
  h.learn.lessons = [lesson];
  await h.boot(tester);
  await openLearn(tester);
  await tester.tap(find.byKey(Key('lesson-${lesson.id}')));
  await tester.pumpAndSettle();
  expect(find.byType(LessonReaderScreen), findsOneWidget);
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cards one at a time, then the microhabit; Finish saves it '
      'as done and goes back to Learn', (tester) async {
    final h = await openReader(tester);
    expect(find.text('Microhabits'), findsOneWidget);
    expect(find.text('Small habits need less willpower.'), findsOneWidget);
    expect(find.text('Card 1 of 2'), findsOneWidget);
    expect(find.byKey(const Key('lesson-back')), findsNothing);

    await tapKey(tester, 'lesson-next');
    expect(find.text('Start with 2 minutes.'), findsOneWidget);
    expect(find.text('Card 2 of 2'), findsOneWidget);
    expect(h.learn.progress['l1']!.progress, closeTo(2 / 3, 0.001));
    expect(h.learn.progress['l1']!.completed, isFalse);

    await tapKey(tester, 'lesson-back');
    expect(find.text('Card 1 of 2'), findsOneWidget);
    await tapKey(tester, 'lesson-next');
    await tapKey(tester, 'lesson-next');
    expect(find.byKey(const Key('lesson-microhabit')), findsOneWidget);
    expect(find.text('TRY THIS TODAY'), findsOneWidget);
    expect(find.text('Walk for 2 minutes'), findsOneWidget);
    expect(find.text('2 min'), findsOneWidget);

    await tapKey(tester, 'lesson-finish');
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(h.learn.progress['l1']!.completed, isTrue);
    expect(find.byKey(const Key('learn-continue')), findsNothing);
  });

  testWidgets('swiping moves between cards too', (tester) async {
    await openReader(tester);
    await tester.fling(
      find.byKey(const Key('lesson-pages')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Card 2 of 2'), findsOneWidget);
  });

  testWidgets('a lesson without a microhabit ends with a short well done', (
    tester,
  ) async {
    await openReader(
      tester,
      lesson: const Lesson(
        id: 'l2',
        category: 'D',
        title: 'Short',
        cards: ['Only card.'],
      ),
    );
    await tapKey(tester, 'lesson-next');
    expect(find.text("That's the lesson"), findsOneWidget);
    expect(find.byKey(const Key('lesson-microhabit')), findsNothing);
  });

  group('Listen (FR-LRN-02)', () {
    testWidgets('the coach reads each approved card with its own message '
        'id, shows the AI voice label and a progress bar, and moves on', (
      tester,
    ) async {
      final h = await openReader(tester);
      expect(find.byKey(const Key('ai-voice-label')), findsNothing);
      await tapKey(tester, 'lesson-listen');
      final (first, _) = h.speaker.spoken.single;
      expect(first.messageId, 'lesson.l1.c1@v2');
      expect(first.moment, Moment.lesson);
      expect(first.text, 'Small habits need less willpower.');
      expect(first.approved, isTrue);
      expect(first.containsUserText, isFalse);
      expect(find.byKey(const Key('ai-voice-label')), findsOneWidget);
      expect(find.byTooltip('Stop listening'), findsOneWidget);

      h.speaker.word(10);
      await tester.pump();
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('lesson-listening')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, closeTo(10 / first.text.length, 0.001));

      h.speaker.finish();
      await tester.pumpAndSettle();
      expect(find.text('Card 2 of 2'), findsOneWidget);
      expect(h.speaker.spoken.last.$1.messageId, 'lesson.l1.c2@v2');

      h.speaker.finish();
      await tester.pumpAndSettle();
      expect(h.speaker.spoken.last.$1.messageId, 'lesson.l1.habit@v2');
      expect(h.speaker.spoken.last.$1.text, 'Walk for 2 minutes');

      h.speaker.finish();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-voice-label')), findsNothing);
      expect(h.speaker.spoken, hasLength(3));
    });

    testWidgets('Stop listening stops the voice', (tester) async {
      final h = await openReader(tester);
      await tapKey(tester, 'lesson-listen');
      await tapKey(tester, 'lesson-listen');
      expect(h.speaker.stops, greaterThan(0));
      expect(find.byKey(const Key('ai-voice-label')), findsNothing);
      h.speaker.finish();
      await tester.pumpAndSettle();
      expect(find.text('Card 1 of 2'), findsOneWidget, reason: 'stays put');
    });

    testWidgets('when the phone cannot speak, it says so and the lesson '
        'stays readable', (tester) async {
      final h = await openReader(tester);
      h.speaker.works = false;
      await tapKey(tester, 'lesson-listen');
      expect(
        find.text(
          "Listening isn't working on this phone right now. You can read the "
          'lesson instead.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-voice-label')), findsNothing);
      expect(find.text('Small habits need less willpower.'), findsOneWidget);
    });
  });

  testWidgets('an item that is gone says so and leads back to Learn', (
    tester,
  ) async {
    await signedIn().boot(tester);
    await openLearn(tester);
    GoRouter.of(tester.element(find.byType(LearnScreen)))
        .go(LearnItemScreen.pathFor('nope'));
    await tester.pumpAndSettle();
    expect(find.text("This lesson isn't here right now"), findsOneWidget);
    await tester.tap(find.text('Back to Learn'));
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
  });

  group('accessibility (NFR-06)', () {
    testWidgets('labels, tap targets and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await openReader(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(find.byTooltip('Listen'), findsOneWidget);
      handle.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('iPhone SE, text $scale: no overflow', (tester) async {
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openReader(tester);
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'lesson-next');
        await tapKey(tester, 'lesson-next');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
