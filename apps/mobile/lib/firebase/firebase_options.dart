import 'package:firebase_core/firebase_core.dart';

import '../core/config/flavor.dart';
import 'firebase_options_dev.dart' as dev;

/// Firebase options for [flavor], or null while that environment's Firebase
/// project does not exist yet (staging and prod, see docs/decisions.md D-05).
/// Add `firebase_options_<flavor>.dart` with `flutterfire configure` to enable one.
FirebaseOptions? firebaseOptionsFor(Flavor flavor) => switch (flavor) {
  Flavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
  Flavor.staging => null,
  Flavor.prod => null,
};
