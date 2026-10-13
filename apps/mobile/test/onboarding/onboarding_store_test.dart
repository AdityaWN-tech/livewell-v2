import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/onboarding/data/onboarding_store.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved yet means start at Welcome', () async {
    final p = await SharedPrefsOnboardingStore().load();
    expect(p.step, OnboardingStep.welcome);
    expect(p.isAdult, isFalse);
  });

  test('saves, reloads and clears progress on the device', () async {
    final store = SharedPrefsOnboardingStore();
    final at = DateTime.utc(2026, 10, 13);
    await store.save(
      OnboardingProgress(
        step: OnboardingStep.signIn,
        adultConfirmedAt: at,
        legalAcceptedAt: {for (final t in legalDocuments) t: at},
      ),
    );
    final back = await SharedPrefsOnboardingStore().load();
    expect(back.step, OnboardingStep.signIn);
    expect(back.readyForAccount, isTrue);
    expect(back.legalAcceptedAt[ConsentType.aiDisclosure], at);

    await store.clear();
    expect((await store.load()).step, OnboardingStep.welcome);
  });

  test('corrupt saved data does not crash; onboarding restarts', () async {
    SharedPreferences.setMockInitialValues({'onboarding_progress_v1': '{oops'});
    expect(
      (await SharedPrefsOnboardingStore().load()).step,
      OnboardingStep.welcome,
    );
  });
}
