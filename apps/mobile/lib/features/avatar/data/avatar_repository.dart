import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/avatar_config.dart';

/// users/{uid}/avatar/current (spec 11). The app writes only the style;
/// vendor ids and thumbnails are server fields (firestore.rules).
abstract class AvatarRepository {
  Future<AvatarConfig?> load();
  Future<void> save(AvatarConfig config);
}

class FirestoreAvatarRepository implements AvatarRepository {
  FirestoreAvatarRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(_uid()).collection('avatar').doc('current');

  @override
  Future<AvatarConfig?> load() async {
    final snap = await _doc.get();
    final style = snap.data()?['style_config'];
    return style is Map<String, dynamic> ? AvatarConfig.fromMap(style) : null;
  }

  @override
  Future<void> save(AvatarConfig config) async {
    final now = FieldValue.serverTimestamp();
    final fields = <String, Object>{
      'type': 'stylized',
      'style_config': config.toMap(),
      // The selfie (if any) never leaves the phone and is already deleted.
      'raw_media_retained': false,
      'updated_at': now,
    };
    final Future<void> write;
    bool exists;
    try {
      exists = (await _doc.get().timeout(const Duration(seconds: 3))).exists;
    } catch (_) {
      exists = false;
    }
    if (exists) {
      // Update only the fields the rules allow to change.
      write = _doc.update(fields);
    } else {
      write = _doc.set({...fields, 'created_at': now, 'schema_version': 1});
    }
    // Offline: queued and synced later.
    await write.timeout(const Duration(seconds: 3), onTimeout: () {});
  }
}

/// Dev preview: kept in memory, nothing saved.
class InMemoryAvatarRepository implements AvatarRepository {
  AvatarConfig? _saved;

  @override
  Future<AvatarConfig?> load() async => _saved;

  @override
  Future<void> save(AvatarConfig config) async => _saved = config;
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
