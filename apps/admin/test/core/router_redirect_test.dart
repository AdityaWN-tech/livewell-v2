import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/app/router.dart';
import 'package:livewell_admin/core/auth/staff.dart';

import '../support/harness.dart';

void main() {
  String? go(StaffSession? s, String path) =>
      adminRedirect(AsyncData(s), Uri.parse(path));

  test('signed out: every page goes to sign-in', () {
    for (final p in ['/offers', '/offers/x', '/offers/new', '/no-access']) {
      expect(go(null, p), '/sign-in');
    }
    expect(go(null, '/sign-in'), isNull);
  });

  test('no staff role, or no MFA: no-access, never the catalog', () {
    final appUser = staff('u', {});
    final noMfa = staff('s', {StaffRole.admin}, mfa: false);
    for (final s in [appUser, noMfa]) {
      expect(go(s, '/offers'), '/no-access');
      expect(go(s, '/offers/abc'), '/no-access');
      expect(go(s, '/sign-in'), '/no-access');
      expect(go(s, '/no-access'), isNull);
    }
  });

  test('staff: catalog; editing pages need an editing role', () {
    expect(go(editor, '/sign-in'), '/offers');
    expect(go(editor, '/offers/new'), isNull);
    expect(go(editor, '/offers/a/edit'), isNull);
    for (final s in [reviewer, safetyReviewer]) {
      expect(go(s, '/offers'), isNull);
      expect(go(s, '/offers/a'), isNull);
      expect(go(s, '/offers/new'), '/offers');
      expect(go(s, '/offers/a/edit'), '/offers');
    }
    expect(go(admin, '/offers/new'), isNull);
  });

  test('while the session loads, waits and then returns to the page', () {
    const loading = AsyncLoading<StaffSession?>();
    expect(
      adminRedirect(loading, Uri.parse('/offers/a')),
      '/loading?from=%2Foffers%2Fa',
    );
    expect(go(editor, '/loading?from=/offers/a'), '/offers/a');
    // Only catalog pages are valid targets.
    expect(go(editor, '/loading?from=https://evil.example'), '/offers');
  });
}
