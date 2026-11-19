import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/firestore.dart';
import '../../../core/local_db/local_database.dart';
import '../../../core/local_db/local_db_providers.dart';
import '../../../core/local_db/sync_queue.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/checkin.dart';

/// Check-ins, one document per local date (idempotent by date).
abstract class CheckInRepository {
  Stream<CheckIn?> watchDay(String date);

  /// Saves (or re-saves) [checkIn]. Works offline: the write is queued and
  /// synced later.
  Future<void> save(CheckIn checkIn);

  /// Check-ins from [from] to [to] (YYYY-MM-DD, inclusive), oldest first,
  /// for Track (T-UI-02e). Offline: what the phone has.
  Future<List<CheckIn>> range(String from, String to);
}

/// Shared by the in-memory stores.
List<CheckIn> checkInsBetween(Iterable<CheckIn> all, String from, String to) =>
    all
        .where((c) => c.date.compareTo(from) >= 0 && c.date.compareTo(to) <= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

/// Firestore implementation. The app uses it only to read the server copy
/// (see [LocalFirstCheckInRepository]); saving goes through the encrypted
/// local database and its sync queue (T-FND-08).
class FirestoreCheckInRepository implements CheckInRepository {
  FirestoreCheckInRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  /// How long to wait for the server before treating a save as queued.
  static const serverWait = Duration(seconds: 3);

  DocumentReference<Map<String, dynamic>> _doc(String date) =>
      _db.collection('users').doc(_uid()).collection('checkins').doc(date);

  static CheckIn? _from(String date, Map<String, dynamic>? d) => d == null
      ? null
      : CheckIn(
          date: date,
          mood: d['mood'] as int,
          energy: d['energy'] as int?,
          sleep: d['sleep'] as int?,
          stress: d['stress'] as int?,
          timeAvailable: d['time_available'] as int?,
          barrierText: d['barrier_text'] as String?,
          gentleDay: d['gentle_day'] as bool? ?? false,
          createdAt: (d['created_at'] as Timestamp?)?.toDate(),
        );

  @override
  Stream<CheckIn?> watchDay(String date) =>
      _doc(date).snapshots().map((s) => _from(date, s.data()));

  @override
  Future<List<CheckIn>> range(String from, String to) async {
    final query = _db
        .collection('users')
        .doc(_uid())
        .collection('checkins')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
        .where(FieldPath.documentId, isLessThanOrEqualTo: to);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.get().timeout(serverWait);
    } catch (_) {
      snap = await query.get(const GetOptions(source: Source.cache));
    }
    return [for (final d in snap.docs) ?_from(d.id, d.data())]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> save(CheckIn c) async {
    final ref = _doc(c.date);
    final answers = <String, Object>{
      'mood': c.mood,
      // A skipped answer on a re-submit clears the earlier one.
      'energy': c.energy ?? FieldValue.delete(),
      'sleep': c.sleep ?? FieldValue.delete(),
      'stress': c.stress ?? FieldValue.delete(),
      'time_available': c.timeAvailable ?? FieldValue.delete(),
      'barrier_text': c.barrierText ?? FieldValue.delete(),
      'source': 'app',
      'gentle_day': c.gentleDay,
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': 1,
    };
    final Future<void> write;
    if (await _exists(ref)) {
      // Same-day re-submit: merge, and never send created_at, so the first
      // one is kept (the rules require it). Sending a new created_at here
      // made a second offline save fail when it synced.
      write = ref.set(answers, SetOptions(merge: true));
    } else {
      write = ref.set({
        for (final e in answers.entries)
          if (e.value is! FieldValue || e.key == 'updated_at') e.key: e.value,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    // Offline, the write stays queued and the local copy updates at once;
    // don't keep the user waiting for the network.
    await write.timeout(serverWait, onTimeout: () {});
  }

  /// Whether today's check-in already exists: asks the server when online,
  /// and falls back to the phone's copy (including writes still waiting to
  /// sync) when offline.
  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final snap = await ref.get().timeout(serverWait);
      return snap.exists;
    } catch (_) {
      try {
        return (await ref.get(const GetOptions(source: Source.cache))).exists;
      } on FirebaseException {
        return false;
      }
    }
  }
}

/// Offline-first check-ins (T-FND-08, NFR-05). A save goes into the
/// encrypted local database and the sync queue in one transaction, so it is
/// instant and survives a restart; the queue sends it when the server can
/// be reached. Reads come from the local database, refreshed from the
/// server copy unless a local change is still waiting to sync (the phone's
/// newer value wins until it is sent; last writer wins).
class LocalFirstCheckInRepository implements CheckInRepository {
  LocalFirstCheckInRepository({
    required this._db,
    required this._queue,
    required this._remote,
    required this._uid,
    void Function()? onQueued,
    DateTime Function()? now,
  }) : _onQueued = onQueued ?? (() {}),
       _now = now ?? DateTime.now;

  final LocalDatabase _db;
  final SyncQueue _queue;
  final CheckInRepository _remote;
  final String Function() _uid;
  final void Function() _onQueued;
  final DateTime Function() _now;

  /// How long a read waits for the server copy before showing the local one.
  static const remoteWait = Duration(seconds: 3);

  /// The outbox key: one queued write per person and day.
  static String idempotencyKey(String uid, String date) => 'checkin:$uid:$date';

  static CheckIn _toDomain(LocalCheckIn r) => CheckIn(
    date: r.date,
    mood: r.mood,
    energy: r.energy,
    sleep: r.sleep,
    stress: r.stress,
    timeAvailable: r.timeAvailable,
    barrierText: r.barrierText,
    gentleDay: r.gentleDay,
    createdAt: r.createdAt,
  );

  LocalCheckInsCompanion _row(String uid, CheckIn c, DateTime? createdAt) =>
      LocalCheckInsCompanion.insert(
        uid: uid,
        date: c.date,
        mood: c.mood,
        energy: Value(c.energy),
        sleep: Value(c.sleep),
        stress: Value(c.stress),
        timeAvailable: Value(c.timeAvailable),
        barrierText: Value(c.barrierText),
        gentleDay: c.gentleDay,
        createdAt: Value(createdAt),
        updatedAt: _now(),
      );

  @override
  Future<void> save(CheckIn c) async {
    final uid = _uid();
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.localCheckIns)
                ..where((r) => r.uid.equals(uid) & r.date.equals(c.date)))
              .getSingleOrNull();
      await _db
          .into(_db.localCheckIns)
          .insertOnConflictUpdate(
            _row(uid, c, existing?.createdAt ?? c.createdAt ?? _now()),
          );
      await _queue.enqueue(
        idempotencyKey: idempotencyKey(uid, c.date),
        uid: uid,
        kind: 'checkin',
        docPath: 'users/$uid/checkins/${c.date}',
        fields: {
          'mood': c.mood,
          // Null: a skipped answer on a re-submit clears the earlier one.
          'energy': c.energy,
          'sleep': c.sleep,
          'stress': c.stress,
          'time_available': c.timeAvailable,
          'barrier_text': c.barrierText,
          'source': 'app',
          'gentle_day': c.gentleDay,
          'schema_version': 1,
        },
      );
    });
    _onQueued();
  }

  /// Copies the server's [c] into the local database, unless a local
  /// change for that day is still waiting to sync.
  Future<void> _adopt(String uid, CheckIn c) async {
    if (await _queue.isPending(idempotencyKey(uid, c.date))) return;
    await _db
        .into(_db.localCheckIns)
        .insertOnConflictUpdate(_row(uid, c, c.createdAt));
  }

  Future<void> _refreshDay(String uid, String date) async {
    try {
      final server = await _remote.watchDay(date).first.timeout(remoteWait);
      if (server != null) await _adopt(uid, server);
    } catch (_) {
      // Offline: the local copy is what we have.
    }
  }

  @override
  Stream<CheckIn?> watchDay(String date) {
    final uid = _uid();
    unawaited(_refreshDay(uid, date));
    return (_db.select(_db.localCheckIns)
          ..where((r) => r.uid.equals(uid) & r.date.equals(date)))
        .watchSingleOrNull()
        .map((r) => r == null ? null : _toDomain(r));
  }

  @override
  Future<List<CheckIn>> range(String from, String to) async {
    final uid = _uid();
    try {
      for (final c in await _remote.range(from, to)) {
        await _adopt(uid, c);
      }
    } catch (_) {
      // Offline: the local copy is what we have.
    }
    final rows =
        await (_db.select(_db.localCheckIns)..where(
              (r) =>
                  r.uid.equals(uid) &
                  r.date.isBiggerOrEqualValue(from) &
                  r.date.isSmallerOrEqualValue(to),
            ))
            .get();
    return checkInsBetween(rows.map(_toDomain), from, to);
  }
}

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  if (ref.watch(previewModeProvider)) {
    return ref.watch(previewCheckInRepositoryProvider);
  }
  final auth = ref.watch(authServiceProvider);
  String uid() => auth.currentUser!.uid;
  final engine = ref.watch(syncEngineProvider);
  return LocalFirstCheckInRepository(
    db: ref.watch(localDatabaseProvider),
    queue: ref.watch(syncQueueProvider),
    remote: FirestoreCheckInRepository(ref.watch(firestoreProvider), uid),
    uid: uid,
    onQueued: engine.kick,
  );
});

/// Remembers the last day the check-in sheet was shown, so it is asked once
/// per day only. A trivial UI flag (spec 10.4 allows SharedPreferences).
abstract class CheckInPromptStore {
  Future<String?> lastAskedDay();
  Future<void> markAsked(String day);
}

class SharedPrefsCheckInPromptStore implements CheckInPromptStore {
  static const _key = 'checkin_last_asked_day';

  @override
  Future<String?> lastAskedDay() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> markAsked(String day) async =>
      (await SharedPreferences.getInstance()).setString(_key, day);
}

final checkInPromptStoreProvider = Provider<CheckInPromptStore>(
  (ref) => SharedPrefsCheckInPromptStore(),
);
