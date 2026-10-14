import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/domain/portal.dart';
import 'package:livewell/features/learn/presentation/learn_screen.dart';
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

Lesson lesson(int i) => Lesson(
  id: 'l$i',
  category: 'Driver $i',
  title: 'Lesson $i',
  summary: 'About lesson $i',
  readMinutes: i + 1,
);

void main() {
  group('real account (prod)', () {
    testWidgets('empty catalog: no portal card, lessons empty state', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openLearn(tester);
      expect(find.text('APPROVED KNOWLEDGE'), findsOneWidget);
      expect(find.byKey(const Key('portal-card')), findsNothing);
      expect(find.text('Lessons are on their way'), findsOneWidget);
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
      expect(h.learn.events, isEmpty, reason: 'nothing logged either');
    });

    testWidgets(
      'lessons from the catalog: 3 shown, "View all" opens the rest',
      (tester) async {
        final h = signedIn();
        h.learn.lessons = [for (var i = 1; i <= 5; i++) lesson(i)];
        await h.boot(tester);
        await openLearn(tester);
        expect(find.text('Lesson 1'), findsOneWidget);
        expect(find.text('Lesson 3'), findsOneWidget);
        expect(find.text('Lesson 4'), findsNothing);
        expect(find.text('DRIVER 2'), findsOneWidget);
        expect(find.text('3-min read'), findsOneWidget);
        await tester.tap(find.byKey(const Key('learn-view-all')));
        await tester.pumpAndSettle();
        expect(find.byType(LibraryScreen), findsOneWidget);
        expect(find.text('Lesson 5'), findsOneWidget);
      },
    );

    testWidgets('3 lessons or fewer: no "View all"', (tester) async {
      final h = signedIn();
      h.learn.lessons = [lesson(1), lesson(2)];
      await h.boot(tester);
      await openLearn(tester);
      expect(find.byKey(const Key('learn-view-all')), findsNothing);
    });
  });

  group('dev preview: sample portal card', () {
    testWidgets('labelled, paid, with View course and an equal Not now', (
      tester,
    ) async {
      await bootPreview(tester);
      await openLearn(tester);
      expect(find.text('FROM THE LIVE WELL PORTAL'), findsOneWidget);
      expect(find.text('Paid course'), findsOneWidget);
      final view = tester.getSize(find.byKey(const Key('portal-view')));
      final notNow = tester.getSize(find.byKey(const Key('portal-not-now')));
      expect(notNow, view, reason: 'Not now is as visible as View course');
    });

    testWidgets('Not now hides it (14-day cooldown)', (tester) async {
      await bootPreview(tester);
      await openLearn(tester);
      await tester.tap(find.byKey(const Key('portal-not-now')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('portal-card')), findsNothing);
    });

    testWidgets('View course opens the portal with attribution ids only', (
      tester,
    ) async {
      final h = await bootPreview(tester);
      await openLearn(tester);
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

    testWidgets('a gentle day shows no card', (tester) async {
      await bootPreview(
        tester,
        checkIn: const CheckIn(date: today, mood: 1, gentleDay: true),
      );
      await openLearn(tester);
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
          handle.dispose();
        },
      );
    }
  });
}
