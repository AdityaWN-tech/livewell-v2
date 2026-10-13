import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/flavor.dart';

/// The only way app code gets Firestore. It names the flavor's database
/// explicitly (D-16), so a project with a differently named or second database
/// can never be hit by accident. Enforced by test/data/firestore_guard_test.dart.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final flavor = ref.watch(flavorProvider);
  return FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: flavor.firestoreDatabaseId!,
  );
});
