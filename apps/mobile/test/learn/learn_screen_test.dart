import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/domain/portal.dart';
import 'package:livewell/features/learn/presentation/learn_screen.dart';
import 'package:livewell/features/learn/presentation/learn_search_screen.dart';
import 'package:livewell/features/learn/presentation/library_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn, today;

Future<void> openLearn(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Learn'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(LearnScreen), findsOneWidget);
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

Future<void> filter(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(Key('learn-filter-$name')));
  await tester.pumpAndSettle();
}

Lesson lesson(int i, {LessonKind kind = LessonKind.lesson}) => Lesson(
  id: '${kind.name}$i',
  category: 'Driver $i',
  title: '${kind == LessonKind.audio ? 'Session' : 'Lesson'} $i',
  summary: 'About item $i',
  readMinutes: i + 1,
  kind: kind,
);

void main() {
  test('search matches every word, in any order, ignoring case', () {
    final all = [
      const Lesson(id: 'a', category: 'Sleep', title: 'Winding down'),
      const Lesson(
        id: 'b',
        category: 'Move',
        title: 'Walks',
        summary: 'A short walk after meals',
      ),
    ];
    expect(searchLessons(all, 'WALK meals').map((x) => x.id), ['b']);
    expect(searchLessons(all, 'sleep').map((x) => x.id), ['a']);
    expect(searchLessons(all, '  '), isEmpty);
    expect(searchLessons(all, 'yoga'), isEmpty);
  });

  test('every item gets lesson art, its own or a stable placeholder', () {
    const own = Lesson(
      id: 'x',
      category: '',
      title: '',
      art: 'lesson_move_body',
    );
    expect(own.artId, 'lesson_move_body');
    const none = Lesson(id: 'y', category: '', title: '');
    expect(none.artId, startsWith('lesson_'));
    expect(none.artId, none.artId);
  });

  group('real account (prod)', () {
    testWidgets('empty catalog: chips, empty state, no portal card', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openLearn(tester);
      expect(find.text('APPROVED KNOWLEDGE'), findsOneWidget);
      for (final f in ['all', 'lessons', 'audio', 'programs']) {
        expect(find.byKey(Key('learn-filter-$f')), findsOneWidget);
      }
      expect(find.byKey(const Key('portal-card')), findsNothing);
      expect(find.text('Lessons are on their way'), findsOneWidget);
      // No progress yet: no "Pick up where you left off".
      expect(find.byKey(const Key('learn-continue')), findsNothing);
    });

    testWidgets('an approved offer still shows no card while the safety '
        'check cannot be done (D-22) and the flag is off', (tester) async {
      final h = signedIn(createdAt: DateTime(2026, 9, 1));
      h.learn.offers = [
        const PortalOffer(
          id: 'o1',
          title: 'A course',
          url: 'https://portal.example/o1',
          offerType: 'course',
        ),
      ];
      await h.boot(tester);
      await openLearn(tester);
      expect(find.byKey(const Key('portal-card')), findsNothing);
      await filter(tester, 'programs');
      expect(find.byKey(const Key('portal-card')), findsNothing);
      expect(find.text('No programs right now'), findsOneWidget);
      expect(h.learn.events, isEmpty, reason: 'nothing logged either');
    });

    testWidgets('lessons: 4 featured, "See all" opens the rest', (
      tester,
    ) async {
      final h = signedIn();
      h.learn.lessons = [for (var i = 1; i <= 6; i++) lesson(i)];
      await h.boot(tester);
      await openLearn(tester);
      expect(find.text('Featured Lessons'), findsOneWidget);
      expect(find.text('Lesson 1'), findsOneWidget);
      await scrollTo(tester, find.text('Lesson 4'));
      expect(find.text('Lesson 5'), findsNothing);
      expect(find.text('3 min'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('learn-view-all')));
      await tester.tap(find.byKey(const Key('learn-view-all')));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Lesson 6'), 200);
      expect(find.text('Lesson 6'), findsOneWidget);
    });

    testWidgets('4 lessons or fewer: no "See all"', (tester) async {
      final h = signedIn();
      h.learn.lessons = [lesson(1), lesson(2)];
      await h.boot(tester);
      await openLearn(tester);
      expect(find.byKey(const Key('learn-view-all')), findsNothing);
    });

    testWidgets('chips: Lessons only lessons, Audio only sessions', (
      tester,
    ) async {
      final h = signedIn();
      h.learn.lessons = [
        lesson(1),
        lesson(2, kind: LessonKind.audio),
        lesson(3, kind: LessonKind.audio),
      ];
      await h.boot(tester);
      await openLearn(tester);
      await scrollTo(tester, find.text('Session 3'));
      expect(find.text('Popular Audio Sessions'), findsOneWidget);
      await filter(tester, 'lessons');
      expect(find.text('Lesson 1'), findsOneWidget);
      expect(find.text('Session 2'), findsNothing);
      await filter(tester, 'audio');
      expect(find.text('Lesson 1'), findsNothing);
      expect(find.text('Session 2'), findsOneWidget);
      expect(find.text('Session 3'), findsOneWidget);
      await filter(tester, 'all');
      expect(find.text('Lesson 1'), findsOneWidget);
    });

    testWidgets('no audio yet: Audio says so kindly', (tester) async {
      final h = signedIn();
      h.learn.lessons = [lesson(1)];
      await h.boot(tester);
      await openLearn(tester);
      expect(find.text('Popular Audio Sessions'), findsNothing);
      await filter(tester, 'audio');
      expect(
        find.text('Audio sessions will show here once they are reviewed.'),
        findsOneWidget,
      );
    });

    testWidgets('a lesson and a session open as "coming soon"', (tester) async {
      final h = signedIn();
      h.learn.lessons = [lesson(1), lesson(2, kind: LessonKind.audio)];
      await h.boot(tester);
      await openLearn(tester);
      await tester.tap(find.byKey(const Key('lesson-lesson1')));
      await tester.pumpAndSettle();
      expect(find.text('Lessons open here soon'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('audio-audio2-play')));
      await tester.tap(find.byKey(const Key('audio-audio2-play')));
      await tester.pumpAndSettle();
      expect(find.text('Audio sessions are coming soon'), findsOneWidget);
    });

    testWidgets('search finds lessons and sessions by title or topic', (
      tester,
    ) async {
      final h = signedIn();
      h.learn.lessons = [
        lesson(1),
        lesson(2, kind: LessonKind.audio),
        lesson(3),
      ];
      await h.boot(tester);
      await openLearn(tester);
      await tester.tap(find.byKey(const Key('learn-search')));
      await tester.pumpAndSettle();
      expect(find.byType(LearnSearchScreen), findsOneWidget);
      expect(find.text('Search by title or topic.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('learn-search-field')),
        'driver 2',
      );
      await tester.pumpAndSettle();
      expect(find.text('Session 2'), findsOneWidget);
      expect(find.text('Lesson 1'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('learn-search-field')),
        'yoga',
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing found for “yoga”.'), findsOneWidget);
    });
  });

  group('dev preview: sample content and portal card', () {
    testWidgets('pick up, featured, audio and the labelled portal card', (
      tester,
    ) async {
      await bootPreview(tester);
      await openLearn(tester);
      expect(find.text('Pick up where you left off'), findsOneWidget);
      expect(find.text('40% done'), findsOneWidget);
      expect(find.text('Microhabits vs. willpower'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('portal-card')));
      expect(find.text('FROM THE LIVE WELL PORTAL'), findsOneWidget);
      expect(find.text('Paid course'), findsOneWidget);
      final view = tester.getSize(find.byKey(const Key('portal-view')));
      final notNow = tester.getSize(find.byKey(const Key('portal-not-now')));
      expect(notNow, view, reason: 'Not now is as visible as View course');
      await scrollTo(tester, find.text('Wind down for sleep'));
      expect(find.text('Popular Audio Sessions'), findsOneWidget);
    });

    testWidgets('Programs shows the portal card only', (tester) async {
      await bootPreview(tester);
      await openLearn(tester);
      await filter(tester, 'programs');
      expect(find.byKey(const Key('portal-card')), findsOneWidget);
      expect(find.text('Featured Lessons'), findsNothing);
      expect(find.byKey(const Key('learn-continue')), findsNothing);
    });

    testWidgets('Not now hides it (14-day cooldown)', (tester) async {
      await bootPreview(tester);
      await openLearn(tester);
      await filter(tester, 'programs');
      await tester.tap(find.byKey(const Key('portal-not-now')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('portal-card')), findsNothing);
      expect(find.text('No programs right now'), findsOneWidget);
    });

    testWidgets('View course opens the portal with attribution ids only', (
      tester,
    ) async {
      final h = await bootPreview(tester);
      await openLearn(tester);
      await filter(tester, 'programs');
      await tester.tap(find.byKey(const Key('portal-view')));
      await tester.pumpAndSettle();
      final url = h.browser.opened.single;
      expect(url.host, 'example.com');
      expect(url.queryParameters.keys.toSet(), {
        'utm_source',
        'utm_medium',
        'utm_campaign',
        'utm_content',
        'lw_cid',
      });
      expect(url.queryParameters['utm_content'], 'sample-offer');
    });

    testWidgets('a gentle day shows no card, in All or Programs', (
      tester,
    ) async {
      await bootPreview(
        tester,
        checkIn: const CheckIn(date: today, mood: 1, gentleDay: true),
      );
      await openLearn(tester);
      expect(find.byKey(const Key('portal-card')), findsNothing);
      await filter(tester, 'programs');
      expect(find.byKey(const Key('portal-card')), findsNothing);
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
          await openLearn(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(find.byTooltip('Search lessons'), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              'Breathe and reset. Audio, 5 minutes, 40% done. Opens it.',
            ),
            findsOneWidget,
          );
          await scrollTo(tester, find.text('Wind down for sleep'));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(find.byTooltip('Play Deep breathing'), findsOneWidget);
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
        await openLearn(tester);
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.text('Wind down for sleep'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
