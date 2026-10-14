import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../consent/domain/consent.dart';
import '../domain/onboarding_progress.dart';

/// Keeps onboarding progress on the device so it resumes at the exact step
/// (FR-ONB-06). Holds only the step, the 18+ confirmation time and legal
/// acceptance times: no health data. Moves to the encrypted local database
/// when T-FND-08 lands (D-19).
abstract class OnboardingStore {
  Future<OnboardingProgress> load();
  Future<void> save(OnboardingProgress progress);
  Future<void> clear();
}

class SharedPrefsOnboardingStore implements OnboardingStore {
  static const _key = 'onboarding_progress_v1';

  @override
  Future<OnboardingProgress> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const OnboardingProgress();
    try {
      return OnboardingProgress.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return const OnboardingProgress();
    }
  }

  @override
  Future<void> save(OnboardingProgress progress) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(progress.toJson()),
      );

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => SharedPrefsOnboardingStore(),
);

/// Current onboarding progress, saved on every change.
class OnboardingController extends AsyncNotifier<OnboardingProgress> {
  OnboardingStore get _store => ref.read(onboardingStoreProvider);

  @override
  Future<OnboardingProgress> build() => _store.load();

  Future<void> _update(OnboardingProgress next) async {
    await _store.save(next);
    state = AsyncData(next);
  }

  Future<OnboardingProgress> _current() async => state.value ?? await future;

  Future<void> goTo(OnboardingStep step) async =>
      _update((await _current()).copyWith(step: step));

  Future<void> confirmAdult(DateTime now) async => _update(
    (await _current()).copyWith(
      adultConfirmedAt: now,
      step: OnboardingStep.legal,
    ),
  );

  Future<void> setLegalAccepted(
    ConsentType type, {
    required bool accepted,
    required DateTime now,
  }) async {
    final current = await _current();
    final legal = Map.of(current.legalAcceptedAt);
    if (accepted) {
      legal[type] = now;
    } else {
      legal.remove(type);
    }
    await _update(current.copyWith(legalAcceptedAt: legal));
  }

  /// Account created: the progress now lives in the profile and consents.
  Future<void> finish() async {
    await _store.clear();
    state = const AsyncData(OnboardingProgress());
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingProgress>(
      OnboardingController.new,
    );
