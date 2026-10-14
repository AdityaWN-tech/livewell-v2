import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/auth/presentation/phone_sign_in_screen.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:livewell/features/onboarding/presentation/about_screen.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';

import '../support/app_harness.dart';
import '../support/fake_onboarding_store.dart';
import '../support/frames.dart';

/// Onboarding already finished up to sign-in.
FakeOnboardingStore readyStore() {
  final at = DateTime.utc(2026, 10, 13);
  return FakeOnboardingStore(
    OnboardingProgress(
      step: OnboardingStep.signIn,
      adultConfirmedAt: at,
      legalAcceptedAt: {for (final t in legalDocuments) t: at},
    ),
  );
}

void main() {
  testWidgets('sign-in offers phone, email and Google (Apple only on iPhone)', (
    tester,
  ) async {
    await Harness(store: readyStore()).boot(tester);
    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing); // Android test host
  });

  testWidgets('phone: India number, code, then the account is set up', (
    tester,
  ) async {
    final h = Harness(store: readyStore());
    await h.boot(tester);
    await tapText(tester, 'Continue with phone');
    await tapText(tester, 'India (+91)');

    await tester.enterText(find.byKey(const Key('phone')), '12345');
    await tapText(tester, 'Send code');
    expect(
      find.text('Enter a valid mobile number for this country.'),
      findsOneWidget,
    );
    expect(h.auth.codesSent, 0);

    await tester.enterText(find.byKey(const Key('phone')), '98765 43210');
    await tapText(tester, 'Send code');
    expect(
      find.text('We sent a 6-digit code to +919876543210.'),
      findsOneWidget,
    );
    expect(find.text('Resend code in 30 s'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), '000000');
    await tapText(tester, 'Verify');
    expect(
      find.text("That code isn't right. Check the text message and try again."),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tapText(tester, 'Verify');
    expect(find.byType(WhyScreen), findsOneWidget);

    const uid = 'phone:+919876543210';
    expect(h.profiles.created[uid]!.region, 'IN');
    expect(h.consents.records.map((r) => r.type), legalDocuments);
    expect(h.store.saved, isNull, reason: 'on-device progress cleared');
  });

  testWidgets('phone: resend unlocks after the countdown', (tester) async {
    final h = Harness(store: readyStore());
    await h.boot(tester);
    await tapText(tester, 'Continue with phone');
    await tapText(tester, 'India (+91)');
    await tester.enterText(find.byKey(const Key('phone')), '9876543210');
    await tapText(tester, 'Send code');
    await pumpFrames(tester, PhoneSignInScreen.resendDelay);
    await tester.pumpAndSettle();
    await tapText(tester, 'Resend code');
    expect(h.auth.codesSent, 2);
  });

  testWidgets('email: create an account, with validation', (tester) async {
    final h = Harness(store: readyStore());
    await h.boot(tester);
    await tapText(tester, 'Continue with email');
    await tapText(tester, 'Create account');

    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('password')), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email')), 'priya@example.com');
    await tester.enterText(
      find.byKey(const Key('password')),
      'walk-after-lunch',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(WhyScreen), findsOneWidget);
    expect(
      h.profiles.created['email:priya@example.com']!.email,
      'priya@example.com',
    );
  });

  testWidgets('email: wrong password shows a helpful message', (tester) async {
    final h = Harness(store: readyStore());
    h.auth.emailAccounts['priya@example.com'] = 'correct-horse';
    await h.boot(tester);
    await tapText(tester, 'Continue with email');
    await tester.enterText(find.byKey(const Key('email')), 'priya@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "That email and password don't match. Try again or reset your password.",
      ),
      findsOneWidget,
    );
    expect(h.auth.signedIn, isNull);
  });

  testWidgets('Google: cancelling says nothing and stays put', (tester) async {
    final h = Harness(store: readyStore());
    h.auth.googleFailure = AuthFailure.cancelled;
    await h.boot(tester);
    await tapText(tester, 'Continue with Google');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('returning member with an account goes straight to Home', (
    tester,
  ) async {
    final h = Harness();
    h.profiles.existing['google:1'] = 'assessment';
    await h.boot(tester);
    await tapText(tester, 'I already have an account');
    await tapText(tester, 'Continue with Google');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(h.profiles.created, isEmpty);
  });

  testWidgets('new device, no account yet: finish onboarding after sign-in', (
    tester,
  ) async {
    final h = Harness();
    await h.boot(tester);
    await tapText(tester, 'I already have an account');
    await tapText(tester, 'Continue with Google');
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(h.profiles.created, isEmpty, reason: 'no 18+ check or legal yet');

    await tapText(tester, 'Continue');
    await tapText(tester, "Yes, I'm 18 or older");
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(CheckboxListTile).at(i));
      await tester.pumpAndSettle();
    }
    await tapText(tester, 'Accept and continue');
    expect(find.byType(WhyScreen), findsOneWidget);
    expect(h.profiles.created.keys, ['google:1']);
    expect(h.consents.records, hasLength(4));
  });

  testWidgets('signed in, then says under 18: the account is deleted', (
    tester,
  ) async {
    final h = Harness();
    await h.boot(tester);
    await tapText(tester, 'I already have an account');
    await tapText(tester, 'Continue with Google');
    await tapText(tester, 'Continue');
    await tapText(tester, "No, I'm under 18");
    expect(find.text('Live Well is for adults'), findsOneWidget);
    expect(h.auth.deleted, isTrue);
    expect(h.auth.signedIn, isNull);
    expect(h.profiles.created, isEmpty);
    expect(h.store.saved, isNull);
  });

  testWidgets('phone screen labels both countries with their codes', (
    tester,
  ) async {
    await Harness(store: readyStore()).boot(tester);
    await tapText(tester, 'Continue with phone');
    expect(find.text('India (+91)'), findsOneWidget);
    // Regression: PR #13 had overwritten this label with "the US".
    expect(find.text('United States (+1)'), findsOneWidget);
  });
}
