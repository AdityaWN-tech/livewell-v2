import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../data/firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/application/account_setup.dart';
import '../../features/auth/data/firebase_auth_service.dart';
import '../../features/consent/data/consent_repository.dart';
import '../../features/onboarding/data/onboarding_store.dart';
import '../../features/onboarding/domain/onboarding_progress.dart';
import '../config/flavor.dart';
import '../monitoring/crash_reporting.dart';
import '../config/remote_flags.dart';
import 'startup_trace.dart';

/// Where the app goes after the splash.
class StartDestination {
  const StartDestination(this.path, {required this.signedIn});

  /// Route to open.
  final String path;

  /// Signed-in users get the short splash hold (NFR-01: Home in < 2 s).
  final bool signedIn;

  static const welcome = StartDestination('/welcome', signedIn: false);
  static const home = StartDestination('/home', signedIn: true);

  @override
  bool operator ==(Object other) =>
      other is StartDestination &&
      other.path == path &&
      other.signedIn == signedIn;

  @override
  int get hashCode => Object.hash(path, signedIn);

  @override
  String toString() => 'StartDestination($path, signedIn: $signedIn)';
}

/// Everything the app needs before its first real screen. Runs while the
/// splash animation plays, so the work overlaps (NFR-01: Home in under 2 s).
final appStartupProvider = FutureProvider<StartDestination>((ref) async {
  StartupTrace.mark('startup_begin');
  await ref.watch(firebaseAppProvider.future);
  StartupTrace.mark('firebase_ready');
  _startCrashReporting(ref);
  // Feature flags from Remote Config (T-FND-11, D-73): last launch's values
  // first, then a fetch. Not awaited, so startup never waits on it.
  unawaited(ref.read(remoteFlagValuesProvider.notifier).load());
  // The signed-in user is restored from the device; don't wait long for it.
  final user = await FirebaseAuth.instance.authStateChanges().first.timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );
  StartupTrace.mark('startup_ready signedIn=${user != null}');
  if (user != null) {
    // Signed in: Home if the account is set up, otherwise finish onboarding.
    final next = await ref
        .read(signInCompletionProvider)
        .complete(FirebaseAuthService.toAuthUser(user), restored: true);
    StartupTrace.mark('destination_ready $next');
    return StartDestination(next, signedIn: true);
  }
  return signedOutDestination(await ref.read(onboardingProvider.future));
});

/// Not signed in: resume onboarding at the exact step (FR-ONB-06).
StartDestination signedOutDestination(OnboardingProgress progress) =>
    StartDestination(progress.step.path, signedIn: false);

/// Crash reporting (T-FND-10, D-80): handlers now, collection only once the
/// analytics consent is known to be granted. Not awaited (NFR-01).
void _startCrashReporting(Ref ref) {
  final crash = ref.read(crashReporterProvider)..install();
  crash.follow(
    crashCollectionAllowed(
      flavor: ref.read(flavorProvider),
      devOptIn: devCrashReportsOptIn,
      signedIn: FirebaseAuth.instance.authStateChanges().map((u) => u != null),
      consents: () => ref.read(consentRepositoryProvider).watchRecords(),
    ),
  );
  unawaited(crash.setKey(CrashKey.flavor, ref.read(flavorProvider)));
}
