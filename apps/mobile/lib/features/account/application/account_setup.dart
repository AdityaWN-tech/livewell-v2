import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth.dart';
import '../../consent/data/consent_repository.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/domain/onboarding_progress.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../voice/data/voice_repository.dart';
import '../data/profile_repository.dart';

/// What to do after someone signs in.
enum AccountStatus {
  /// Profile exists: go to the app.
  ready,

  /// Signed in, but the 18+ check or legal acceptance isn't done yet
  /// (e.g. "I already have an account" on a new device): finish onboarding.
  needsOnboarding,
}

/// Turns finished onboarding into the account: profile first (the rules need
/// it with age_confirmed before anything else can be stored), then one
/// consent record per legal document with the time it was accepted.
class AccountSetup {
  AccountSetup({
    required this.profiles,
    required this.consents,
    required this.deviceCountry,
  });

  final ProfileRepository profiles;
  final ConsentRepository consents;
  final String? Function() deviceCountry;

  Future<AccountStatus> afterSignIn(
    AuthUser user,
    OnboardingProgress progress,
  ) async {
    if (await profiles.exists(user.uid)) return AccountStatus.ready;
    if (!progress.readyForAccount) return AccountStatus.needsOnboarding;

    await profiles.create(
      user.uid,
      NewProfile(
        displayName: user.displayName,
        email: user.email,
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
        region: inferRegion(
          phoneE164: user.phoneNumber,
          deviceCountry: deviceCountry(),
        ),
      ),
    );
    for (final type in legalDocuments) {
      await consents.record(
        type,
        granted: true,
        grantedAt: progress.legalAcceptedAt[type],
      );
    }
    return AccountStatus.ready;
  }
}

final accountSetupProvider = Provider<AccountSetup>(
  (ref) => AccountSetup(
    profiles: ref.watch(profileRepositoryProvider),
    consents: ref.watch(consentRepositoryProvider),
    deviceCountry: () => PlatformDispatcher.instance.locale.countryCode,
  ),
);

/// After any successful sign-in: runs [AccountSetup] and returns the route
/// to open next.
class SignInCompletion {
  SignInCompletion(this._ref);

  final Ref _ref;

  Future<String> complete(AuthUser user) async {
    // Storage chosen while signed out (in memory) must not outlive sign-in.
    _ref
      ..invalidate(planRepositoryProvider)
      ..invalidate(avatarRepositoryProvider)
      ..invalidate(voiceRepositoryProvider);
    final progress = await _ref.read(onboardingProvider.future);
    final status = await _ref
        .read(accountSetupProvider)
        .afterSignIn(user, progress);
    switch (status) {
      case AccountStatus.ready:
        await _ref.read(onboardingProvider.notifier).finish();
        final profiles = _ref.read(profileRepositoryProvider);
        final profile = await profiles.get(user.uid);
        // No name yet but Google or Apple gave one (for example an account
        // made by phone, then Google linked): use it, so Home can say
        // "Hi, {first name}" without asking (T-UI-02c).
        final given = user.displayName?.trim();
        if (profile != null &&
            (profile.displayName?.trim().isEmpty ?? true) &&
            given != null &&
            given.isNotEmpty) {
          try {
            await profiles.updateSettings(user.uid, {
              ProfileSettings.displayName: given,
            });
          } catch (_) {
            // A name is nice to have; never block sign-in on it.
          }
        }
        return routeForProfileStep(profile?.onboardingStep);
      case AccountStatus.needsOnboarding:
        final next = progress.isAdult
            ? OnboardingStep.legal
            : OnboardingStep.about;
        await _ref.read(onboardingProvider.notifier).goTo(next);
        return next.path;
    }
  }
}

/// Where a signed-in person with a profile goes, by their onboarding step
/// (FR-ONB-06). Steps without a screen yet (the assessment) go to Home.
String routeForProfileStep(String? step) => switch (step) {
  ProfileStep.avatar => avatarPath,
  ProfileStep.voice => voicePath,
  ProfileStep.checkin => checkinPath,
  ProfileStep.focus => focusPath,
  ProfileStep.plan => planPath,
  ProfileStep.why => whyPath,
  _ => '/home',
};

const whyPath = '/onboarding/why';
const avatarPath = '/onboarding/avatar';
const voicePath = '/onboarding/voice';
const checkinPath = '/onboarding/checkin';
const focusPath = '/onboarding/focus';
const planPath = '/onboarding/plan';

final signInCompletionProvider = Provider<SignInCompletion>(
  SignInCompletion.new,
);
