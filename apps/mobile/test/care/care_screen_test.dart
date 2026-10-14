import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/care/presentation/care_screen.dart';
import 'package:livewell/features/consent/domain/consent.dart';
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

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('care-input')), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('care-send')));
  await tester.pumpAndSettle();
}

const notSent =
    'Your coach isn’t available yet, so this message wasn’t sent. '
    'It stays on this screen only.';

void main() {
  group('real account (prod): coach not built', () {
    testWidgets('coming soon, no made-up answers, disclaimer, help link', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      expect(find.text('DIRECT SUPPORT'), findsOneWidget);
      expect(find.text('Talk to your coach'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Your coach is coming soon'), findsOneWidget);
      expect(find.text('AI voice'), findsNothing);
      expect(find.byKey(const Key('care-sources')), findsNothing);
      expect(
        find.text(
          'Educational companion · Does not prescribe or change medication',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-help-now')), findsOneWidget);
      expect(find.text('Hold to talk'), findsOneWidget);
    });

    testWidgets('typing works (FR-CNV-07); the message is not sent or saved', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await send(tester, 'How do I sleep better?');
      expect(find.text('How do I sleep better?'), findsOneWidget);
      expect(find.text(notSent), findsOneWidget);
    });

    testWidgets('crisis text shows the crisis card first, and is dropped', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await send(tester, 'I want to end my life');
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      await tapText(tester, 'Go back');
      expect(find.text('I want to end my life'), findsNothing);
      expect(find.text(notSent), findsNothing);
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
      expect(find.text(notSent), findsOneWidget);
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

    testWidgets('unknown region: both countries are shown', (tester) async {
      await signedIn().boot(tester);
      await openCare(tester);
      await tester.tap(find.byKey(const Key('care-help-now')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-emergency-US')), findsOneWidget);
      expect(find.byKey(const Key('help-emergency-IN')), findsOneWidget);
    });

    testWidgets('talk asks for the microphone consent; words fill the box', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openCare(tester);
      await tester.tap(find.byKey(const Key('care-talk')));
      await tester.pumpAndSettle();
      expect(find.text('Use your microphone?'), findsOneWidget);
      await tapText(tester, 'Allow');
      expect(h.consents.records.single.type, ConsentType.microphone);
      expect(find.text('Listening… let go to stop'), findsOneWidget);
      h.dictation.say('Tips for a calm evening');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('care-input')),
      );
      expect(field.controller!.text, 'Tips for a calm evening');
      expect(find.text('Hold to talk'), findsOneWidget);
    });

    testWidgets('holding the button listens until release', (tester) async {
      final h = signedIn();
      await h.consents.record(ConsentType.microphone, granted: true);
      await h.boot(tester);
      await openCare(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('care-talk'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(h.dictation.listening, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(h.dictation.listening, isFalse);
    });
  });

  group('dev preview: sample conversation', () {
    testWidgets('bubbles, Sources chip and the "AI voice" label', (
      tester,
    ) async {
      await bootPreview(tester);
      await openCare(tester);
      expect(
        find.text('Is walking after meals really useful?'),
        findsOneWidget,
      );
      expect(find.text('AI voice'), findsOneWidget);
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
          handle.dispose();
        },
      );
    }
  });
}
