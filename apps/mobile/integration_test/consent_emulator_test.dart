import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/data/firestore.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/firebase/firebase_options.dart';

/// T-FND-05 end to end, on a device, against the local emulators. Proves the
/// app's consent records pass the real firestore.rules. Auth, Firestore and
/// Functions are all emulated, so the real project is never touched; the
/// emulators use the dev project id because Android starts Firebase natively
/// from google-services.json before Dart runs. Run from the repo root:
///
///   firebase emulators:exec --only auth,firestore,functions
///     --project my-livewell
///     "cd apps/mobile && flutter test integration_test/consent_emulator_test.dart
///      --flavor dev -d emulator-5554"
///
/// The Android emulator reaches the computer at 10.0.2.2.
const host = '10.0.2.2';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FirebaseFirestore db;
  late String uid;

  setUpAll(() async {
    await Firebase.initializeApp(options: firebaseOptionsFor(Flavor.dev));
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    container = ProviderContainer(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
    );
    db = container.read(firestoreProvider);
    db.useFirestoreEmulator(host, 8080);

    uid = (await FirebaseAuth.instance.signInAnonymously()).user!.uid;
    final now = FieldValue.serverTimestamp();
    await db.doc('users/$uid').set({
      'display_name': 'Test',
      'age_confirmed': true,
      'created_at': now,
      'updated_at': now,
      'schema_version': 1,
    });
  });

  tearDownAll(() => container.dispose());

  testWidgets('grant and revoke every consent type through the real rules', (
    tester,
  ) async {
    final repo = container.read(consentRepositoryProvider);

    for (final type in ConsentType.values) {
      await repo.record(type, granted: true);
      if (!type.required) await repo.record(type, granted: false);
    }

    final records = await repo.watchRecords().firstWhere(
      (r) =>
          r.length == ConsentType.values.length + ConsentType.granular.length,
    );
    final current = currentConsents(records);
    for (final type in ConsentType.values) {
      expect(isGranted(current, type), type.required, reason: type.key);
      expect(current[type]!.docVersion, ConsentTexts.versionOf(type));
      expect(current[type]!.createdAt, isNotNull, reason: 'server time');
    }
  });

  testWidgets('the rules refuse to edit or delete a consent record', (
    tester,
  ) async {
    final snap = await db.collection('users/$uid/consents').limit(1).get();
    final ref = snap.docs.single.reference;
    await expectLater(
      ref.update({'granted': false}),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    await expectLater(
      ref.delete(),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });
}
