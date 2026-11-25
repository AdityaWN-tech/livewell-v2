import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../local_db/local_database.dart';
import '../local_db/sync_queue.dart';

/// Writes queued records to Firestore (T-FND-08). Each record has its own
/// document id (the date for a check-in), so the write is idempotent: a
/// retry after a lost reply updates the same document, never adds one.
///
/// A transaction is used because it only succeeds once the server has the
/// write: offline it fails, and the entry stays queued. (A plain `set` would
/// "succeed" into Firestore's own offline cache.) Inside it:
/// - new document: the non-null fields + `created_at` + `updated_at`;
/// - existing document: merge, a null field is removed, `created_at` is
///   never sent (the rules keep the first one).
class FirestoreRemoteWriter implements RemoteWriter {
  FirestoreRemoteWriter(this._db);

  final FirebaseFirestore _db;

  static const timeout = Duration(seconds: 10);

  /// Codes where trying again can't help.
  static const _refused = {'permission-denied', 'invalid-argument'};

  @override
  Future<(RemoteOutcome, String?)> apply(OutboxEntry entry) async {
    final fields = SyncQueue.fieldsOf(entry);
    final ref = _db.doc(entry.docPath);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          tx.set(ref, {
            for (final e in fields.entries)
              e.key: e.value ?? FieldValue.delete(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          tx.set(ref, {
            for (final e in fields.entries)
              if (e.value != null) e.key: e.value,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }, timeout: timeout);
      return (RemoteOutcome.done, null);
    } on FirebaseException catch (e) {
      return (
        _refused.contains(e.code)
            ? RemoteOutcome.rejected
            : RemoteOutcome.retryLater,
        e.code,
      );
    } on TimeoutException {
      return (RemoteOutcome.retryLater, 'timeout');
    }
  }
}
