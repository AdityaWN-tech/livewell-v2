import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/components/social_sign_in.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';

import '../support/app_harness.dart';
import 'sign_in_flow_test.dart' show readyStore, tapKey;

/// T-ONB-03a: Google and Apple as one-tap logo buttons.
void main() {
  final google = find.byKey(const Key('sign-in-google'));
  final apple = find.byKey(const Key('sign-in-apple'));

  group('the icons', () {
    for (final dark in [false, true]) {
      testWidgets(
        'labelled, 48 dp, right artwork (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final handle = tester.ensureSemantics();
          await Harness(store: readyStore()).boot(tester);

          expect(find.text('or continue with'), findsOneWidget);
          expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
          expect(find.bySemanticsLabel('Continue with Apple'), findsOneWidget);
          for (final f in [google, apple]) {
            expect(tester.getSize(f), const Size(48, 48));
          }
          // Google's own light / dark button, never recoloured.
          final image = tester.widget<Image>(
            find.descendant(of: google, matching: find.byType(Image)),
          );
          expect(
            (image.image as AssetImage).assetName,
            dark
                ? 'assets/brand/social/google_dark.png'
                : 'assets/brand/social/google_light.png',
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }

    testWidgets('the old large "Continue with Google" button is gone', (
      tester,
    ) async {
      await Harness(store: readyStore()).boot(tester);
      expect(
        find.widgetWithText(OutlinedButton, 'Continue with Google'),
        findsNothing,
      );
      expect(find.byType(SocialSignInButton), findsNWidgets(2));
    });
  });

  group('one tap signs in or signs up', () {
    testWidgets('Google, new person: account created, then the Why', (
      tester,
    ) async {
      final h = Harness(store: readyStore());
      await h.boot(tester);
      await tapKey(tester, 'sign-in-google');
      expect(find.byType(WhyScreen), findsOneWidget);
      expect(h.profiles.created.keys, ['google:1']);
      expect(h.consents.records, hasLength(4));
    });

    testWidgets('Google, existing account: straight to Home, nothing redone', (
      tester,
    ) async {
      final h = Harness(store: readyStore());
      h.profiles.existing['google:1'] = 'assessment';
      await h.boot(tester);
      await tapKey(tester, 'sign-in-google');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.profiles.created, isEmpty);
      expect(h.consents.records, isEmpty);
    });

    testWidgets('Apple with a hidden email (private relay) is accepted', (
      tester,
    ) async {
      final h = Harness(store: readyStore());
      await h.boot(tester);
      await tapKey(tester, 'sign-in-apple');
      expect(find.byType(WhyScreen), findsOneWidget);
      expect(h.profiles.created['apple:1']!.email, isNull);
    });

    for (final key in ['sign-in-google', 'sign-in-apple']) {
      testWidgets('$key: cancelling says nothing and stays put', (
        tester,
      ) async {
        final h = Harness(store: readyStore());
        h.auth
          ..googleFailure = AuthFailure.cancelled
          ..appleFailure = AuthFailure.cancelled;
        await h.boot(tester);
        await tapKey(tester, key);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byKey(Key(key)), findsOneWidget);
        expect(h.auth.signedIn, isNull);
      });
    }

    testWidgets('Apple not set up for this build: a calm message', (
      tester,
    ) async {
      final h = Harness(store: readyStore());
      h.auth.appleFailure = AuthFailure.methodDisabled;
      await h.boot(tester);
      await tapKey(tester, 'sign-in-apple');
      expect(
        find.text("This sign-in option isn't available yet."),
        findsOneWidget,
      );
    });
  });

  group('same email used another way (account-exists)', () {
    const message =
        'You already have a Live Well account with this email. Sign in the '
        'way you did before (phone or email). Then we’ll offer to add '
        'this option to it.';

    Future<Harness> hitExisting(WidgetTester tester) async {
      final h = Harness(store: readyStore());
      h.auth
        ..googleFailure = AuthFailure.accountExists
        ..existingEmail = 'priya@example.com'
        ..emailAccounts['priya@example.com'] = 'correct-horse';
      await h.boot(tester);
      await tapKey(tester, 'sign-in-google');
      expect(find.text(message), findsOneWidget);
      expect(h.auth.signedIn, isNull);
      return h;
    }

    Future<void> signInWithEmail(WidgetTester tester, String email) async {
      await tapText(tester, 'Continue with email');
      await tester.enterText(find.byKey(const Key('email')), email);
      await tester.enterText(
        find.byKey(const Key('password')),
        'correct-horse',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      // The sign-in spinner keeps running while the link offer is open.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('kind message, then after the original sign-in: add Google', (
      tester,
    ) async {
      final h = await hitExisting(tester);
      await signInWithEmail(tester, 'priya@example.com');
      expect(find.text('Add Google to your account?'), findsOneWidget);
      await tapText(tester, 'Add Google');
      expect(h.auth.linked, [SocialProvider.google]);
      expect(find.text('Google is now added to your account.'), findsOneWidget);
    });

    testWidgets('"Not now" links nothing', (tester) async {
      final h = await hitExisting(tester);
      await signInWithEmail(tester, 'priya@example.com');
      await tapText(tester, 'Not now');
      expect(find.text('Add Google to your account?'), findsNothing);
      expect(h.auth.linked, isEmpty);
      expect(h.auth.pending, isNull);
    });

    testWidgets('a different account is never offered the link', (
      tester,
    ) async {
      final h = await hitExisting(tester);
      h.auth.emailAccounts['other@example.com'] = 'correct-horse';
      await signInWithEmail(tester, 'other@example.com');
      expect(find.text('Add Google to your account?'), findsNothing);
      expect(h.auth.linked, isEmpty);
      expect(h.auth.pending, isNull);
    });
  });
}
