import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/core/auth/auth_repository.dart';
import 'package:livewell_admin/core/auth/staff.dart';

import '../support/harness.dart';

// The role gate (T-PRT-02, D-92): the catalog is never loaded or shown to
// anyone without a staff role and MFA. The Core API checks again.
void main() {
  testWidgets('signed out: sign-in page, catalog not loaded', (tester) async {
    final (_, api) = await pumpAdmin(tester, offers: [offer('a')]);
    expect(find.byKey(const Key('sign-in-submit')), findsOneWidget);
    expect(find.text('Portal catalog'), findsNothing);
    expect(api.listCalls, 0);
  });

  testWidgets('an app user without a staff role sees No access', (
    tester,
  ) async {
    final (_, api) = await pumpAdmin(
      tester,
      session: staff('u', {}),
      offers: [offer('a')],
      location: '/offers/a',
    );
    expect(find.byKey(const Key('no-access-role')), findsOneWidget);
    expect(find.text('Gut health in 30 days'), findsNothing);
    expect(api.listCalls, 0);
  });

  testWidgets('staff without MFA are asked for two-step sign-in', (
    tester,
  ) async {
    final (_, api) = await pumpAdmin(
      tester,
      session: staff('s', {StaffRole.admin}, mfa: false),
      offers: [offer('a')],
    );
    expect(find.byKey(const Key('no-access-mfa')), findsOneWidget);
    expect(api.listCalls, 0);
  });

  testWidgets('sign-in, then the catalog; sign-out returns to sign-in', (
    tester,
  ) async {
    final (auth, _) = await pumpAdmin(tester, offers: [offer('a')]);
    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'ed@example.com',
    );
    await tester.enterText(find.byKey(const Key('sign-in-password')), 'pw');
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();
    expect(auth.signIns, ['ed@example.com']);

    auth.emit(editor);
    await tester.pumpAndSettle();
    expect(find.text('Portal catalog'), findsOneWidget);
    expect(find.text('Gut health in 30 days'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sign-in-submit')), findsOneWidget);
  });

  testWidgets('a failed sign-in says why', (tester) async {
    final (auth, _) = await pumpAdmin(tester);
    auth.failNext = const SignInFailure('Email or password is not right.');
    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'x@example.com',
    );
    await tester.enterText(find.byKey(const Key('sign-in-password')), 'pw');
    // Enter in the password field submits (keyboard use).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Email or password is not right.'), findsOneWidget);
  });

  testWidgets('reviewers have no New offer and cannot open the editor', (
    tester,
  ) async {
    await pumpAdmin(
      tester,
      session: reviewer,
      offers: [offer('a')],
      location: '/offers/new',
    );
    expect(find.text('Portal catalog'), findsOneWidget);
    expect(find.byKey(const Key('offer-new')), findsNothing);
    expect(find.byKey(const Key('field-title')), findsNothing);
  });
}
