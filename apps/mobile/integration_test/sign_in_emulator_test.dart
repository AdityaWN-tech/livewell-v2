import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/data/firestore.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/auth/data/firebase_auth_service.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/onboarding/data/onboarding_store.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:livewell/firebase/firebase_options.dart';

/// T-ONB-01 end to end on a device, against the local Auth and Firestore
/// emulators and the real firestore.rules (nothing touches the real project).
/// Run from the repo root:
///
///   firebase emulators:exec --only auth,firestore,functions
///     --project my-livewell
///     "cd apps/mobile && flutter test integration_test/sign_in_emulator_test.dart
///      --flavor dev -d emulator-5554"
const host = '10.0.2.2';
const project = 'my-livewell';

/// Onboarding finished up to sign-in, kept in memory for the test.
class _ReadyStore implements OnboardingStore {
  OnboardingProgress? saved = OnboardingProgress(
    step: OnboardingStep.signIn,
    adultConfirmedAt: DateTime.utc(2026, 10, 13, 8),
    legalAcceptedAt: {
      for (final t in legalDocuments) t: DateTime.utc(2026, 10, 13, 8, 5),
    },
  );

  @override
  Future<OnboardingProgress> load() async =>
      saved ?? const OnboardingProgress();
  @override
  Future<void> save(OnboardingProgress p) async => saved = p;
  @override
  Future<void> clear() async => saved = null;
}

/// The Auth emulator exposes the SMS codes it "sent".
Future<String> latestSmsCode(String phone) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(
      Uri.parse(
        'http://$host:9099/emulator/v1/projects/$project/verificationCodes',
      ),
    );
    final body = await (await req.close()).transform(utf8.decoder).join();
    final codes = (jsonDecode(body) as Map)['verificationCodes'] as List;
    return codes.lastWhere((c) => c['phoneNumber'] == phone)['code'] as String;
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FirebaseFirestore db;

  setUpAll(() async {
    await Firebase.initializeApp(options: firebaseOptionsFor(Flavor.dev));
    await fb.FirebaseAuth.instance.useAuthEmulator(host, 9099);
  });

  setUp(() async {
    await fb.FirebaseAuth.instance.signOut();
    container = ProviderContainer(
      overrides: [
        flavorProvider.overrideWithValue(Flavor.dev),
        onboardingStoreProvider.overrideWithValue(_ReadyStore()),
      ],
    );
    db = container.read(firestoreProvider);
    db.useFirestoreEmulator(host, 8080);
  });

  tearDown(() => container.dispose());

  Future<void> expectAccountCreated(String uid, {String? region}) async {
    final profile = await db.doc('users/$uid').get();
    expect(profile.exists, isTrue);
    expect(profile['age_confirmed'], isTrue);
    expect(profile['onboarding_step'], 'why');
    if (region != null) expect(profile['region'], region);

    final consents = await db.collection('users/$uid/consents').get();
    final types = consents.docs.map((d) => d['type'] as String).toSet();
    expect(types, legalDocuments.map((t) => t.key).toSet());
    for (final d in consents.docs) {
      expect(d['granted'], isTrue);
      expect(d['granted_at'], isA<Timestamp>());
      expect(d['created_at'], isA<Timestamp>());
    }
  }

  testWidgets('email sign-up creates the profile and legal consents', (
    _,
  ) async {
    final auth = container.read(authServiceProvider);
    final email = 'e2e-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final user = await auth.createAccountWithEmail(email, 'walk-after-lunch');

    final next = await container.read(signInCompletionProvider).complete(user);
    expect(next, '/home');
    await expectAccountCreated(user.uid);

    // Signing in again on the same account goes straight to Home.
    await auth.signOut();
    final again = await auth.signInWithEmail(email, 'walk-after-lunch');
    expect(
      await container.read(signInCompletionProvider).complete(again),
      '/home',
    );
  });

  testWidgets('wrong password is reported, not crashed', (_) async {
    final auth = container.read(authServiceProvider);
    final email =
        'e2e-wrong-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await auth.createAccountWithEmail(email, 'right-password');
    await auth.signOut();
    await expectLater(
      auth.signInWithEmail(email, 'wrong-password'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.failure,
          'failure',
          AuthFailure.wrongCredentials,
        ),
      ),
    );
  });

  testWidgets('phone OTP (+91) signs in and records region IN', (_) async {
    final auth = container.read(authServiceProvider);
    final n = DateTime.now().millisecondsSinceEpoch % 100000000;
    final phone = '+919${n.toString().padLeft(9, '0')}';
    final v = await auth.startPhoneSignIn(phone);
    final code = await latestSmsCode(phone);
    final user = await auth.confirmPhoneCode(v, code);
    expect(user.phoneNumber, phone);

    expect(
      await container.read(signInCompletionProvider).complete(user),
      '/home',
    );
    await expectAccountCreated(user.uid, region: 'IN');
  });
}
