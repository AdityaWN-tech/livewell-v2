import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/account_actions.dart';
import '../../firebase/firebase_options.dart';
import '../config/flavor.dart';

/// Firebase for this flavor, initialized once. Startup awaits it
/// (appStartupProvider) while the splash plays.
///
/// Providers that need Firebase watch this instead of calling
/// `Firebase.app()` directly. A provider created before Firebase is ready
/// (for example by the first frame) then fails only for that moment, and is
/// rebuilt automatically once this resolves, instead of keeping a
/// "no-app" error that broke every cold start.
final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) async {
  final flavor = ref.watch(flavorProvider);
  final app = await Firebase.initializeApp(
    options: firebaseOptionsFor(flavor)!,
  );
  // After a log out: clear the last account's offline Firestore copy before
  // anything can read it (T-ONB-03f). Done here, before this resolves, so no
  // provider can open Firestore first.
  if (await ref.read(localDataProvider).takeCachePending()) {
    try {
      await FirebaseFirestore.instanceFor(
        app: app,
        databaseId: flavor.firestoreDatabaseId!,
      ).clearPersistence();
    } catch (_) {
      // Already in use (should not happen here).
    }
  }
  return app;
});

/// The only way app code gets Firestore. It names the flavor's database
/// explicitly (D-16), so a project with a differently named or second database
/// can never be hit by accident. Enforced by test/data/firestore_guard_test.dart.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final flavor = ref.watch(flavorProvider);
  // Throws while Firebase is still starting; rebuilt when it is ready.
  final app = ref.watch(firebaseAppProvider).requireValue;
  return FirebaseFirestore.instanceFor(
    app: app,
    databaseId: flavor.firestoreDatabaseId!,
  );
});
