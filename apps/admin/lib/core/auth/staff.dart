/// Admin / CMS staff and their roles (spec 10.2, 16.2; T-PRT-02, D-92).
///
/// Roles come from Firebase Auth custom claims set only by the owner's
/// server script (`services/core-api/scripts/set-staff-claims.mjs`). The
/// checks here only decide what the console shows; the Core API checks the
/// same claims again on every call and is the real gate.
library;

enum StaffRole {
  contentEditor('content_editor', 'Content editor'),
  clinicalReviewer('clinical_reviewer', 'Clinical reviewer'),
  safetyReviewer('safety_reviewer', 'Safety reviewer'),
  admin('admin', 'Admin');

  const StaffRole(this.claim, this.label);

  /// The value in the `staff_roles` claim.
  final String claim;
  final String label;

  static StaffRole? fromClaim(Object? v) {
    for (final r in values) {
      if (r.claim == v) return r;
    }
    return null;
  }
}

/// Longest MFA waiver the server honours (services/core-api staff.ts).
const maxMfaWaiver = Duration(days: 30);

/// The signed-in person as the console sees them.
class StaffSession {
  const StaffSession({
    required this.uid,
    required this.email,
    required this.roles,
    required this.mfaSatisfied,
  });

  /// Reads the ID token claims. Unknown roles are ignored; MFA counts when
  /// the sign-in used a second factor or a live, short owner waiver exists.
  factory StaffSession.fromClaims({
    required String uid,
    required String? email,
    required Map<String, Object?> claims,
    required DateTime now,
  }) {
    final raw = claims['staff_roles'];
    final roles = <StaffRole>{
      if (raw is List)
        for (final r in raw) ?StaffRole.fromClaim(r),
    };
    return StaffSession(
      uid: uid,
      email: email,
      roles: roles,
      mfaSatisfied: _mfa(claims, now),
    );
  }

  static bool _mfa(Map<String, Object?> claims, DateTime now) {
    final firebase = claims['firebase'];
    if (firebase is Map && firebase['sign_in_second_factor'] is String) {
      return true;
    }
    final until = claims['staff_mfa_waiver_until'];
    final iat = claims['iat'];
    if (until is! num || iat is! num) return false;
    final nowS = now.millisecondsSinceEpoch ~/ 1000;
    return until > nowS && until - iat <= maxMfaWaiver.inSeconds;
  }

  final String uid;
  final String? email;
  final Set<StaffRole> roles;
  final bool mfaSatisfied;

  bool get isStaff => roles.isNotEmpty;

  /// Signed in, has a role and passed MFA: the console opens.
  bool get canUseConsole => isStaff && mfaSatisfied;

  bool hasAny(Iterable<StaffRole> any) => any.any(roles.contains);
}
