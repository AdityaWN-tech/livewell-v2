import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/flavor.dart';
import 'core/startup/startup_trace.dart';
import 'features/splash/application/splash_handoff.dart';
import 'firebase/firebase_options.dart';

/// Shared startup for every flavor entrypoint (main_dev/main_staging/main_prod).
///
/// Nothing slow runs before runApp: the first Flutter frame (the splash) is
/// drawn straight away, and Firebase + sign-in state load in the background
/// (appStartupProvider) while the logo reveal plays (NFR-01).
Future<void> bootstrap(Flavor flavor) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  NativeSplashGate.preserve(binding);

  if (firebaseOptionsFor(flavor) == null) {
    throw StateError(
      'No Firebase project is configured for the ${flavor.name} flavor yet. '
      'Create it and run flutterfire configure (docs/setup/firebase-windows.md).',
    );
  }

  WidgetsBinding.instance.addPostFrameCallback(
    (_) => StartupTrace.mark('first_flutter_frame'),
  );
  runApp(
    ProviderScope(
      overrides: [flavorProvider.overrideWithValue(flavor)],
      child: const LiveWellApp(),
    ),
  );
}
