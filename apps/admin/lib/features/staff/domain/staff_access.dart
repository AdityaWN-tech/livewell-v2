/// Staff access on the free plan (D-112): a person asks, a Superadmin
/// approves. The Firestore rules enforce every step; this is the app's view.
library;

import '../../../core/auth/staff.dart';

/// The roles a Superadmin can give an Admin (D-118). Only a clinical
/// reviewer may approve or send back content; the Firestore rules check it.
const assignableRoles = [
  StaffRole.contentEditor,
  StaffRole.clinicalReviewer,
  StaffRole.safetyReviewer,
];

/// Reads `staff_members/{uid}.roles`; unknown values are ignored.
Set<StaffRole> rolesFrom(Object? raw) => {
  if (raw is List)
    for (final r in raw)
      if (StaffRole.fromClaim(r) case final role?
          when assignableRoles.contains(role))
        role,
};

/// Where the signed-in person stands.
enum StaffAccess {
  /// Never asked.
  none,

  /// Asked; waiting for a Superadmin.
  pending,

  /// A Superadmin said no (they may ask again).
  rejected,

  /// Approved Admin.
  active,

  /// Was an Admin; removed by a Superadmin.
  removed,
}

/// One "Request admin access" (staff_requests/{uid}).
class StaffRequest {
  const StaffRequest({
    required this.uid,
    required this.name,
    required this.email,
    required this.reason,
    required this.status,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String reason;

  /// pending, approved or rejected.
  final String status;
  final DateTime? createdAt;
}

/// An approved Admin (staff_members/{uid}).
class StaffMember {
  const StaffMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    this.roles = const {},
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;

  /// active or removed.
  final String status;

  /// What this Admin may do (D-118).
  final Set<StaffRole> roles;
  final DateTime? updatedAt;

  bool get active => status == 'active';
  bool get clinicalReviewer =>
      active && roles.contains(StaffRole.clinicalReviewer);

  /// "Clinical reviewer, Safety reviewer" in the fixed order; "No roles yet".
  String get rolesLabel {
    final names = [
      for (final r in assignableRoles)
        if (roles.contains(r)) r.label,
    ];
    return names.isEmpty ? 'No roles yet' : names.join(', ');
  }
}

/// One line of the Superadmin activity log (staff_audit).
class StaffAuditEntry {
  const StaffAuditEntry({
    required this.actor,
    required this.action,
    required this.target,
    this.at,
  });

  final String actor;

  /// staff.approved, staff.rejected, staff.removed or staff.restored.
  final String action;
  final String target;
  final DateTime? at;

  String get label => switch (action) {
    'staff.approved' => 'Approved',
    'staff.rejected' => 'Rejected',
    'staff.removed' => 'Removed',
    'staff.restored' => 'Restored',
    'staff.roles_changed' => 'Roles changed',
    _ => action,
  };
}

/// The uid in an activity target ("staff_members/abc" -> "abc").
String uidOfTarget(String target) {
  final i = target.lastIndexOf('/');
  return i < 0 ? target : target.substring(i + 1);
}

/// Combines the person's request and membership into one state.
StaffAccess accessOf({String? requestStatus, String? memberStatus}) {
  if (memberStatus == 'active') return StaffAccess.active;
  if (memberStatus == 'removed') return StaffAccess.removed;
  return switch (requestStatus) {
    'pending' => StaffAccess.pending,
    'rejected' => StaffAccess.rejected,
    // Approved but the member record isn't there yet: still waiting.
    'approved' => StaffAccess.pending,
    _ => StaffAccess.none,
  };
}
