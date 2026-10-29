import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart';
import 'package:livewell/features/care/presentation/care_screen.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/safety/presentation/help_now_screen.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;
import '../support/app_harness.dart';

/// A real account with the coach's chat and voice switched on (their
/// flags; Step 4d): every typed word is still safety-checked first.
Harness chatOn() =>
    signedIn(flags: const FeatureFlags(coachChat: true, coachVoice: true));

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
  group('coach chat switched on (flags): coach not answering yet', () {
    testWidgets('the illustrated Chat tab, no made-up answers', (tester) async {
      await chatOn().boot(tester);
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
      // The status pill shows only while the coach speaks (AI voice).
      expect(find.byKey(const Key('care-status')), findsNothing);
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

    // Phone bug: "Hold to talk" became "Tap to speak"; no "Coming soon".
    testWidgets('Tap to speak, with the voice flag, asks for nothing yet', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = chatOn();
      await h.boot(tester);
      await openCare(tester);
      await scrollTo(tester, find.byKey(const Key('care-talk')));
      expect(find.text('Hold to talk'), findsNothing);
      expect(find.text('Tap to speak'), findsOneWidget);
      expect(find.textContaining('oming soon'), findsNothing);
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
      await chatOn().boot(tester);
      await openCare(tester);
      await send(tester, 'How do I sleep better?');
      expect(find.text('How do I sleep better?'), findsOneWidget);
      expect(find.text(replySoon), findsOneWidget);
    });

    testWidgets('a quick prompt is asked the same way', (tester) async {
      await chatOn().boot(tester);
      await openCare(tester);
      await tester.tap(find.byKey(const Key('care-prompt-2')));
      await tester.pumpAndSettle();
      expect(find.text('Help me sleep better'), findsNWidgets(2));
      expect(find.text(replySoon), findsOneWidget);
    });

    testWidgets('crisis text: the crisis card first, dropped, coach calm', (
      tester,
    ) async {
      await chatOn().boot(tester);
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
      await chatOn().boot(tester);
      await openCare(tester);
      await send(tester, 'I have crushing chest pain');
      expect(find.text('This could be an emergency'), findsOneWidget);
    });

    testWidgets('medication question: the note, then it may continue', (
      tester,
    ) async {
      await chatOn().boot(tester);
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
      final h = chatOn();
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
        final h = chatOn();
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
      await chatOn().boot(tester);
      await openCare(tester);
      await openTab(tester, 'safety');
      expect(find.byKey(const Key('help-emergency-US')), findsOneWidget);
      expect(find.byKey(const Key('help-emergency-IN')), findsOneWidget);
    });

    testWidgets('Voice and Saved say kindly what is coming', (tester) async {
      await chatOn().boot(tester);
      await openCare(tester);
      await openTab(tester, 'voice');
      expect(find.text('Voice conversations are coming soon'), findsOneWidget);
      await openTab(tester, 'saved');
      expect(find.text('Nothing saved yet'), findsOneWidget);
      // Get help now stays on every tab (spec 14.2).
      expect(find.byKey(const Key('care-help-now')), findsOneWidget);
    });

    testWidgets('history: kind note until the coach is ready', (tester) async {
      await chatOn().boot(tester);
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
      final h = chatOn();
      h.learn.lessons = [
        const Lesson(
          id: 'a',
          category: 'Driver 4',
          title: 'Calm breathing',
          cards: ['Breathe slowly.'],
        ),
      ];
      await h.boot(tester);
      await openCare(tester);
      await scrollTo(tester, find.byKey(const Key('care-resource-a')));
      expect(find.text('Helpful resources'), findsOneWidget);
      expect(find.text('From Driver 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-resource-a')));
      await tester.pumpAndSettle();
      // It opens in the lesson reader (Step 4e).
      expect(find.text('Breathe slowly.'), findsOneWidget);
      expect(find.byKey(const Key('lesson-next')), findsOneWidget);
    });
  });

  group('prod today: the coach isn\'t built (Step 4d, D-56)', () {
    testWidgets('help, the coach, resources and contacts; no chat', (
      tester,
    ) async {
      final h = signedIn();
      h.profiles.regions['u1'] = 'IN';
      h.learn.lessons = [
        const Lesson(
          id: 'a',
          category: 'Driver 4',
          title: 'Calm breathing',
          cards: ['Breathe slowly.'],
        ),
      ];
      await h.boot(tester);
      await openCare(tester);
      expect(find.byKey(const Key('care-help-now')), findsOneWidget);
      expect(heroExpression(tester), AvatarExpression.calm);
      expect(
        find.text(
          "I'm here for you. Here are some things that can help right now.",
        ),
        findsOneWidget,
      );
      // Nothing that can't answer: no tabs, prompts, box, mic or history.
      for (final key in [
        'care-tab-chat',
        'care-tab-voice',
        'care-tab-saved',
        'care-input',
        'care-prompt-0',
        'care-talk',
        'care-history',
        'care-status',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      await scrollTo(tester, find.byKey(const Key('care-resource-a')));
      expect(find.text('Helpful resources'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('help-emergency-IN')));
      await tester.tap(find.byKey(const Key('help-emergency-IN')));
      await tester.pumpAndSettle();
      expect(h.phone.calls, ['112']);
      await scrollTo(tester, find.byKey(const Key('care-clinician')));
      await scrollTo(tester, find.byKey(const Key('care-disclaimer')));
      expect(find.textContaining('oming soon'), findsNothing);
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
          'care-talk',
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
