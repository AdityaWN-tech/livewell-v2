/// Staff access on the free plan (D-112): a person asks, a Superadmin
/// approves. The Firestore rules enforce every step; this is the app's view.
library;

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
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;

  /// active or removed.
  final String status;
  final DateTime? updatedAt;

  bool get active => status == 'active';
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
    _ => action,
  };
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
