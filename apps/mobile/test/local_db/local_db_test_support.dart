import 'dart:io';

import 'package:livewell/core/local_db/encrypted_open.dart';
import 'package:livewell/core/local_db/local_database.dart';
import 'package:livewell/core/local_db/sync_queue.dart';
import 'package:livewell/features/checkin/data/checkin_repository.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';

/// The keystore, in memory.
class MemoryKeyStore implements DatabaseKeyStore {
  String? key;
  int writes = 0;
  int deletes = 0;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String k) async {
    writes++;
    key = k;
  }

  @override
  Future<void> delete() async {
    deletes++;
    key = null;
  }
}

/// A temp-file encrypted database (real SQLCipher, from the sqlite3 hook).
Future<LocalDatabase> openTestDatabase(
  File file,
  DatabaseKeyStore keys,
) async => LocalDatabase(
  await openEncryptedDatabase(file: file, keys: keys, background: false),
);

/// A stand-in for Firestore with the same semantics as
/// FirestoreRemoteWriter: one document per path; create adds created_at,
/// update merges (null removes) and keeps created_at.
class FakeServer implements RemoteWriter {
  bool online = true;

  /// Commits the write, then reports a timeout (the reply was lost).
  bool loseNextReply = false;

  /// Refuses writes to these paths (as the rules would).
  final refuse = <String>{};

  /// Runs inside [apply] before it returns (to simulate a save meanwhile).
  Future<void> Function()? during;

  final docs = <String, Map<String, Object?>>{};

  /// Writes that reached the server, by document path.
  final commits = <String, int>{};
  int attempts = 0;
  int _clock = 0;

  @override
  Future<(RemoteOutcome, String?)> apply(OutboxEntry entry) async {
    attempts++;
    if (!online) return (RemoteOutcome.retryLater, 'unavailable');
    if (refuse.contains(entry.docPath)) {
      return (RemoteOutcome.rejected, 'permission-denied');
    }
    final fields = SyncQueue.fieldsOf(entry);
    final now = ++_clock;
    final doc = docs[entry.docPath];
    if (doc == null) {
      docs[entry.docPath] = {
        for (final e in fields.entries)
          if (e.value != null) e.key: e.value,
        'created_at': now,
        'updated_at': now,
      };
    } else {
      for (final e in fields.entries) {
        if (e.value == null) {
          doc.remove(e.key);
        } else {
          doc[e.key] = e.value;
        }
      }
      doc['updated_at'] = now;
    }
    commits[entry.docPath] = (commits[entry.docPath] ?? 0) + 1;
    await during?.call();
    if (loseNextReply) {
      loseNextReply = false;
      return (RemoteOutcome.retryLater, 'timeout');
    }
    return (RemoteOutcome.done, null);
  }

  /// Check-in documents of [uid].
  Map<String, Map<String, Object?>> checkIns(String uid) => {
    for (final e in docs.entries)
      if (e.key.startsWith('users/$uid/checkins/'))
        e.key.split('/').last: e.value,
  };
}

/// Reads [FakeServer]'s check-ins, like FirestoreCheckInRepository does.
class FakeServerCheckIns implements CheckInRepository {
  FakeServerCheckIns(this.server, this.uid);

  final FakeServer server;
  final String uid;

  CheckIn? _get(String date) {
    if (!server.online) throw Exception('offline');
    final d = server.docs['users/$uid/checkins/$date'];
    if (d == null) return null;
    return CheckIn(
      date: date,
      mood: d['mood']! as int,
      energy: d['energy'] as int?,
      sleep: d['sleep'] as int?,
      stress: d['stress'] as int?,
      timeAvailable: d['time_available'] as int?,
      barrierText: d['barrier_text'] as String?,
      gentleDay: d['gentle_day']! as bool,
    );
  }

  @override
  Stream<CheckIn?> watchDay(String date) => Stream.value(_get(date));

  @override
  Future<List<CheckIn>> range(String from, String to) async {
    if (!server.online) throw Exception('offline');
    return checkInsBetween(
      [for (final date in server.checkIns(uid).keys) ?_get(date)],
      from,
      to,
    );
  }

  @override
  Future<void> save(CheckIn checkIn) => throw UnsupportedError('read only');
}
