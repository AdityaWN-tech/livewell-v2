import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/presentation/avatar_screen.dart';
import 'package:livewell/features/auth/presentation/phone_sign_in_screen.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:livewell/features/onboarding/presentation/about_screen.dart';

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
  testWidgets('sign-in offers phone, email, and Google and Apple icons', (
    tester,
  ) async {
    await Harness(store: readyStore()).boot(tester);
    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-apple')), findsOneWidget);
  });

  testWidgets('phone: US number, code, then the account is set up', (
    tester,
  ) async {
    final h = Harness(store: readyStore());
    await h.boot(tester);
    await tapText(tester, 'Continue with phone');

    await tester.enterText(find.byKey(const Key('phone')), '12345');
    await tapText(tester, 'Send code');
    expect(
      find.text('Enter a valid mobile number for United States.'),
      findsOneWidget,
    );
    expect(h.auth.codesSent, 0);

    // An area code can't start with 1 (NANP), so this isn't a US number.
    await tester.enterText(find.byKey(const Key('phone')), '112 555 0123');
    await tapText(tester, 'Send code');
    expect(
      find.text('Enter a valid mobile number for United States.'),
      findsOneWidget,
    );
    expect(h.auth.codesSent, 0);

    await tester.enterText(find.byKey(const Key('phone')), '(212) 555-0123');
    await tapText(tester, 'Send code');
    expect(
      find.text('We sent a 6-digit code to +12125550123.'),
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
    expect(find.byType(AvatarScreen), findsOneWidget);

    const uid = 'phone:+12125550123';
    // flutter_test's locale is en_US, so +1 resolves to the US (D-03).
    expect(h.profiles.created[uid]!.region, 'US');
    expect(h.consents.records.map((r) => r.type), legalDocuments);
    expect(h.store.saved, isNull, reason: 'on-device progress cleared');
  });

  testWidgets('phone: resend unlocks after the countdown', (tester) async {
    final h = Harness(store: readyStore());
    await h.boot(tester);
    await tapText(tester, 'Continue with phone');
    await tester.enterText(find.byKey(const Key('phone')), '2125550123');
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
    expect(find.byType(AvatarScreen), findsOneWidget);
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
    await tapKey(tester, 'sign-in-google');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
  });

  testWidgets('returning member with an account goes straight to Home', (
    tester,
  ) async {
    final h = Harness();
    h.profiles.existing['google:1'] = 'assessment';
    await h.boot(tester);
    await tapText(tester, 'I already have an account');
    await tapKey(tester, 'sign-in-google');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(h.profiles.created, isEmpty);
  });

  testWidgets('new device, no account yet: finish onboarding after sign-in', (
    tester,
  ) async {
    final h = Harness();
    await h.boot(tester);
    await tapText(tester, 'I already have an account');
    await tapKey(tester, 'sign-in-google');
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(h.profiles.created, isEmpty, reason: 'no 18+ check or legal yet');

    await tapText(tester, 'Continue');
    await tapText(tester, "Yes, I'm 18 or older");
    await tester.tap(find.byKey(const Key('legal-agree-box')));
    await tester.pumpAndSettle();
    await tapText(tester, 'Accept and continue');
    expect(find.byType(AvatarScreen), findsOneWidget);
    expect(h.profiles.created.keys, ['google:1']);
    expect(h.consents.records, hasLength(4));
  });

  testWidgets('signed in, then says under 18: the account is deleted', (
    tester,
  ) async {
    final h = Harness();
    await h.boot(tester);
    await tapText(tester, 'I already have an account');
    await tapKey(tester, 'sign-in-google');
    await tapText(tester, 'Continue');
    await tapText(tester, "No, I'm under 18");
    expect(find.text('Live Well is for adults'), findsOneWidget);
    expect(h.auth.deleted, isTrue);
    expect(h.auth.signedIn, isNull);
    expect(h.profiles.created, isEmpty);
    expect(h.store.saved, isNull);
  });

  group('phone: any country (D-99)', () {
    Future<Harness> openPhone(WidgetTester tester, {Locale? locale}) async {
      if (locale != null) {
        tester.platformDispatcher.localeTestValue = locale;
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      }
      final h = Harness(store: readyStore());
      await h.boot(tester);
      await tapText(tester, 'Continue with phone');
      return h;
    }

    String chosen(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('phone-country-value'))).data!;

    testWidgets('the country defaults to the device country', (tester) async {
      await openPhone(tester, locale: const Locale('en', 'IN'));
      expect(chosen(tester), contains('India (+91)'));
      expect(find.text('+91 '), findsOneWidget, reason: 'number prefix');
    });

    testWidgets('a device in another country pre-selects it', (tester) async {
      await openPhone(tester, locale: const Locale('en', 'GB'));
      expect(chosen(tester), contains('United Kingdom (+44)'));
    });

    testWidgets('no device country: the United States', (tester) async {
      await openPhone(tester, locale: const Locale('en'));
      expect(chosen(tester), contains('United States (+1)'));
    });

    testWidgets('search by name, code or dial code, then select', (
      tester,
    ) async {
      await openPhone(tester);
      expect(chosen(tester), contains('United States (+1)'));
      await tapKey(tester, 'phone-country');
      expect(find.text('Choose your country'), findsOneWidget);
      // The two markets come first.
      expect(find.byKey(const Key('country-US')), findsOneWidget);
      expect(find.byKey(const Key('country-IN')), findsOneWidget);

      final search = find.byKey(const Key('country-search'));
      await tester.enterText(search, 'united k');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('country-GB')), findsOneWidget);
      expect(find.byKey(const Key('country-US')), findsNothing);

      await tester.enterText(search, '+977');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('country-NP')), findsOneWidget);
      expect(find.byKey(const Key('country-IN')), findsNothing);

      await tester.enterText(search, 'cote');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('country-CI')), findsOneWidget);

      await tester.enterText(search, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No country matches that'), findsOneWidget);

      await tester.enterText(search, 'ae');
      await tester.pumpAndSettle();
      await tapKey(tester, 'country-AE');
      expect(find.text('Choose your country'), findsNothing);
      expect(chosen(tester), contains('United Arab Emirates (+971)'));
      expect(find.text('+971 '), findsOneWidget);
    });

    testWidgets('India picked: a +91 number signs in, region India', (
      tester,
    ) async {
      final h = await openPhone(tester);
      await tapKey(tester, 'phone-country');
      await tester.enterText(find.byKey(const Key('country-search')), 'india');
      await tester.pumpAndSettle();
      await tapKey(tester, 'country-IN');

      // A US-shaped number that isn't an Indian mobile is refused.
      await tester.enterText(find.byKey(const Key('phone')), '212 555 0123');
      await tapText(tester, 'Send code');
      expect(
        find.text('Enter a valid mobile number for India.'),
        findsOneWidget,
      );
      expect(h.auth.codesSent, 0);

      await tester.enterText(find.byKey(const Key('phone')), '98765 43210');
      await tapText(tester, 'Send code');
      expect(
        find.text('We sent a 6-digit code to +919876543210.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('code')), '123456');
      await tapText(tester, 'Verify');
      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(h.profiles.created['phone:+919876543210']!.region, 'IN');
    });

    testWidgets('a UK number signs in and the region is left to ask (D-03)', (
      tester,
    ) async {
      // Device is en_US, the number is +44: never guess a region.
      final h = await openPhone(tester);
      await tapKey(tester, 'phone-country');
      await tester.enterText(find.byKey(const Key('country-search')), 'gb');
      await tester.pumpAndSettle();
      await tapKey(tester, 'country-GB');
      await tester.enterText(find.byKey(const Key('phone')), '07400 123456');
      await tapText(tester, 'Send code');
      expect(
        find.text('We sent a 6-digit code to +447400123456.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('code')), '123456');
      await tapText(tester, 'Verify');
      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(h.profiles.created['phone:+447400123456']!.region, isNull);
    });

    testWidgets('a typed +code is accepted as typed', (tester) async {
      final h = await openPhone(tester);
      await tester.enterText(find.byKey(const Key('phone')), '+61 412 345 678');
      await tester.pump();
      expect(find.text('+1 '), findsNothing, reason: 'no clashing prefix');
      await tapText(tester, 'Send code');
      expect(
        find.text('We sent a 6-digit code to +61412345678.'),
        findsOneWidget,
      );
      expect(h.auth.codesSent, 1);
    });

    testWidgets('still one primary action on the phone screen', (tester) async {
      await openPhone(tester);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}
