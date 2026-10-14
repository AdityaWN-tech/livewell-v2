import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/auth/presentation/sign_in_screen.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/onboarding/data/onboarding_store.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:livewell/features/onboarding/presentation/about_screen.dart';
import 'package:livewell/features/onboarding/presentation/age_gate_screen.dart';
import 'package:livewell/features/onboarding/presentation/legal_screen.dart';
import 'package:livewell/features/splash/application/splash_handoff.dart';
import 'package:livewell/features/welcome/presentation/welcome_screen.dart';

import '../support/fake_onboarding_store.dart';
import '../support/frames.dart';

/// Boots the real app the way a cold start would: the splash resumes at
/// whatever step the store holds.
Future<void> boot(WidgetTester tester, FakeOnboardingStore store) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        flavorProvider.overrideWithValue(Flavor.prod),
        splashHandoffProvider.overrideWithValue(SplashHandoff.instant),
        onboardingStoreProvider.overrideWithValue(store),
        appStartupProvider.overrideWith(
          (ref) async =>
              signedOutDestination(await ref.read(onboardingProvider.future)),
        ),
      ],
      child: const LiveWellApp(),
    ),
  );
  await pumpFrames(tester, const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

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

    // Continue stays disabled until every document is ticked.
    final boxes = find.byType(CheckboxListTile);
    expect(boxes, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      expect(primaryButton(tester).onPressed, isNull, reason: 'after $i ticks');
      await tester.tap(boxes.at(i));
      await tester.pumpAndSettle();
    }
    expect(primaryButton(tester).onPressed, isNotNull);

    await tapText(tester, 'Accept and continue');
    expect(find.byType(SignInScreen), findsOneWidget);
    final saved = store.saved!;
    expect(saved.step, OnboardingStep.signIn);
    expect(saved.readyForAccount, isTrue);
  });

  testWidgets('unticking a document disables Continue again', (tester) async {
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
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(primaryButton(tester).onPressed, isNull);
    expect(store.saved!.allLegalAccepted, isFalse);
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
    final first = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(first.value, isTrue, reason: 'earlier tick kept');
  });

  testWidgets('"I already have an account" goes straight to sign-in', (
    tester,
  ) async {
    final store = FakeOnboardingStore();
    await boot(tester, store);
    await tapText(tester, 'I already have an account');
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('each legal document opens with its draft text and version', (
    tester,
  ) async {
    final store = FakeOnboardingStore(
      OnboardingProgress(
        step: OnboardingStep.legal,
        adultConfirmedAt: DateTime.utc(2026),
      ),
    );
    await boot(tester, store);
    final reads = find.text('Read');
    expect(reads, findsNWidgets(4));
    await tester.tap(reads.first);
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.textContaining('DRAFT for review'), findsOneWidget);
    expect(
      find.text('Version ${ConsentTexts.versionOf(ConsentType.terms)}'),
      findsOneWidget,
    );
  });
}
