import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/speech/dictation.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/data/firebase_auth_service.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/onboarding/data/onboarding_store.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';
import 'package:livewell/features/splash/application/splash_handoff.dart';

import '../consent/consent_test.dart' show FakeConsentRepository;
import 'fake_onboarding_store.dart';
import 'fakes.dart';
import 'frames.dart';

/// Everything a test can look at after booting the app.
class Harness {
  Harness({
    FakeOnboardingStore? store,
    FakeAuthService? auth,
    FakeProfileRepository? profiles,
    FakeConsentRepository? consents,
    FakeDictation? dictation,
    FakePhoneLauncher? phone,
    this.flavor = Flavor.prod,
  }) : dictation = dictation ?? FakeDictation(),
       phone = phone ?? FakePhoneLauncher(),
       store = store ?? FakeOnboardingStore(),
       auth = auth ?? FakeAuthService(),
       profiles = profiles ?? FakeProfileRepository(),
       consents = consents ?? FakeConsentRepository();

  final FakeOnboardingStore store;
  final FakeAuthService auth;
  final FakeProfileRepository profiles;
  final FakeConsentRepository consents;
  final FakeDictation dictation;
  final FakePhoneLauncher phone;

  /// Build flavour to simulate (dev shows developer tools).
  final Flavor flavor;

  /// Cold start the real app: signed out resumes at the saved onboarding
  /// step; signed in goes by the profile's step.
  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flavorProvider.overrideWithValue(flavor),
          splashHandoffProvider.overrideWithValue(SplashHandoff.instant),
          onboardingStoreProvider.overrideWithValue(store),
          authServiceProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profiles),
          consentRepositoryProvider.overrideWithValue(consents),
          dictationProvider.overrideWithValue(dictation),
          phoneLauncherProvider.overrideWithValue(phone),
          // Same decisions as the real startup, minus Firebase.
          appStartupProvider.overrideWith((ref) async {
            final user = auth.currentUser;
            if (user != null) {
              final next = await ref
                  .read(signInCompletionProvider)
                  .complete(user);
              return StartDestination(next, signedIn: true);
            }
            return signedOutDestination(
              await ref.read(onboardingProvider.future),
            );
          }),
        ],
        child: const LiveWellApp(),
      ),
    );
    await pumpFrames(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}
