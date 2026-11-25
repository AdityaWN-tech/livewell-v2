import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../domain/push.dart';

/// users/{uid}/devices/{installId}: where the server sends pushes
/// (T-TCH-01, D-77). Firestore rules allow exactly these fields.
abstract class DeviceRegistry {
  Future<void> save(String uid, String installId, DeviceRecord device);

  /// Removes the device (consent off, log out). Missing is fine.
  Future<void> remove(String uid, String installId);
}

class FirestoreDeviceRegistry implements DeviceRegistry {
  FirestoreDeviceRegistry(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String id) =>
      _db.collection('users').doc(uid).collection('devices').doc(id);

  @override
  Future<void> save(String uid, String installId, DeviceRecord d) =>
      _doc(uid, installId).set({
        'token': d.token,
        'platform': d.platform,
        'time_zone': d.timeZone,
        // A new registration each time (the token is the whole point).
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'schema_version': 1,
      });

  @override
  Future<void> remove(String uid, String installId) =>
      _doc(uid, installId).delete();
}

final deviceRegistryProvider = Provider<DeviceRegistry>(
  (ref) => FirestoreDeviceRegistry(ref.watch(firestoreProvider)),
);
