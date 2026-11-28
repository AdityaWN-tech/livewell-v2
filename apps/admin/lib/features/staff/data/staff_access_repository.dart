import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/staff.dart';
import '../domain/staff_access.dart';

/// Requests, approvals and the activity log (D-112). The only place the
/// console talks to Firestore directly: on the free plan there are no Cloud
/// Functions, and the Firestore rules decide who may do what.
abstract class StaffAccessRepository {
  /// The signed-in person's state, live.
  Stream<StaffAccess> watch(String uid);

  /// "Request admin access" (or asking again after a no).
  Future<void> request({
    required String uid,
    required String email,
    required String name,
    required String reason,
    required bool again,
  });

  // Superadmin only (the rules refuse everyone else).
  Stream<List<StaffRequest>> pendingRequests();
  Stream<List<StaffMember>> members();
  Stream<List<StaffAuditEntry>> activity();
  Future<void> approve(StaffRequest r, {required String superUid});
  Future<void> reject(StaffRequest r, {required String superUid});
  Future<void> setActive(
    StaffMember m, {
    required bool active,
    required String superUid,
  });

  /// Gives an Admin their roles (D-118), with a log line.
  Future<void> setRoles(
    StaffMember m,
    Set<StaffRole> roles, {
    required String superUid,
  });

  /// Everyone who ever asked for access: uid -> "Name (email)", so the
  /// activity log can show people instead of ids. Superadmin only.
  Stream<Map<String, String>> people();

  /// The signed-in Admin's own roles, live (empty when not an Admin).
  Stream<Set<StaffRole>> myRoles(String uid);
}

class FirestoreStaffAccessRepository implements StaffAccessRepository {
  FirestoreStaffAccessRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('staff_requests');
  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('staff_members');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection('staff_audit');

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  @override
  Stream<StaffAccess> watch(String uid) {
    String? request;
    String? member;
    final out = StreamController<StaffAccess>();
    final subs = <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    void emit() =>
        out.add(accessOf(requestStatus: request, memberStatus: member));
    out.onListen = () {
      subs.add(
        _requests.doc(uid).snapshots().listen((s) {
          request = s.data()?['status'] as String?;
          emit();
        }, onError: (_) => emit()),
      );
      subs.add(
        _members.doc(uid).snapshots().listen((s) {
          member = s.data()?['status'] as String?;
          emit();
        }, onError: (_) => emit()),
      );
    };
    out.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return out.stream;
  }

  @override
  Future<void> request({
    required String uid,
    required String email,
    required String name,
    required String reason,
    required bool again,
  }) {
    final data = <String, Object>{
      'name': name.trim(),
      'reason': reason.trim(),
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    };
    return again
        ? _requests.doc(uid).update(data)
        : _requests.doc(uid).set({...data, 'email': email});
  }

