import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/data/firestore.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/checkin/data/checkin_repository.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/firebase/firebase_options.dart';

/// T-DLY-02 integration: offline submit, then reconnect, syncs exactly once,
/// through the real firestore.rules on the local emulators. Run from the
/// repo root:
///
///   firebase emulators:exec --only auth,firestore,functions
///     --project my-livewell
///     "cd apps/mobile && flutter test integration_test/checkin_emulator_test.dart
///      --flavor dev -d emulator-5554"
const host = '10.0.2.2';
const day = '2026-10-14';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FirebaseFirestore db;
  late String uid;

  setUpAll(() async {
    await Firebase.initializeApp(options: firebaseOptionsFor(Flavor.dev));
    await fb.FirebaseAuth.instance.useAuthEmulator(host, 9099);
    container = ProviderContainer(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
    );
    db = container.read(firestoreProvider);
    db.useFirestoreEmulator(host, 8080);
    final email =
        'checkin-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: 'walk-after-lunch',
    );
    uid = cred.user!.uid;
    await container
        .read(profileRepositoryProvider)
        .create(uid, const NewProfile(onboardingStep: ProfileStep.assessment));
  });

  tearDownAll(() => container.dispose());

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  serverDocs() async =>
      (await db
              .collection('users/$uid/checkins')
              .get(const GetOptions(source: Source.server)))
          .docs;

  testWidgets('offline submit, then reconnect: synced exactly once', (_) async {
    final repo = container.read(checkInRepositoryProvider);

    await db.disableNetwork();
    // Offline: save returns (queued) instead of hanging.
    await repo.save(
      const CheckIn(date: day, mood: 4, stress: 2, gentleDay: false),
    );
    expect((await repo.watchDay(day).first)!.mood, 4, reason: 'local copy');
    // A second offline save the same day updates the same record.
    await repo.save(
      const CheckIn(
        date: day,
        mood: 5,
        stress: 2,
        timeAvailable: 10,
        gentleDay: false,
      ),
    );

    await db.enableNetwork();
    await db.waitForPendingWrites();

    final docs = await serverDocs();
    expect(docs, hasLength(1));
    expect(docs.single.id, day);
    expect(docs.single['mood'], 5);
    expect(docs.single['time_available'], 10);
    expect(docs.single['created_at'], isA<Timestamp>());
  });

  testWidgets('online re-submit keeps one record and its created_at', (
    _,
  ) async {
    final repo = container.read(checkInRepositoryProvider);
    final before = (await serverDocs()).single['created_at'] as Timestamp;

    await repo.save(const CheckIn(date: day, mood: 2, gentleDay: true));
    await db.waitForPendingWrites();

    final docs = await serverDocs();
    expect(docs, hasLength(1));
    expect(docs.single['mood'], 2);
    expect(docs.single['gentle_day'], isTrue);
    expect(docs.single['created_at'], before);
  });

  testWidgets('the rules refuse a low-mood day marked as not gentle', (
    _,
  ) async {
    await expectLater(
      db.doc('users/$uid/checkins/2026-10-15').set({
        'mood': 1,
        'source': 'app',
        'gentle_day': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'schema_version': 1,
      }),
      throwsA(isA<FirebaseException>()),
    );
  });
}
