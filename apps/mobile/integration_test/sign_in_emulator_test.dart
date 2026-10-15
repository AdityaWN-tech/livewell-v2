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
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/data/firebase_auth_service.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/voice/data/voice_repository.dart';
import 'package:livewell/features/voice/domain/voice.dart';
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
    expect(profile['onboarding_step'], 'avatar');
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
    expect(next, avatarPath, reason: 'new accounts create their coach next');
    await expectAccountCreated(user.uid);

    // Save the Why through the real rules (FR-ONB-05); the account is then
    // past onboarding, so signing in again goes straight to Home.
    final profiles = container.read(profileRepositoryProvider);
    await profiles.saveWhy(
      user.uid,
      'Energy to travel with my family.',
      nextStep: ProfileStep.assessment,
    );
    expect(
      (await profiles.get(user.uid))!.whyStatement,
      'Energy to travel with my family.',
    );

    await auth.signOut();
    final again = await auth.signInWithEmail(email, 'walk-after-lunch');
    expect(
      await container.read(signInCompletionProvider).complete(again),
      '/home',
    );

    // A Why over 280 characters is refused by the rules.
    await expectLater(
      profiles.saveWhy(again.uid, 'x' * 281, nextStep: ProfileStep.assessment),
      throwsA(isA<FirebaseException>()),
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
      avatarPath,
    );
    await expectAccountCreated(user.uid, region: 'IN');
  });

  // T-ONB-03a: Google one tap. The Auth emulator accepts an unsigned Google
  // ID token, so the provider's browser step is replaced by that credential.
  FirebaseAuthService googleAs(String sub, String email) => FirebaseAuthService(
    fb.FirebaseAuth.instance,
    (_) => fb.FirebaseAuth.instance.signInWithCredential(
      fb.GoogleAuthProvider.credential(
        idToken: jsonEncode({
          'sub': sub,
          'email': email,
          'email_verified': true,
          'name': 'Priya Test',
        }),
      ),
    ),
  );

  testWidgets('Google, new person: one tap signs up and sets up the account', (
    _,
  ) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final auth = googleAs('g-$id', 'g-$id@example.com');
    final user = await auth.signInWithGoogle();
    expect(user.email, 'g-$id@example.com');
    expect(
      await container.read(signInCompletionProvider).complete(user),
      avatarPath,
    );
    await expectAccountCreated(user.uid);
  });

  testWidgets('Google, existing person: one tap signs in, nothing redone', (
    _,
  ) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final auth = googleAs('g-$id', 'g-$id@example.com');
    final first = await auth.signInWithGoogle();
    await container.read(signInCompletionProvider).complete(first);
    await container
        .read(profileRepositoryProvider)
        .saveWhy(
          first.uid,
          'Energy to travel with my family.',
          nextStep: ProfileStep.assessment,
        );
    final created = (await db.doc('users/${first.uid}').get())['created_at'];
    final consents =
        (await db.collection('users/${first.uid}/consents').get()).size;

    await auth.signOut();
    final again = await auth.signInWithGoogle();
    expect(again.uid, first.uid, reason: 'same account, not a new one');
    expect(
      await container.read(signInCompletionProvider).complete(again),
      '/home',
    );
    final profile = await db.doc('users/${first.uid}').get();
    expect(profile['created_at'], created);
    expect(
      (await db.collection('users/${first.uid}/consents').get()).size,
      consents,
      reason: 'no duplicate consent records',
    );
  });

  testWidgets('cancelled Google sign-in is reported as cancelled', (_) async {
    final auth = FirebaseAuthService(
      fb.FirebaseAuth.instance,
      (_) => throw fb.FirebaseAuthException(code: 'web-context-canceled'),
    );
    await expectLater(
      auth.signInWithGoogle(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.failure,
          'failure',
          AuthFailure.cancelled,
        ),
      ),
    );
    expect(fb.FirebaseAuth.instance.currentUser, isNull);
  });

  testWidgets('avatar saves through the real rules, then restyles', (_) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final user = await googleAs(
      'a-$id',
      'a-$id@example.com',
    ).signInWithGoogle();
    await container.read(signInCompletionProvider).complete(user);
    final avatars = container.read(avatarRepositoryProvider);

    await avatars.save(AvatarConfig.forLook(AvatarLook.woman));
    final first = await db.doc('users/${user.uid}/avatar/current').get();
    expect(first['type'], 'stylized');
    expect(first['raw_media_retained'], isFalse);
    expect(first['style_config']['look'], 'woman');

    // A second save is an update the rules allow (created_at untouched).
    await avatars.save(
      AvatarConfig.fallback.copyWith(skin: 9, headCovering: HeadCovering.hijab),
    );
    final second = await db.doc('users/${user.uid}/avatar/current').get();
    expect(second['style_config']['skin'], 9);
    expect(second['style_config']['head_covering'], 'hijab');
    expect(second['created_at'], first['created_at']);
    expect((await avatars.load())!.skin, 9);
  });

  testWidgets('library voice: chosen, then switched, one active (rules)', (
    _,
  ) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final user = await googleAs(
      'v-$id',
      'v-$id@example.com',
    ).signInWithGoogle();
    await container.read(signInCompletionProvider).complete(user);
    final voices = container.read(voiceRepositoryProvider);

    await voices.choose(VoiceChoice.fallback);
    await voices.choose(
      const VoiceChoice(
        voiceId: 'lw-clear',
        speed: 1.2,
        style: VoiceStyle.energetic,
      ),
    );
    final all = await db.collection('users/${user.uid}/voices').get();
    final byId = {for (final d in all.docs) d.id: d.data()};
    expect(byId['lw-warm']!['status'], 'inactive');
    expect(byId['lw-clear']!['status'], 'active');
    expect(byId['lw-clear']!['kind'], 'library');
    expect(byId['lw-clear']!['speed'], 1.2);
    expect(byId['lw-clear']!['style'], 'energetic');
    // A cloned voice can't be created from the app.
    await expectLater(
      db.doc('users/${user.uid}/voices/lw-mine').set({
        'kind': 'self_clone',
        'vendor_voice_id': 'x',
        'status': 'active',
        'speed': 1,
        'style': 'calm',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'schema_version': 1,
      }),
      throwsA(isA<FirebaseException>()),
    );
  });
}
