import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/auth/presentation/sign_in_screen.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:livewell/features/onboarding/presentation/about_screen.dart';
import 'package:livewell/features/onboarding/presentation/age_gate_screen.dart';
import 'package:livewell/features/onboarding/presentation/legal_screen.dart';
import 'package:livewell/features/welcome/presentation/welcome_screen.dart';

import '../support/fake_onboarding_store.dart';
import '../support/app_harness.dart';

Future<void> boot(WidgetTester tester, FakeOnboardingStore store) =>
    Harness(store: store).boot(tester);

FilledButton primaryButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  group('OnboardingProgress', () {
    test('survives a save and load', () {
      final at = DateTime.utc(2026, 10, 13, 9);
      final p = OnboardingProgress(
        step: OnboardingStep.legal,
        adultConfirmedAt: at,
        legalAcceptedAt: {ConsentType.terms: at},
      );
      final back = OnboardingProgress.fromJson(p.toJson());
      expect(back.step, OnboardingStep.legal);
      expect(back.adultConfirmedAt, at);
      expect(back.legalAcceptedAt, {ConsentType.terms: at});
    });

    test('ready for an account only when adult and all four accepted', () {
      final at = DateTime.utc(2026);
      final all = {for (final t in legalDocuments) t: at};
      expect(legalDocuments, hasLength(4));
      expect(OnboardingProgress(legalAcceptedAt: all).readyForAccount, isFalse);
      expect(
        OnboardingProgress(
          adultConfirmedAt: at,
          legalAcceptedAt: {ConsentType.terms: at},
        ).readyForAccount,
        isFalse,
      );
      expect(
        OnboardingProgress(
          adultConfirmedAt: at,
          legalAcceptedAt: all,
        ).readyForAccount,
        isTrue,
      );
    });

    test('unknown or damaged saved data falls back safely', () {
      final p = OnboardingProgress.fromJson({
        'step': 'something_new',
        'legal_accepted_at': {
          'unknown_doc': '2026-01-01',
          'terms': 'not a date',
        },
      });
      expect(p.step, OnboardingStep.welcome);
      expect(p.legalAcceptedAt, isEmpty);
    });

    test('signed out, the app resumes at the saved step (FR-ONB-06)', () {
      for (final step in OnboardingStep.values) {
        final d = signedOutDestination(OnboardingProgress(step: step));
        expect(d.path, step.path);
        expect(d.signedIn, isFalse);
      }
    });
  });

  testWidgets('full flow: welcome, about, 18+, legal, then sign-in', (
    tester,
  ) async {
    final store = FakeOnboardingStore();
    await boot(tester, store);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tapText(tester, 'Get started');
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(
      find.text('Give medication, dose or supplement advice.'),
      findsOneWidget,
    );

    await tapText(tester, 'Continue');
    expect(find.byType(AgeGateScreen), findsOneWidget);

    await tapText(tester, "Yes, I'm 18 or older");
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(store.saved!.isAdult, isTrue);

    // One checkbox (Step 3); Continue stays disabled until it is ticked.
    expect(find.byType(Checkbox), findsOneWidget);
    expect(primaryButton(tester).onPressed, isNull);
    await tester.tap(find.byKey(const Key('legal-agree-box')));
    await tester.pumpAndSettle();
    expect(primaryButton(tester).onPressed, isNotNull);
    // Still four acceptances (four consent records at sign-in), one time.
    final accepted = store.saved!.legalAcceptedAt;
    expect(accepted.keys, unorderedEquals(legalDocuments));
    expect(accepted.values.toSet(), hasLength(1));

    await tapText(tester, 'Accept and continue');
    expect(find.byType(SignInScreen), findsOneWidget);
    final saved = store.saved!;
    expect(saved.step, OnboardingStep.signIn);
    expect(saved.readyForAccount, isTrue);
  });

  testWidgets('unticking the box disables Continue again', (tester) async {
    final at = DateTime.utc(2026);
    final store = FakeOnboardingStore(
      OnboardingProgress(
        step: OnboardingStep.legal,
        adultConfirmedAt: at,
        legalAcceptedAt: {for (final t in legalDocuments) t: at},
      ),
    );
    await boot(tester, store);
    expect(primaryButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('legal-agree-box')));
    await tester.pumpAndSettle();
    expect(primaryButton(tester).onPressed, isNull);
    expect(store.saved!.legalAcceptedAt, isEmpty);
  });

  testWidgets('under 18: friendly stop and nothing is stored (FR-ONB-04)', (
    tester,
  ) async {
    final store = FakeOnboardingStore();
    await boot(tester, store);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Continue');
    await tapText(tester, "No, I'm under 18");
    expect(find.text('Live Well is for adults'), findsOneWidget);
    expect(store.saved, isNull, reason: 'nothing kept on the device');
    await tapText(tester, 'Back to start');
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('closing the app mid-way reopens at the same step (FR-ONB-06)', (
    tester,
  ) async {
    final store = FakeOnboardingStore(
      OnboardingProgress(
        step: OnboardingStep.legal,
        adultConfirmedAt: DateTime.utc(2026),
        legalAcceptedAt: {ConsentType.terms: DateTime.utc(2026)},
      ),
    );
    await boot(tester, store);
    expect(find.byType(LegalScreen), findsOneWidget);
    // Only some documents (saved by an older version): not ticked, so the
    // person agrees to all four again.
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(primaryButton(tester).onPressed, isNull);
  });

  testWidgets('"I already have an account" goes straight to sign-in', (
    tester,
  ) async {
    final store = FakeOnboardingStore();
    await boot(tester, store);
    await tapText(tester, 'I already have an account');
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('each document name is a link to its draft text and version', (
    tester,
  ) async {
    final store = FakeOnboardingStore(
      OnboardingProgress(
        step: OnboardingStep.legal,
        adultConfirmedAt: DateTime.utc(2026),
      ),
    );
    await boot(tester, store);
    expect(
      find.text(
        'I agree to the Terms of Service, Privacy Policy, Medical Disclaimer '
        'and AI Disclosure',
        findRichText: true,
      ),
      findsOneWidget,
    );
    for (final (name, type) in [
      ('Terms of Service', ConsentType.terms),
      ('Privacy Policy', ConsentType.privacy),
      ('Medical Disclaimer', ConsentType.medicalDisclaimer),
      ('AI Disclosure', ConsentType.aiDisclosure),
    ]) {
      await tester.tapOnText(find.textRange.ofSubstring(name));
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsOneWidget, reason: name);
      expect(find.textContaining('DRAFT for review'), findsOneWidget);
      expect(
        find.text('Version ${ConsentTexts.versionOf(type)}'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    // Reading a document doesn't tick the box.
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(store.saved?.legalAcceptedAt ?? const {}, isEmpty);
  });

  testWidgets(
    'the plain words tick the box; screen readers hear the sentence',
    (tester) async {
      final handle = tester.ensureSemantics();
      final store = FakeOnboardingStore(
        OnboardingProgress(
          step: OnboardingStep.legal,
          adultConfirmedAt: DateTime.utc(2026),
        ),
      );
      await boot(tester, store);
      expect(
        tester.getSemantics(find.byKey(const Key('legal-agree-box'))),
        matchesSemantics(
          label:
              'I agree to the Terms of Service, Privacy Policy, Medical '
              'Disclaimer and AI Disclosure',
          hasCheckedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      await tester.tapOnText(find.textRange.ofSubstring('I agree to the'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(store.saved!.allLegalAccepted, isTrue);
      handle.dispose();
    },
  );
}
