import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deployment environment (spec 10.3). One Firebase project per flavor:
/// dev = `my-livewell`; staging and prod projects are created later.
enum Flavor {
  dev(firebaseProjectId: 'my-livewell', label: 'DEV'),
  staging(firebaseProjectId: null, label: 'STAGING'),
  prod(firebaseProjectId: null, label: null);

  const Flavor({required this.firebaseProjectId, required this.label});

  /// Null until that environment's Firebase project exists.
  final String? firebaseProjectId;

  /// Corner banner text; null hides the banner (prod).
  final String? label;
}

/// Overridden in [bootstrap] with the flavor of the running entrypoint.
final flavorProvider = Provider<Flavor>(
  (ref) => throw UnimplementedError('flavorProvider must be overridden'),
);
