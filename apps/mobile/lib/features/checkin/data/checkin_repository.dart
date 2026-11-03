import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/firestore.dart';
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

/// Firestore implementation. Offline support comes from Firestore's own
/// offline persistence for now.
/// TODO(T-FND-08): move check-ins into the encrypted local database
/// (Drift + SQLCipher) with its sync queue.
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

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  if (ref.watch(previewModeProvider)) {
    return ref.watch(previewCheckInRepositoryProvider);
  }
  final auth = ref.watch(authServiceProvider);
  return FirestoreCheckInRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
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
