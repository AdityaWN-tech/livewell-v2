import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/auth/presentation/phone_sign_in_screen.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';

import 'profile_test.dart' show confirm, openProfile, signedIn, tapKey;

/// Step 4c (D-55, FR-ONB-01, D-02): Profile > Add a phone number with a
/// one-time code, added to this account (never a new sign-in), and removed
/// again unless it is the only way to sign in.

Future<void> addNumber(
  WidgetTester tester, {
  String number = '98765 43210',
  String code = '123456',
}) async {
  await tapKey(tester, 'profile-link-phone');
  expect(find.byType(PhoneSignInScreen), findsOneWidget);
  expect(find.text('Add a phone number'), findsOneWidget);
  await tester.tap(find.text('India (+91)'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('phone')), number);
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('code')), code);
  await tester.tap(find.text('Verify'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add a number: same account, back on Profile, can remove it', (
    tester,
  ) async {
    final h = signedIn();
    await h.boot(tester);
    await openProfile(tester);
    await addNumber(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    final user = h.auth.signedIn!;
    expect(user.uid, 'u1', reason: 'added to this account, not a new one');
    expect(user.providers, ['password', 'phone']);
    expect(user.phoneNumber, '+919876543210');
    expect(find.textContaining('Your phone number is added'), findsOneWidget);

    // The row now offers to remove it, showing the number.
    await tapKey(tester, 'profile-link-phone');
    expect(find.text('Remove your phone number?'), findsOneWidget);
    await confirm(tester);
    expect(h.auth.signedIn!.providers, ['password']);
    expect(find.text('Phone number removed.'), findsOneWidget);
  });

  testWidgets('a wrong code says so and nothing is added', (tester) async {
    final h = signedIn();
    await h.boot(tester);
    await openProfile(tester);
    await addNumber(tester, code: '000000');
    expect(find.byType(PhoneSignInScreen), findsOneWidget);
    expect(find.textContaining("That code isn't right"), findsOneWidget);
    expect(h.auth.signedIn!.providers, ['password']);
  });

  testWidgets('a number another account uses: a kind message', (tester) async {
    final h = signedIn();
    h.auth.takenPhones.add('+919876543210');
    await h.boot(tester);
    await openProfile(tester);
    await addNumber(tester);
    expect(
      find.textContaining('already used by another Live Well account'),
      findsOneWidget,
    );
    expect(h.auth.signedIn!.providers, ['password']);
  });

  testWidgets('the only way to sign in can\'t be removed', (tester) async {
    final h = signedIn(providers: ['phone']);
    await h.boot(tester);
    await openProfile(tester);
    await tapKey(tester, 'profile-link-phone');
    await confirm(tester);
    expect(find.textContaining('only way to sign in'), findsOneWidget);
    expect(h.auth.signedIn!.providers, ['phone']);
  });

  test('Firebase errors map to kind messages', () {
    expect(
      authFailureFromCode('credential-already-in-use'),
      AuthFailure.phoneInUse,
    );
    expect(
      authFailureFromCode('provider-already-linked'),
      AuthFailure.alreadyLinked,
    );
  });
}
