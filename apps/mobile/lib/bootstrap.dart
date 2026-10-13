import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/flavor.dart';
import 'firebase/firebase_options.dart';

/// Shared startup for every flavor entrypoint (main_dev/main_staging/main_prod).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  final options = firebaseOptionsFor(flavor);
  if (options == null) {
    throw StateError(
      'No Firebase project is configured for the ${flavor.name} flavor yet. '
      'Create it and run flutterfire configure (docs/setup/firebase-windows.md).',
    );
  }
  await Firebase.initializeApp(options: options);

  runApp(
    ProviderScope(
      overrides: [flavorProvider.overrideWithValue(flavor)],
      child: const LiveWellApp(),
    ),
  );
}
