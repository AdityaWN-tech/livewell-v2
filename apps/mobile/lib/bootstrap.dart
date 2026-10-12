import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/flavor.dart';

/// Shared startup for every flavor entrypoint (main_dev/main_staging/main_prod).
/// Firebase.initializeApp is added here once `flutterfire configure` has
/// written `lib/firebase/firebase_options_<flavor>.dart`.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [flavorProvider.overrideWithValue(flavor)],
      child: const LiveWellApp(),
    ),
  );
}
