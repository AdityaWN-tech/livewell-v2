import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/focus/presentation/onboarding_checkin_screen.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';

Harness atWhy({String? region}) {
  final h = Harness(
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
  );
  h.profiles.existing[uid] = ProfileStep.why;
  if (region != null) h.profiles.regions[uid] = region;
  return h;
}

Future<void> saveWhy(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('why')), text);
  await tester.pump();
  await tapText(tester, 'Save my Why');
}

void main() {
  testWidgets('crisis in India: Tele-MANAS and 112, nothing saved', (
    tester,
  ) async {
    final h = atWhy(region: 'IN');
    await h.boot(tester);
    await saveWhy(tester, "I don't want to be alive anymore");

    expect(find.byType(SafetyInterruptScreen), findsOneWidget);
    expect(find.text("You don't have to face this alone"), findsOneWidget);
    expect(find.text('Call Tele-MANAS: 14416'), findsOneWidget);
    expect(find.textContaining('988'), findsNothing);

    await tapText(tester, 'Call Tele-MANAS: 14416');
    expect(h.phone.calls, ['14416']);
    await tapText(tester, 'Call 112');
    expect(h.phone.calls, ['14416', '112']);

    await tapText(tester, 'Go back');
    expect(find.byType(WhyScreen), findsOneWidget);
    expect(h.profiles.whys, isEmpty, reason: 'red-flag text is not saved');
  });

  testWidgets('crisis in the US: call or text 988', (tester) async {
    final h = atWhy(region: 'US');
    await h.boot(tester);
    await saveWhy(tester, 'I want to kill myself');
    await tapText(tester, 'Call 988 Suicide & Crisis Lifeline: 988');
    await tapText(tester, 'Text 988');
    expect(h.phone.calls, ['988']);
    expect(h.phone.texts, ['988']);
    expect(find.textContaining('14416'), findsNothing);
  });

  testWidgets('emergency with unknown region shows both numbers, labelled', (
    tester,
  ) async {
    final h = atWhy();
    await h.boot(tester);
    await saveWhy(tester, 'I have crushing chest pain');
    expect(find.text('This could be an emergency'), findsOneWidget);
    expect(find.text('Call 911 in the US'), findsOneWidget);
    expect(find.text('Call 112 in India'), findsOneWidget);
    await tapText(tester, 'Call 911 in the US');
    expect(h.phone.calls, ['911']);
    expect(h.profiles.whys, isEmpty);
  });

  testWidgets('disordered eating: supportive note, no way to save it', (
    tester,
  ) async {
    final h = atWhy();
    await h.boot(tester);
    await saveWhy(tester, 'Eat 500 calories a day to lose weight fast');
    expect(find.byType(SafetyNoticeSheet), findsOneWidget);
    expect(find.text("Let's take care of you first"), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Save my Why'),
      findsOneWidget,
      reason: 'only the Why screen button behind the sheet',
    );
    await tapText(tester, 'Change it');
    expect(find.byType(WhyScreen), findsOneWidget);
    expect(h.profiles.whys, isEmpty);
  });

  testWidgets('medication: a note, then the user may still save', (
    tester,
  ) async {
    final h = atWhy();
    await h.boot(tester);
    await saveWhy(tester, 'I want to come off my diabetes medicines one day');
    expect(
      find.text('Medicine changes are for you and your prescriber'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SafetyNoticeSheet),
        matching: find.text('Save my Why'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingCheckInScreen), findsOneWidget);
    expect(
      h.profiles.whys[uid],
      'I want to come off my diabetes medicines one day',
    );
  });

  testWidgets('an ordinary Why saves with no safety screens', (tester) async {
    final h = atWhy();
    await h.boot(tester);
    await saveWhy(tester, 'I want to stay active for my grandchildren.');
    expect(find.byType(SafetyInterruptScreen), findsNothing);
    expect(find.byType(SafetyNoticeSheet), findsNothing);
    expect(find.byType(OnboardingCheckInScreen), findsOneWidget);
  });
}
