import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deployment environment (spec 10.3). One Firebase project per flavor:
/// dev = `my-livewell`; staging and prod projects are created later.
enum Flavor {
  dev(
    firebaseProjectId: 'my-livewell',
    firestoreDatabaseId: '(default)',
    label: 'DEV',
  ),
  staging(firebaseProjectId: null, firestoreDatabaseId: null, label: 'STAGING'),
  prod(firebaseProjectId: null, firestoreDatabaseId: null, label: null);

  const Flavor({
    required this.firebaseProjectId,
    required this.firestoreDatabaseId,
    required this.label,
  });

  /// Null until that environment's Firebase project exists.
  final String? firebaseProjectId;

  /// Firestore database name, always passed explicitly (D-16): a Standard
  /// edition `(default)` database in nam5.
  final String? firestoreDatabaseId;

  /// Corner banner text; null hides the banner (prod).
  final String? label;
}

/// Overridden in [bootstrap] with the flavor of the running entrypoint.
final flavorProvider = Provider<Flavor>(
  (ref) => throw UnimplementedError('flavorProvider must be overridden'),
);
