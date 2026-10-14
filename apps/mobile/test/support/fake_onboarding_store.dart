import 'package:livewell/features/onboarding/data/onboarding_store.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';

/// In-memory stand-in for the on-device onboarding store.
class FakeOnboardingStore implements OnboardingStore {
  FakeOnboardingStore([this.saved]);

  /// What is "on the device" (null = nothing stored).
  OnboardingProgress? saved;
  int saves = 0;

  @override
  Future<OnboardingProgress> load() async =>
      saved ?? const OnboardingProgress();

  @override
  Future<void> save(OnboardingProgress progress) async {
    saves++;
    saved = progress;
  }

  @override
  Future<void> clear() async => saved = null;
}
