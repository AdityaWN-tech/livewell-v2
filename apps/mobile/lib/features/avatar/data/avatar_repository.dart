import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/coach_choice.dart';

/// users/{uid}/avatar/current (spec 11, T-AVT-08b). The app writes the
/// ready-made coach, the coach's name and the background; made-for-you
/// frame sets (`frames_version`), vendor ids and thumbnails are server
/// fields (firestore.rules).
abstract class AvatarRepository {
  Future<CoachChoice?> load();
  Future<void> save(CoachChoice choice);
}

class FirestoreAvatarRepository implements AvatarRepository {
  FirestoreAvatarRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(_uid()).collection('avatar').doc('current');

  @override
  Future<CoachChoice?> load() async {
    final data = (await _doc.get()).data();
    return data == null ? null : CoachChoice.fromMap(data);
  }

  @override
  Future<void> save(CoachChoice choice) async {
    final now = FieldValue.serverTimestamp();
    final fields = <String, Object>{...choice.toMap(), 'updated_at': now};
    final Future<void> write;
    bool exists;
    try {
      exists = (await _doc.get().timeout(const Duration(seconds: 3))).exists;
    } catch (_) {
      exists = false;
    }
    if (exists) {
      // Update only the fields the rules allow to change; no name: "Coach".
      write = _doc.update({
        ...fields,
        if (choice.coachName == null) 'coach_name': FieldValue.delete(),
      });
    } else {
      write = _doc.set({...fields, 'created_at': now, 'schema_version': 2});
    }
    // Offline: queued and synced later.
    await write.timeout(const Duration(seconds: 3), onTimeout: () {});
  }
}

/// Dev preview: kept in memory, nothing saved.
class InMemoryAvatarRepository implements AvatarRepository {
  CoachChoice? _saved;

  @override
  Future<CoachChoice?> load() async => _saved;

  @override
  Future<void> save(CoachChoice choice) async => _saved = choice;
}

final _previewAvatarProvider = Provider<AvatarRepository>(
  (ref) => InMemoryAvatarRepository(),
);

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  // Dev preview or nobody signed in: nothing to read or save.
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return ref.watch(_previewAvatarProvider);
  }
  return FirestoreAvatarRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
