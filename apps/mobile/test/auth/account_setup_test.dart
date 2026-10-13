import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';

import '../consent/consent_test.dart' show FakeConsentRepository;
import '../support/fakes.dart';

void main() {
  final at = DateTime.utc(2026, 10, 13, 8, 30);
  final ready = OnboardingProgress(
    step: OnboardingStep.signIn,
    adultConfirmedAt: at,
    legalAcceptedAt: {
      for (final (i, t) in legalDocuments.indexed)
        t: at.add(Duration(minutes: i)),
    },
  );
  const phoneUser = AuthUser(uid: 'u1', phoneNumber: '+919876543210');

  late FakeProfileRepository profiles;
  late FakeConsentRepository consents;
  late AccountSetup setup;

  setUp(() {
    profiles = FakeProfileRepository();
    consents = FakeConsentRepository();
    setup = AccountSetup(
      profiles: profiles,
      consents: consents,
      deviceCountry: () => 'IN',
    );
  });

  test('existing account: straight to the app, nothing written', () async {
    profiles.existing.add('u1');
    expect(await setup.afterSignIn(phoneUser, ready), AccountStatus.ready);
    expect(profiles.created, isEmpty);
    expect(consents.records, isEmpty);
  });

  test('onboarding not finished: nothing written, finish onboarding', () async {
    final notAdult = OnboardingProgress(legalAcceptedAt: ready.legalAcceptedAt);
    expect(
      await setup.afterSignIn(phoneUser, notAdult),
      AccountStatus.needsOnboarding,
    );
    final adultOnly = OnboardingProgress(adultConfirmedAt: at);
    expect(
      await setup.afterSignIn(phoneUser, adultOnly),
      AccountStatus.needsOnboarding,
    );
    expect(profiles.created, isEmpty);
    expect(consents.records, isEmpty);
  });

  test('new account: profile first, then the four legal consents', () async {
    expect(await setup.afterSignIn(phoneUser, ready), AccountStatus.ready);
    final p = profiles.created['u1']!;
    expect(p.region, 'IN');
    expect(p.onboardingStep, 'why');
    expect(consents.records.map((r) => r.type), legalDocuments);
    expect(consents.records.every((r) => r.granted), isTrue);
    for (final type in legalDocuments) {
      expect(consents.grantedAt[type], ready.legalAcceptedAt[type]);
      expect(
        consents.records.firstWhere((r) => r.type == type).docVersion,
        ConsentTexts.versionOf(type),
      );
    }
  });

  test(
    'region left empty when it cannot be known (+1 on a non-US phone)',
    () async {
      setup = AccountSetup(
        profiles: profiles,
        consents: consents,
        deviceCountry: () => 'CA',
      );
      await setup.afterSignIn(
        const AuthUser(uid: 'u2', phoneNumber: '+12125550123'),
        ready,
      );
      expect(profiles.created['u2']!.region, isNull);
    },
  );
}
