import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/core/auth/staff.dart';

void main() {
  final now = DateTime.utc(2026, 11, 19, 12);
  final nowS = now.millisecondsSinceEpoch ~/ 1000;

  StaffSession parse(Map<String, Object?> claims) => StaffSession.fromClaims(
    uid: 'u',
    email: 'u@example.com',
    claims: {'iat': nowS - 60, ...claims},
    now: now,
  );

  test('roles come only from known staff_roles values', () {
    final s = parse({
      'staff_roles': ['content_editor', 'root', 7, 'admin'],
    });
    expect(s.roles, {StaffRole.contentEditor, StaffRole.admin});
    expect(parse({'staff_roles': 'admin'}).roles, isEmpty);
    expect(parse({}).isStaff, isFalse);
  });

  test('MFA: a second factor, or a live waiver of at most 30 days', () {
    final roles = {
      'staff_roles': ['admin'],
    };
    expect(parse(roles).canUseConsole, isFalse);
    expect(
      parse({
        ...roles,
        'firebase': {'sign_in_second_factor': 'totp'},
      }).canUseConsole,
      isTrue,
    );
    expect(
      parse({...roles, 'staff_mfa_waiver_until': nowS + 3600}).canUseConsole,
      isTrue,
    );
    expect(
      parse({...roles, 'staff_mfa_waiver_until': nowS - 1}).canUseConsole,
      isFalse,
    );
    expect(
      parse({
        ...roles,
        'staff_mfa_waiver_until': nowS + const Duration(days: 31).inSeconds,
      }).canUseConsole,
      isFalse,
    );
    // MFA without a role still doesn't open the console.
    expect(
      parse({
        'firebase': {'sign_in_second_factor': 'totp'},
      }).canUseConsole,
      isFalse,
    );
  });
}
