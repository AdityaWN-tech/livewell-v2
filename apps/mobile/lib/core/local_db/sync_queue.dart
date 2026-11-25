import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'local_database.dart';

/// How a remote write went.
enum RemoteOutcome {
  /// Stored on the server (or already there: same document, same values).
  done,

  /// No network, timeout or a server hiccup: try again later.
  retryLater,

  /// The server refused it (rules, validation): retrying won't help.
  rejected,
}

/// Sends one queued record to the server. Must be idempotent: applying the
/// same entry twice leaves the server exactly as applying it once (the
/// Firestore writer targets the record's own document id).
abstract class RemoteWriter {
  /// Returns the outcome and, when not [RemoteOutcome.done], an error code
  /// (a code only, never content).
  Future<(RemoteOutcome, String?)> apply(OutboxEntry entry);
}

/// The result of one flush, as counts only (safe to log).
class FlushResult {
  const FlushResult({
    required this.sent,
    required this.remaining,
    required this.parked,
    required this.offline,
  });

  final int sent;
  final int remaining;
  final int parked;

  /// Stopped early because the server could not be reached.
  final bool offline;

  @override
  String toString() =>
      'FlushResult(sent: $sent, remaining: $remaining, parked: $parked, '
      'offline: $offline)';
}

/// The offline sync queue (T-FND-08, NFR-05) on the encrypted database.
class SyncQueue {
  SyncQueue(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final LocalDatabase _db;
  final DateTime Function() _now;

  /// Queues [fields] for [docPath]. If [idempotencyKey] is already queued,
  /// its values are replaced (last writer wins) and its revision goes up;
  /// there is never more than one queued write per record. Call inside the
  /// same transaction as the local write so both happen or neither.
  Future<void> enqueue({
    required String idempotencyKey,
    required String uid,
    required String kind,
    required String docPath,
    required Map<String, Object?> fields,
  }) async {
    final now = _now();
    final json = jsonEncode(fields);
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.syncOutbox)
                ..where((o) => o.idempotencyKey.equals(idempotencyKey)))
              .getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                idempotencyKey: idempotencyKey,
                uid: uid,
                kind: kind,
                docPath: docPath,
                fields: json,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_db.update(
          _db.syncOutbox,
        )..where((o) => o.id.equals(existing.id))).write(
          SyncOutboxCompanion(
            fields: Value(json),
            revision: Value(existing.revision + 1),
            // A new value deserves a new try, even if the old one was refused.
            parked: const Value(false),
            attempts: const Value(0),
            lastError: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Whether [idempotencyKey] is still waiting to sync.
  Future<bool> isPending(String idempotencyKey) async =>
      await (_db.select(_db.syncOutbox)
            ..where((o) => o.idempotencyKey.equals(idempotencyKey)))
          .getSingleOrNull() !=
      null;

  /// Everything queued for [uid], oldest first (including parked entries).
  Future<List<OutboxEntry>> entries(String uid) =>
      (_db.select(_db.syncOutbox)
            ..where((o) => o.uid.equals(uid))
            ..orderBy([(o) => OrderingTerm.asc(o.id)]))
          .get();

  /// Sends [uid]'s queued writes, oldest first, through [remote]. An entry
  /// is removed only after the server confirmed it, and only if it wasn't
  /// replaced meanwhile (then the newer values go on the next flush). Stops
  /// at the first "try later", so order is kept.
  Future<FlushResult> flush(String uid, RemoteWriter remote) async {
    var sent = 0;
    var parked = 0;
    var offline = false;
    final queue =
        await (_db.select(_db.syncOutbox)
              ..where((o) => o.uid.equals(uid) & o.parked.equals(false))
              ..orderBy([(o) => OrderingTerm.asc(o.id)]))
            .get();
    for (final entry in queue) {
      final (RemoteOutcome outcome, String? code) result;
      try {
        result = await remote.apply(entry);
      } catch (_) {
        // A writer bug or an unexpected error: keep the entry, try later.
        await _failed(entry, 'error', park: false);
        offline = true;
        break;
      }
      switch (result.$1) {
        case RemoteOutcome.done:
          await (_db.delete(_db.syncOutbox)..where(
                (o) =>
                    o.id.equals(entry.id) & o.revision.equals(entry.revision),
              ))
              .go();
          sent++;
        case RemoteOutcome.rejected:
          await _failed(entry, result.$2 ?? 'rejected', park: true);
          parked++;
        case RemoteOutcome.retryLater:
          await _failed(entry, result.$2 ?? 'unavailable', park: false);
          offline = true;
      }
      if (offline) break;
    }
    final remaining =
        await (_db.selectOnly(_db.syncOutbox)
              ..addColumns([_db.syncOutbox.id.count()])
              ..where(
                _db.syncOutbox.uid.equals(uid) &
                    _db.syncOutbox.parked.equals(false),
              ))
            .map((r) => r.read(_db.syncOutbox.id.count()) ?? 0)
            .getSingle();
    return FlushResult(
      sent: sent,
      remaining: remaining,
      parked: parked,
      offline: offline,
    );
  }

  Future<void> _failed(OutboxEntry entry, String code, {required bool park}) =>
      (_db.update(_db.syncOutbox)..where(
            (o) => o.id.equals(entry.id) & o.revision.equals(entry.revision),
          ))
          .write(
            SyncOutboxCompanion(
              attempts: Value(entry.attempts + 1),
              lastError: Value(code),
              parked: Value(park),
              updatedAt: Value(_now()),
            ),
          );

  /// Decoded fields of [entry].
  static Map<String, Object?> fieldsOf(OutboxEntry entry) =>
      (jsonDecode(entry.fields) as Map).cast<String, Object?>();
}

/// Runs the queue: after each save, when the app comes back to the
/// foreground, and on a back-off timer while writes are waiting (5 s
/// doubling to 5 min). No connectivity plugin: a failed attempt is the
/// signal, and the back-off keeps battery use low (NFR-08).
class SyncEngine {
  SyncEngine({
    required this._queue,
    required this._remote,
    required this._uid,
    bool listenToLifecycle = true,
  }) {
    if (listenToLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: kick);
    }
  }

  final SyncQueue _queue;
  final RemoteWriter _remote;
  final String? Function() _uid;
  AppLifecycleListener? _lifecycle;
  Future<FlushResult?>? _running;
  bool _again = false;
  Timer? _retry;
  int _failures = 0;
  bool _disposed = false;

  static const firstRetry = Duration(seconds: 5);
  static const maxRetry = Duration(minutes: 5);

  /// Back-off after [failures] failed flushes in a row.
  static Duration backoff(int failures) {
    final ms = firstRetry.inMilliseconds * pow(2, max(0, failures - 1));
    return Duration(milliseconds: min(ms.toInt(), maxRetry.inMilliseconds));
  }

  /// Starts a flush soon (does not wait for it).
  void kick() {
    unawaited(flushNow());
  }

  /// Flushes now. Only one flush runs at a time; a call during a flush
  /// makes it run once more at the end, so nothing saved meanwhile waits
  /// for the timer.
  Future<FlushResult?> flushNow() {
    if (_disposed) return Future.value();
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _run();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<FlushResult?> _run() async {
    FlushResult? result;
    do {
      _again = false;
      final uid = _uid();
      if (uid == null) return null;
      result = await _queue.flush(uid, _remote);
      // Saved again meanwhile (a newer revision) or more came in: go on
      // while the server is reachable and the queue moves.
    } while (!_disposed &&
        !result.offline &&
        (_again || (result.sent > 0 && result.remaining > 0)));
    _retry?.cancel();
    if (_disposed) return result;
    if (result.offline) {
      _failures++;
      _retry = Timer(backoff(_failures), kick);
    } else {
      _failures = 0;
    }
    return result;
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _lifecycle?.dispose();
  }
}
