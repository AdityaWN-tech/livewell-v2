import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feature switches for things that are not built yet or need a kill switch
/// (spec 10.2). Defaults are off.
/// TODO(T-FND-11): read these from Firebase Remote Config.
class FeatureFlags {
  const FeatureFlags({this.briefings = false});

  /// Morning briefing player (FR-DLY-01). Off until briefings are generated.
  final bool briefings;
}

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags(),
);
