import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/data/firestore.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/consent.dart';

/// Append-only consent store (T-FND-05). Grant and revoke both *add* a
/// record; nothing is ever updated or deleted (enforced by firestore.rules).
abstract class ConsentRepository {
  /// All of the signed-in user's consent records, live.
  Stream<List<ConsentRecord>> watchRecords();

  /// Adds a record for [type] with the current text version.
  Future<void> record(ConsentType type, {required bool granted});
}

class FirestoreConsentRepository implements ConsentRepository {
  FirestoreConsentRepository(this._db, this._auth, this._appVersion);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Future<String> Function() _appVersion;

  CollectionReference<Map<String, dynamic>> _consents() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Consents need a signed-in user.');
    }
    return _db.collection('users').doc(uid).collection('consents');
  }

  @override
  Stream<List<ConsentRecord>> watchRecords() => _consents()
      .orderBy('created_at')
      .snapshots()
      // A record saved offline has no server time yet; currentConsents()
      // treats it as the newest, so the switch updates immediately.
      .map((s) => [for (final d in s.docs) ?_fromDoc(d.data())]);

  @override
  Future<void> record(ConsentType type, {required bool granted}) async {
    final now = FieldValue.serverTimestamp();
    await _consents().add({
      'type': type.key,
      'doc_version': ConsentTexts.versionOf(type),
      'granted': granted,
      'app_version': await _appVersion(),
      'created_at': now,
      'updated_at': now,
      'schema_version': 1,
    });
  }

  static ConsentRecord? _fromDoc(Map<String, dynamic> d) {
    final type = ConsentType.fromKey(d['type'] as String? ?? '');
    if (type == null) return null; // unknown type from a newer app version
    return ConsentRecord(
      type: type,
      docVersion: d['doc_version'] as String? ?? '',
      granted: d['granted'] as bool? ?? false,
      appVersion: d['app_version'] as String? ?? '',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  if (ref.watch(previewModeProvider)) return InMemoryConsentRepository();
  return FirestoreConsentRepository(
    ref.watch(firestoreProvider),
    FirebaseAuth.instance,
    () async => (await PackageInfo.fromPlatform()).version,
  );
});

/// Current decision per consent type.
final currentConsentsProvider = StreamProvider<Map<ConsentType, ConsentRecord>>(
  (ref) =>
      ref.watch(consentRepositoryProvider).watchRecords().map(currentConsents),
);
