import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'phone:+919876543210';

/// Signed in, account created, onboarding at the Why step.
Harness atWhy() {
  final h = Harness(
    auth: FakeAuthService(
      signedIn: const AuthUser(uid: uid, phoneNumber: '+919876543210'),
    ),
  );
  h.profiles.existing[uid] = ProfileStep.why;
  return h;
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  test('profile steps route to the right screen (FR-ONB-06)', () {
    expect(routeForProfileStep(ProfileStep.why), '/onboarding/why');
    expect(routeForProfileStep(ProfileStep.assessment), '/home');
    expect(routeForProfileStep(null), '/home');
  });

  testWidgets('reopening the app at the Why step opens the Why screen', (
    tester,
  ) async {
    await atWhy().boot(tester);
    expect(find.byType(WhyScreen), findsOneWidget);
  });

  testWidgets('type a Why, save it, and see it on Home (FR-ONB-05)', (
    tester,
  ) async {
    final h = atWhy();
    await h.boot(tester);
    expect(saveButton(tester).onPressed, isNull, reason: 'empty');

    await tester.enterText(find.byKey(const Key('why')), 'hi');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull, reason: 'too short');

    await tester.enterText(
      find.byKey(const Key('why')),
      '  Energy to play cricket with my son.  ',
    );
    await tester.pump();
    await tapText(tester, 'Save my Why');

    expect(h.profiles.whys[uid], 'Energy to play cricket with my son.');
    expect(h.profiles.existing[uid], ProfileStep.assessment);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('YOUR WHY'), findsOneWidget);
    expect(find.text('Energy to play cricket with my son.'), findsOneWidget);
  });

  testWidgets('a suggestion fills the box and can be edited', (tester) async {
    final h = atWhy();
    await h.boot(tester);
    await tapText(tester, 'I want energy to travel with my family.');
    final field = tester.widget<TextField>(find.byKey(const Key('why')));
    expect(field.controller!.text, 'I want energy to travel with my family.');
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('the Why is limited to 200 characters', (tester) async {
    await atWhy().boot(tester);
    await tester.enterText(find.byKey(const Key('why')), 'x' * 250);
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('why')));
    expect(field.controller!.text.length, WhyScreen.maxLength);
  });

  group('voice typing', () {
    testWidgets(
      'asks for the microphone consent first; "Not now" changes nothing',
      (tester) async {
        final h = atWhy();
        await h.boot(tester);
        await tapText(tester, 'Speak instead');
        expect(find.text('Use your microphone?'), findsOneWidget);
        await tapText(tester, 'Not now');
        expect(h.dictation.listening, isFalse);
        expect(h.consents.records, isEmpty);
      },
    );

    testWidgets('"Allow" records the consent, then spoken words fill the box', (
      tester,
    ) async {
      final h = atWhy();
      await h.boot(tester);
      await tapText(tester, 'Speak instead');
      await tapText(tester, 'Allow');
      expect(h.consents.records.single.type, ConsentType.microphone);
      expect(h.consents.records.single.granted, isTrue);
      expect(h.dictation.listening, isTrue);
      expect(find.text('Listening. Tap to stop.'), findsOneWidget);

      h.dictation.say('I want to sleep better');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const Key('why')));
      expect(field.controller!.text, 'I want to sleep better');
      expect(find.text('Speak instead'), findsOneWidget);
    });

    testWidgets('with the consent already given, no question is asked', (
      tester,
    ) async {
      final h = atWhy();
      await h.consents.record(ConsentType.microphone, granted: true);
      await h.boot(tester);
      await tapText(tester, 'Speak instead');
      expect(find.text('Use your microphone?'), findsNothing);
      expect(h.dictation.listening, isTrue);
    });

    testWidgets('unavailable on this phone: says so, typing still works', (
      tester,
    ) async {
      final h = atWhy()..dictation.available = false;
      await h.consents.record(ConsentType.microphone, granted: true);
      await h.boot(tester);
      await tapText(tester, 'Speak instead');
      expect(
        find.text(
          "Voice typing isn't available on this phone. You can type instead.",
        ),
        findsOneWidget,
      );
    });
  });
}
