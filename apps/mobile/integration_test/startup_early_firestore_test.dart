import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/data/firestore.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/track/data/reflection_repository.dart';

/// D-71: the app's first frame asks for Firestore before Firebase is ready
/// (the home-screen widget's inputs read today's reflection). That read
/// fails, and a signed-in reopen then hit the stored error and showed
/// "We couldn't start Live Well". Startup must recover from it.
///
/// Needs a fresh app process (Firebase not yet initialised), so it runs on
/// a device; no emulators needed:
///
///   flutter test integration_test/startup_early_firestore_test.dart
///     --flavor dev -d DEVICE
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup recovers from a Firestore read before Firebase is '
      'ready', (_) async {
    expect(Firebase.apps, isEmpty, reason: 'needs a fresh app process');
    final container = ProviderContainer(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
    );
    addTearDown(container.dispose);

    // What the widget does on the app's first frame.
    final early = container.listen(
      reflectionRepositoryProvider,
      (_, _) {},
      onError: (_, _) {},
    );
    addTearDown(early.close);
    expect(() => container.read(firestoreProvider), throwsA(anything));

    await container.read(appStartupProvider.future);

    // Right after startup, with no wait for Riverpod's own retry.
    expect(container.read(firestoreProvider), isA<FirebaseFirestore>());
    expect(container.read(reflectionRepositoryProvider), isNotNull);
  });
}
