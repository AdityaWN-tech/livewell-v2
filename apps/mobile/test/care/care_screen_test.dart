import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart';
import 'package:livewell/features/care/presentation/care_screen.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/safety/presentation/help_now_screen.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;
import '../support/app_harness.dart';

Future<void> openCare(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Care'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(CareScreen), findsOneWidget);
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

Future<void> send(WidgetTester tester, String text) async {
  await scrollTo(tester, find.byKey(const Key('care-input')));
  await tester.enterText(find.byKey(const Key('care-input')), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('care-send')));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.byKey(Key('care-tab-$tab')));
  await tester.pumpAndSettle();
}

const replySoon =
    'Your coach is coming soon, so there’s no answer yet. '
    'Your message stays on this screen only.';

AvatarExpression heroExpression(WidgetTester tester) => tester
    .widget<CoachAvatar>(
      find.descendant(
        of: find.byKey(const Key('care-hero')),
        matching: find.byType(CoachAvatar),
      ),
    )
    .expression;

void main() {
  group('real account (prod): coach not built', () {
    testWidgets('the illustrated Chat tab, no made-up answers', (tester) async {
      await signedIn().boot(tester);
      await openCare(tester);
      expect(find.text('DIRECT SUPPORT'), findsOneWidget);
      for (final tab in ['chat', 'voice', 'saved', 'safety']) {
        expect(find.byKey(Key('care-tab-$tab')), findsOneWidget);
      }
      expect(
        find.text('I’m here for you. What would you like to talk about today?'),
        findsOneWidget,
      );
      expect(heroExpression(tester), AvatarExpression.listening);
      expect(find.text('I feel stressed'), findsOneWidget);
      expect(find.text('Plan my day'), findsOneWidget);
      expect(find.byKey(const Key('care-status')), findsOneWidget);
      expect(find.text('AI voice'), findsNothing);
      expect(find.byKey(const Key('care-sources')), findsNothing);
      expect(find.byKey(const Key('care-help-now')), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('care-disclaimer')));
      expect(
        find.text(
          'Educational companion · Does not prescribe or change medication',
        ),
        findsOneWidget,
      );
      // No approved lessons: no resources section.
      expect(find.text('Helpful resources'), findsNothing);
    });

    // Phone bug: "Hold to talk" is "Coming soon" until the coach is built.
    testWidgets('Tap to speak says "Coming soon" and does nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = signedIn();
      await h.boot(tester);
      await openCare(tester);
      await scrollTo(tester, find.byKey(const Key('care-talk-soon')));
      expect(find.text('Hold to talk'), findsNothing);
      expect(find.text('Tap to speak'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Talking to your coach is coming soon'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('care-talk')));
      await tester.pumpAndSettle();
      expect(find.text('Use your microphone?'), findsNothing);
      expect(h.dictation.listening, isFalse);
      expect(h.consents.records, isEmpty);
      handle.dispose();
    });

    testWidgets('typing works (FR-CNV-07); "coming soon", nothing sent', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await send(tester, 'How do I sleep better?');
      expect(find.text('How do I sleep better?'), findsOneWidget);
      expect(find.text(replySoon), findsOneWidget);
    });

    testWidgets('a quick prompt is asked the same way', (tester) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await tester.tap(find.byKey(const Key('care-prompt-2')));
      await tester.pumpAndSettle();
      expect(find.text('Help me sleep better'), findsNWidgets(2));
      expect(find.text(replySoon), findsOneWidget);
    });

    testWidgets('crisis text: the crisis card first, dropped, coach calm', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await send(tester, 'I want to end my life');
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      await tapText(tester, 'Go back');
      expect(find.text('I want to end my life'), findsNothing);
      expect(find.text(replySoon), findsNothing);
      await scrollTo(tester, find.byKey(const Key('care-hero')));
      expect(heroExpression(tester), AvatarExpression.calm);
      expect(
        find.text('I’m glad you told me. Your safety comes first.'),
        findsOneWidget,
      );
    });

    testWidgets('emergency text shows the emergency card', (tester) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await send(tester, 'I have crushing chest pain');
      expect(find.text('This could be an emergency'), findsOneWidget);
    });

    testWidgets('medication question: the note, then it may continue', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await send(tester, 'Should I stop my metformin?');
      expect(find.byType(SafetyNoticeSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SafetyNoticeSheet),
          matching: find.text('Send'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(replySoon), findsOneWidget);
    });

    testWidgets('Get help now: region numbers with one-tap calls', (
      tester,
    ) async {
      final h = signedIn();
      h.profiles.regions['u1'] = 'US';
      await h.boot(tester);
      await openCare(tester);
      await tester.tap(find.byKey(const Key('care-help-now')));
      await tester.pumpAndSettle();
      expect(find.byType(HelpNowScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('help-emergency-US')));
      await tester.pumpAndSettle();
      expect(h.phone.calls, ['911']);
      await tester.tap(find.byKey(const Key('help-support-US')));
      await tester.pumpAndSettle();
      expect(h.phone.calls.last, '988');
    });

    testWidgets(
      'Safety tab: region numbers, a clinician note, still dialable',
      (tester) async {
        final h = signedIn();
        h.profiles.regions['u1'] = 'IN';
        await h.boot(tester);
        await openCare(tester);
        await openTab(tester, 'safety');
        expect(find.byKey(const Key('care-safety')), findsOneWidget);
        expect(find.byKey(const Key('help-emergency-US')), findsNothing);
        await tester.tap(find.byKey(const Key('help-emergency-IN')));
        await tester.pumpAndSettle();
        expect(h.phone.calls, ['112']);
        await scrollTo(tester, find.text('Talk to a clinician'));
        expect(find.text('Talk to a clinician'), findsOneWidget);
      },
    );

    testWidgets('unknown region: both countries, never guessed', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await openTab(tester, 'safety');
      expect(find.byKey(const Key('help-emergency-US')), findsOneWidget);
      expect(find.byKey(const Key('help-emergency-IN')), findsOneWidget);
    });

    testWidgets('Voice and Saved say kindly what is coming', (tester) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await openTab(tester, 'voice');
      expect(find.text('Voice conversations are coming soon'), findsOneWidget);
      await openTab(tester, 'saved');
      expect(find.text('Nothing saved yet'), findsOneWidget);
      // Get help now stays on every tab (spec 14.2).
      expect(find.byKey(const Key('care-help-now')), findsOneWidget);
    });

    testWidgets('history: kind note until the coach is ready', (tester) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await tester.tap(find.byKey(const Key('care-history')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your conversations will show here once your coach is ready.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('approved lessons show as helpful resources', (tester) async {
      final h = signedIn();
      h.learn.lessons = [
        const Lesson(id: 'a', category: 'Driver 4', title: 'Calm breathing'),
      ];
      await h.boot(tester);
      await openCare(tester);
      await scrollTo(tester, find.byKey(const Key('care-resource-a')));
      expect(find.text('Helpful resources'), findsOneWidget);
      expect(find.text('From Driver 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-resource-a')));
      await tester.pumpAndSettle();
      expect(find.text('Lessons open here soon'), findsOneWidget);
    });
  });

  group('dev preview: sample conversation', () {
    testWidgets('bubbles, Sources chip and the "AI voice" label', (
      tester,
    ) async {
      await bootPreview(tester);
      await openCare(tester);
      expect(find.text('AI voice'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('care-sources')));
      expect(
        find.text('Is walking after meals really useful?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('care-sources')));
      await tester.pumpAndSettle();
      expect(find.text('Where this comes from'), findsOneWidget);
      expect(find.text('• Book, chapter 2'), findsOneWidget);
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
          await openCare(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(
            find.bySemanticsLabel('Your coach speaks with an AI voice'),
            findsOneWidget,
          );
          expect(find.byTooltip('Your conversations'), findsOneWidget);
          await scrollTo(tester, find.byKey(const Key('care-input')));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }

    // Phone bug: everything scrolls, so no text hides behind the message
    // box, on a small phone at every text size.
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('iPhone SE, text $scale: the message box scrolls with the '
          'page and nothing is hidden behind it', (tester) async {
        await bootPreview(tester);
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openCare(tester);
        expect(tester.takeException(), isNull);
        final nav = tester.getRect(find.byType(NavigationBar)).top;
        for (final key in [
          'care-hero',
          'care-prompt-3',
          'care-talk-soon',
          'care-input',
          'care-disclaimer',
        ]) {
          await scrollTo(tester, find.byKey(Key(key)));
          final r = tester.getRect(find.byKey(Key(key)));
          expect(r.bottom, lessThanOrEqualTo(nav + 0.5), reason: key);
          expect(tester.takeException(), isNull, reason: key);
        }
        // The box is part of the scrolling page, not pinned over it.
        expect(
          find.descendant(
            of: find.byType(Scrollable).first,
            matching: find.byKey(const Key('care-input')),
          ),
          findsOneWidget,
        );
      });
    }
  });
}