  @override
  Stream<List<StaffRequest>> pendingRequests() => _requests
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            StaffRequest(
              uid: d.id,
              name: d['name'] as String? ?? '',
              email: d['email'] as String? ?? '',
              reason: d['reason'] as String? ?? '',
              status: d['status'] as String? ?? 'pending',
              createdAt: _date(d.data()['created_at']),
            ),
        ],
      );

  @override
  Stream<List<StaffMember>> members() => _members.snapshots().map(
    (q) => [
      for (final d in q.docs)
        StaffMember(
          uid: d.id,
          name: d['name'] as String? ?? '',
          email: d['email'] as String? ?? '',
          status: d['status'] as String? ?? 'active',
          roles: rolesFrom(d.data()['roles']),
          updatedAt: _date(d.data()['updated_at']),
        ),
    ]..sort((a, b) => a.email.compareTo(b.email)),
  );

  @override
  Stream<List<StaffAuditEntry>> activity() => _audit
      .orderBy('at', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            StaffAuditEntry(
              actor: d['actor'] as String? ?? '',
              action: d['action'] as String? ?? '',
              target: d['target'] as String? ?? '',
              at: _date(d.data()['at']),
            ),
        ],
      );

  Map<String, Object> _auditEntry(
    String superUid,
    String action,
    String target,
  ) => {
    'actor': superUid,
    'action': action,
    'target': target,
    'at': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> approve(StaffRequest r, {required String superUid}) async {
    // One batch: the decision, the new Admin and the log line together.
    final batch = _db.batch()
      ..update(_requests.doc(r.uid), {
        'status': 'approved',
        'decided_by': superUid,
        'decided_at': FieldValue.serverTimestamp(),
      })
      ..set(_members.doc(r.uid), {
        'email': r.email,
        'name': r.name,
        'role': 'admin',
        // New Admins write content; the Superadmin adds reviewer roles.
        'roles': [StaffRole.contentEditor.claim],
        'status': 'active',
        'approved_by': superUid,
        'updated_at': FieldValue.serverTimestamp(),
      })
      ..set(
        _audit.doc(),
        _auditEntry(superUid, 'staff.approved', 'staff_members/${r.uid}'),
      );
    await batch.commit();
  }

  @override
  Future<void> reject(StaffRequest r, {required String superUid}) async {
    final batch = _db.batch()
      ..update(_requests.doc(r.uid), {
        'status': 'rejected',
        'decided_by': superUid,
        'decided_at': FieldValue.serverTimestamp(),
      })
      ..set(
        _audit.doc(),
        _auditEntry(superUid, 'staff.rejected', 'staff_requests/${r.uid}'),
      );
    await batch.commit();
  }

  @override
  Future<void> setActive(
    StaffMember m, {
    required bool active,
    required String superUid,
  }) async {
    final batch = _db.batch()
      ..set(_members.doc(m.uid), {
        'email': m.email,
        'name': m.name,
        'role': 'admin',
        'roles': _roleList(m.roles),
        'status': active ? 'active' : 'removed',
        'approved_by': superUid,
        'updated_at': FieldValue.serverTimestamp(),
      })
      ..set(
        _audit.doc(),
        _auditEntry(
          superUid,
          active ? 'staff.restored' : 'staff.removed',
          'staff_members/${m.uid}',
        ),
      );
    await batch.commit();
  }

  static List<String> _roleList(Set<StaffRole> roles) => [
    for (final r in assignableRoles)
      if (roles.contains(r)) r.claim,
  ];

  @override
  Future<void> setRoles(
    StaffMember m,
    Set<StaffRole> roles, {
    required String superUid,
  }) async {
    final batch = _db.batch()
      ..set(_members.doc(m.uid), {
        'email': m.email,
        'name': m.name,
        'role': 'admin',
        'roles': _roleList(roles),
        'status': m.status,
        'approved_by': superUid,
        'updated_at': FieldValue.serverTimestamp(),
      })
      ..set(
        _audit.doc(),
        _auditEntry(superUid, 'staff.roles_changed', 'staff_members/${m.uid}'),
      );
    await batch.commit();
  }

  @override
  Stream<Map<String, String>> people() => _requests.snapshots().map(
    (q) => {
      for (final d in q.docs)
        d.id: '${d['name'] as String? ?? ''} (${d['email'] as String? ?? ''})',
    },
  );

  @override
  Stream<Set<StaffRole>> myRoles(String uid) => _members
      .doc(uid)
      .snapshots()
      .map(
        (s) => s.data()?['status'] == 'active'
            ? rolesFrom(s.data()?['roles'])
            : const <StaffRole>{},
      );
}

final staffAccessRepositoryProvider = Provider<StaffAccessRepository>(
  (ref) =>
      throw UnimplementedError('staffAccessRepositoryProvider not overridden'),
);

/// The signed-in person's access, live; null when signed out.
final staffAccessProvider = StreamProvider<StaffAccess?>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(null);
  if (session.superadmin) return Stream.value(StaffAccess.active);
  return ref.watch(staffAccessRepositoryProvider).watch(session.uid);
});

/// The signed-in person's staff roles (D-118); empty for a Superadmin who
/// is not also an Admin. Decides whether Approve shows; the rules decide
/// whether it works.
final myStaffRolesProvider = StreamProvider<Set<StaffRole>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return Stream.value(const <StaffRole>{});
  return ref.watch(staffAccessRepositoryProvider).myRoles(session.uid);
});
