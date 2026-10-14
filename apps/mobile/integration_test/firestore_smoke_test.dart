import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/data/firestore.dart';
import 'package:livewell/firebase/firebase_options.dart';

/// Runs on a device against the real dev project:
///   `flutter test integration_test/firestore_smoke_test.dart --flavor dev -d DEVICE`
/// Passes when the app reaches the dev `(default)` database. With locked rules the
/// read is refused (permission-denied), which still proves the connection;
/// a missing database fails with not-found.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dev app reaches Firestore database "(default)"', (tester) async {
    await Firebase.initializeApp(options: firebaseOptionsFor(Flavor.dev));
    final container = ProviderContainer(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
    );
    addTearDown(container.dispose);
    final db = container.read(firestoreProvider);

    String outcome;
    try {
      final snap = await db
          .doc('_smoke/ping')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      outcome = 'read-allowed exists=${snap.exists}';
    } on FirebaseException catch (e) {
      outcome = e.code;
    }
    // ignore: avoid_print
    print('FIRESTORE_SMOKE $outcome');
    expect(outcome, anyOf(startsWith('read-allowed'), 'permission-denied'));
  });
}
