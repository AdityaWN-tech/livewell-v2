import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/onboarding_store.dart';
import '../../features/onboarding/domain/onboarding_progress.dart';
import '../../firebase/firebase_options.dart';
import '../config/flavor.dart';
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
  final options = firebaseOptionsFor(ref.watch(flavorProvider))!;
  StartupTrace.mark('startup_begin');
  await Firebase.initializeApp(options: options);
  StartupTrace.mark('firebase_ready');
  // The signed-in user is restored from the device; don't wait long for it.
  final user = await FirebaseAuth.instance.authStateChanges().first.timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );
  StartupTrace.mark('startup_ready signedIn=${user != null}');
  if (user != null) return StartDestination.home;
  return signedOutDestination(await ref.read(onboardingProvider.future));
});

/// Not signed in: resume onboarding at the exact step (FR-ONB-06).
StartDestination signedOutDestination(OnboardingProgress progress) =>
    StartDestination(progress.step.path, signedIn: false);
