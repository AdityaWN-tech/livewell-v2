import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/track_models.dart';

/// Evening reflections, one document per local date
/// (users/{uid}/reflections/{date}).
abstract class ReflectionRepository {
  Stream<Reflection?> watchDay(String date);

  /// Saves (or re-saves) [reflection]. Works offline: the write is queued.
  Future<void> save(Reflection reflection);
}

/// Firestore implementation, offline through Firestore's persistence.
/// TODO(T-FND-08): move to the encrypted local database with its sync queue.
class FirestoreReflectionRepository implements ReflectionRepository {
  FirestoreReflectionRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  static const serverWait = Duration(seconds: 3);

  DocumentReference<Map<String, dynamic>> _doc(String date) =>
      _db.collection('users').doc(_uid()).collection('reflections').doc(date);

  @override
  Stream<Reflection?> watchDay(String date) => _doc(date).snapshots().map(
    (s) => s.data() == null
        ? null
        : Reflection(date: date, text: s.data()!['text'] as String),
  );

  @override
  Future<void> save(Reflection r) async {
    final ref = _doc(r.date);
    final fields = <String, Object>{
      'text': r.text,
      'prompt': 'went_well',
      'source': 'app',
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': 1,
    };
    // Same pattern as check-ins: a same-day edit merges and never sends
    // created_at, so the first one is kept (the rules require it).
    final write = await _exists(ref)
        ? ref.set(fields, SetOptions(merge: true))
        : ref.set({...fields, 'created_at': FieldValue.serverTimestamp()});
    await write.timeout(serverWait, onTimeout: () {});
  }

  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get().timeout(serverWait)).exists;
    } catch (_) {
      try {
        return (await ref.get(const GetOptions(source: Source.cache))).exists;
      } on FirebaseException {
        return false;
      }
    }
  }
}

/// Keeps reflections in memory only, for the dev preview (nothing is saved).
class InMemoryReflectionRepository implements ReflectionRepository {
  final _days = <String, Reflection>{};
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<Reflection?> watchDay(String date) async* {
    yield _days[date];
    yield* _changes.stream.where((d) => d == date).map((d) => _days[d]);
  }

  @override
  Future<void> save(Reflection r) async {
    _days[r.date] = r;
    _changes.add(r.date);
  }
}

final _previewReflectionsProvider = Provider<ReflectionRepository>(
  (ref) => InMemoryReflectionRepository(),
);

final reflectionRepositoryProvider = Provider<ReflectionRepository>((ref) {
  if (ref.watch(previewModeProvider)) {
    return ref.watch(_previewReflectionsProvider);
  }
  final auth = ref.watch(authServiceProvider);
  return FirestoreReflectionRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
