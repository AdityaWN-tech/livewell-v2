import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase/firebase_options.dart';
import '../config/flavor.dart';
import 'startup_trace.dart';

/// Where the app goes after the splash.
enum StartDestination { welcome, home }

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
  return user == null ? StartDestination.welcome : StartDestination.home;
});
