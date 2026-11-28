// Staff access on the free plan (D-112): request -> Superadmin approves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/app/router.dart';
import 'package:livewell_admin/core/auth/staff.dart';
import 'package:livewell_admin/features/staff/domain/staff_access.dart';

import '../support/harness.dart';

void main() {
  group('who goes where (adminRedirect)', () {
    String? go(StaffSession s, String path, [StaffAccess? a]) =>
        adminRedirect(AsyncData(s), Uri.parse(path), access: AsyncData(a));

    test('a new person asks for access; can reach nothing else', () {
      final p = person('priya');
      expect(go(p, '/offers', StaffAccess.none), '/request-access');
      expect(go(p, '/superadmin', StaffAccess.none), '/request-access');
      expect(go(p, '/request-access', StaffAccess.none), isNull);
      expect(go(p, '/offers', StaffAccess.rejected), '/request-access');
    });

    test('waiting: only the waiting page', () {
      final p = person('priya');
      expect(go(p, '/offers', StaffAccess.pending), '/pending');
      expect(go(p, '/superadmin', StaffAccess.pending), '/pending');
      expect(go(p, '/pending', StaffAccess.pending), isNull);
    });

    test('approved Admin: the console, never the Superadmin portal', () {
      final p = person('priya');
      expect(go(p, '/pending', StaffAccess.active), '/content');
      expect(go(p, '/offers', StaffAccess.active), isNull);
      expect(go(p, '/superadmin', StaffAccess.active), '/content');
    });

    test('removed: no access', () {
      expect(go(person('priya'), '/offers', StaffAccess.removed), '/no-access');
    });

    test(
      'Superadmin: starts at the Superadmin portal, can open the console',
      () {
        expect(go(superadmin(), '/sign-in'), '/superadmin');
        expect(go(superadmin(), '/superadmin'), isNull);
        expect(go(superadmin(), '/offers'), isNull);
      },
    );

    test('the claim alone is not a Superadmin: domain and verification', () {
      bool sup(Map<String, Object?> c, String e) => isSuperadminClaims(c, e);
      const ok = {'superadmin': true, 'email_verified': true};
      expect(sup(ok, 'owner@whitenoiseacademy.com'), isTrue);
      expect(sup(ok, 'Owner@WhiteNoiseAcademy.com'), isTrue);
      expect(sup(ok, 'owner@gmail.com'), isFalse);
      expect(
        sup({...ok, 'email_verified': false}, 'owner@whitenoiseacademy.com'),
        isFalse,
      );
      expect(
        sup({'email_verified': true}, 'owner@whitenoiseacademy.com'),
        isFalse,
      );
    });
  });

  testWidgets('request access, then the waiting page', (tester) async {
    final staff = FakeStaffAccessRepository();
    await pumpAdmin(tester, session: person('priya'), staff: staff);
    expect(find.byKey(const Key('request-access')), findsOneWidget);

    // Both fields are needed.
    await tester.tap(find.byKey(const Key('request-send')));
    await tester.pumpAndSettle();
    expect(staff.sent, isEmpty);

    await tester.enterText(find.byKey(const Key('request-name')), 'Priya');
    await tester.enterText(
      find.byKey(const Key('request-reason')),
      'I write the sleep lessons',
    );
    await tester.tap(find.byKey(const Key('request-send')));
    await tester.pumpAndSettle();
    expect(staff.sent, ['Priya|I write the sleep lessons|false']);
    expect(find.byKey(const Key('pending')), findsOneWidget);
  });

  testWidgets('waiting page opens the console once approved', (tester) async {
    final staff = FakeStaffAccessRepository(access: StaffAccess.pending);
    await pumpAdmin(tester, session: person('priya'), staff: staff);
    expect(find.byKey(const Key('pending')), findsOneWidget);
    staff.setAccess(StaffAccess.active);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pending')), findsNothing);
  });

  testWidgets('Superadmin approves, rejects and removes', (tester) async {
    final staff = FakeStaffAccessRepository(
      requests: const [
        StaffRequest(
          uid: 'priya',
          name: 'Priya',
          email: 'priya@gmail.com',
          reason: 'I write the sleep lessons',
          status: 'pending',
        ),
        StaffRequest(
          uid: 'ravi',
          name: 'Ravi',
          email: 'ravi@gmail.com',
          reason: 'test',
          status: 'pending',
        ),
      ],
    );
    await pumpAdmin(tester, session: superadmin(), staff: staff);
    expect(find.text('Requests (2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-priya')));
    await tester.pumpAndSettle();
    // Reject asks first; Cancel does nothing.
    await tester.tap(find.byKey(const Key('reject-ravi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(staff.rejected, isEmpty);
    await tester.tap(find.byKey(const Key('reject-ravi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-ok')));
    await tester.pumpAndSettle();
    expect(staff.approved, ['priya']);
    expect(staff.rejected, ['ravi']);
    expect(find.text('No requests waiting.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-admins')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-priya')), findsOneWidget);
    // A new Admin starts as a Content editor.
    expect(find.text('Content editor'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-priya')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-ok')));
    await tester.pumpAndSettle();
    expect(staff.removed, ['priya']);
    expect(find.byKey(const Key('restore-priya')), findsOneWidget);
  });

  testWidgets('Superadmin gives an Admin the clinical reviewer role', (
    tester,
  ) async {
    final staff = FakeStaffAccessRepository(
      members: const [
        StaffMember(
          uid: 'anita',
          name: 'Anita',
          email: 'anita@gmail.com',
          status: 'active',
          roles: {StaffRole.contentEditor},
        ),
      ],
    );
    await pumpAdmin(tester, session: superadmin(), staff: staff);
    // No reviewer yet: the Content tab says nothing can go live.
    await tester.tap(find.byKey(const Key('tab-content')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-reviewer')), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(find.byKey(const Key('tab-admins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roles-anita')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-clinical_reviewer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roles-save')));
    await tester.pumpAndSettle();
    expect(staff.rolesSet['anita'], {
      StaffRole.contentEditor,
      StaffRole.clinicalReviewer,
    });
    expect(find.text('Content editor, Clinical reviewer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-content')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-reviewer')), findsNothing);
    expect(find.text('1 clinical reviewer'), findsOneWidget);
  });

  testWidgets('search narrows Requests and Admins by name or email', (
    tester,
  ) async {
    final staff = FakeStaffAccessRepository(
      requests: const [
        StaffRequest(
          uid: 'priya',
          name: 'Priya',
          email: 'priya@gmail.com',
          reason: 'lessons',
          status: 'pending',
        ),
        StaffRequest(
          uid: 'ravi',
          name: 'Ravi',
          email: 'ravi@clinic.org',
          reason: 'reviews',
          status: 'pending',
        ),
      ],
    );
    await pumpAdmin(tester, session: superadmin(), staff: staff);
    await tester.enterText(find.byKey(const Key('staff-search')), 'CLINIC');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('request-ravi')), findsOneWidget);
    expect(find.byKey(const Key('request-priya')), findsNothing);
    await tester.enterText(find.byKey(const Key('staff-search')), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No requests match your search.'), findsOneWidget);
  });

  testWidgets('Activity shows people, not account ids', (tester) async {
    final staff = FakeStaffAccessRepository(
      people: const {'priya': 'Priya (priya@gmail.com)'},
      activity: const [
        StaffAuditEntry(
          actor: 'super1',
          action: 'staff.roles_changed',
          target: 'staff_members/priya',
        ),
        StaffAuditEntry(
          actor: 'super2',
          action: 'staff.rejected',
          target: 'staff_requests/ghost',
        ),
      ],
    );
    await pumpAdmin(tester, session: superadmin(), staff: staff);
    await tester.tap(find.byKey(const Key('tab-activity')));
    await tester.pumpAndSettle();
    expect(find.text('Roles changed: Priya (priya@gmail.com)'), findsOneWidget);
    expect(find.textContaining('by you'), findsOneWidget);
    expect(find.text('Rejected: Unknown person (ghost)'), findsOneWidget);
    expect(find.textContaining('by another Superadmin'), findsOneWidget);
  });

  test('roles from Firestore: only the three known ones', () {
    expect(rolesFrom(['clinical_reviewer', 'admin', 'superadmin', 3]), {
      StaffRole.clinicalReviewer,
    });
    expect(rolesFrom(null), isEmpty);
    expect(uidOfTarget('staff_members/abc'), 'abc');
  });

  testWidgets('sign-in offers Google', (tester) async {
    final (auth, _) = await pumpAdmin(tester);
    await tester.tap(find.byKey(const Key('sign-in-google')));
    await tester.pumpAndSettle();
    expect(auth.googleSignIns, hasLength(1));
  });
}
