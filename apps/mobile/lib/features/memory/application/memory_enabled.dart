import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/config/flavor.dart';

/// Whether "What my coach remembers" and its route exist (D-101): the dev
/// flavor always, staging and prod only with the `coachMemory` flag (off
/// until the Memory Agent is deployed). Hidden means no Profile row and no
/// route, so no page says "coming soon" (D-56).
final coachMemoryEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(flavorProvider) == Flavor.dev ||
      ref.watch(featureFlagsProvider).coachMemory,
);
