import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/studio/presentation/studio_screen.dart';
import 'package:livewell/features/studio/presentation/studio_widgets.dart';
import 'package:livewell/features/voice/domain/voice.dart';
import 'package:livewell/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';

Harness signedIn({FeatureFlags flags = const FeatureFlags()}) {
  final h = Harness(
    flags: flags,
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  h.profiles.names[uid] = 'Priya Shah';
  return h;
}

/// Scrolls [f] into view in the Studio and taps it.
Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Profile > My coach > Change avatar (or voice): the Studio.
Future<void> openStudio(
  WidgetTester tester, {
  String row = 'profile-avatar',
}) async {
  await tester.tap(find.byKey(const Key('profile-button')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(Key(row)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byKey(Key(row)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(row)));
  await tester.pumpAndSettle();
  expect(find.byType(StudioScreen), findsOneWidget);
  expect(find.text('Avatar & Voice Studio'), findsOneWidget);
}

/// The background the Studio's preview shows.
Color previewBackground(WidgetTester tester) => tester
    .widget<AvatarView>(find.byKey(const Key('avatar-preview')))
    .background!;

void main() {
  group('Avatar tab', () {
    testWidgets('shows the coach and what is coming; the cartoon creator, '
        'characters and selfie suggestion are gone (T-AVT-08a)', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      for (final tab in ['avatar', 'voice', 'background']) {
        expect(find.byKey(Key('studio-tab-$tab')), findsOneWidget);
      }
      expect(find.byKey(const Key('studio-stage')), findsOneWidget);
      expect(find.byKey(const Key('avatar-more-soon')), findsOneWidget);
      for (final gone in [
        'studio-customize',
        'studio-selfie',
        'studio-next',
        'avatar-character-older',
      ]) {
        expect(find.byKey(Key(gone)), findsNothing, reason: gone);
      }
      expect(find.byType(AvatarView), findsOneWidget);
    });
  });

  group('Voice tab', () {
    testWidgets('6 library voices; the saved one is Active; saving works', (
      tester,
    ) async {
      final h = signedIn();
      h.voices.chosen = const VoiceChoice(voiceId: 'lw-gentle');
      await h.boot(tester);
      await openStudio(tester, row: 'profile-voice');
      expect(find.byKey(const Key('ai-voice-label')), findsOneWidget);
      for (final v in VoiceLibrary.all) {
        await tester.scrollUntilVisible(
          find.byKey(Key('voice-${v.id}')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
      }
      final gentle = tester.widget<VoiceRow>(
        find.byKey(const Key('voice-lw-gentle')),
      );
      expect(gentle.selected, isTrue);
      expect(gentle.status, 'Active');
      await tapKey(tester, 'voice-play-lw-deep');
      expect(h.player.played.last.$1, 'assets/voices/lw-deep_calm.m4a');
      await tapKey(tester, 'studio-save-voice');
      expect(h.voices.chosen!.voiceId, 'lw-deep');
    });

    testWidgets('clone and Dr. Gokula off: "Coming soon", not choosable, '
        'no consent banner', (tester) async {
      await signedIn().boot(tester);
      await openStudio(tester, row: 'profile-voice');
      for (final id in ['voice-own', 'voice-loved-one']) {
        await tester.scrollUntilVisible(
          find.byKey(Key(id)),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        final row = tester.widget<VoiceRow>(find.byKey(Key(id)));
        expect(row.status, 'Coming soon');
        expect(row.onTap, isNull);
        expect(row.selected, isNull);
      }
      expect(find.byKey(const Key('voice-dr-gokula')), findsNothing);
      expect(find.byKey(const Key('voice-consent-banner')), findsNothing);
    });

    testWidgets('clone flag on: an explanation only, nothing recorded', (
      tester,
    ) async {
      final h = signedIn(flags: const FeatureFlags(voiceClone: true));
      await h.boot(tester);
      await openStudio(tester, row: 'profile-voice');
      await tapKey(tester, 'voice-own');
      expect(find.byKey(const Key('voice-own-sheet')), findsOneWidget);
      expect(h.voices.chosen, isNull);
    });

    testWidgets('Dr. Gokula flag on: shown, labelled AI voice, not playable', (
      tester,
    ) async {
      await signedIn(flags: const FeatureFlags(drGokulaVoice: true))
          .boot(tester);
      await openStudio(tester, row: 'profile-voice');
      await tester.scrollUntilVisible(
        find.byKey(const Key('voice-dr-gokula')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      final row = tester.widget<VoiceRow>(
        find.byKey(const Key('voice-dr-gokula')),
      );
      expect(row.detail, 'AI voice');
      expect(row.onPreview, isNull);
    });

    testWidgets('the consent banner shows only with a consented clone', (
      tester,
    ) async {
      Widget list(bool consent) => MaterialApp(
        theme: LwTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoiceChoices(
              selectedId: 'lw-warm',
              onSelect: (_) {},
              onPreview: (_) {},
              flags: const FeatureFlags(),
              hasClonedVoiceConsent: consent,
            ),
          ),
        ),
      );
      await tester.pumpWidget(list(false));
      expect(find.byKey(const Key('voice-consent-banner')), findsNothing);
      await tester.pumpWidget(list(true));
      expect(
        find.text(
          'Voice consent active. You can delete your voice data anytime '
          'from settings.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Background tab', () {
    testWidgets('pick a colour and save; scenes say when they come', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = AvatarConfig.fallback.copyWith(skin: 7);
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-background');
      await tapKey(tester, 'studio-bg-3');
      expect(previewBackground(tester), AvatarColours.background[3]);
      await tapKey(tester, 'studio-save-background');
      expect(h.avatars.saved!.background, 3);
      expect(h.avatars.saved!.skin, 7, reason: 'the rest is kept');
      await tester.scrollUntilVisible(
        find.byKey(const Key('studio-scene-beach')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Unlocks with a 7-day streak'), findsOneWidget);
      final beach = tester.widget<VoiceRow>(
        find.byKey(const Key('studio-scene-beach')),
      );
      expect(beach.onTap, isNull);
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets(
        'labels, tap targets and contrast (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final handle = tester.ensureSemantics();
          await signedIn().boot(tester);
          await openStudio(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(find.bySemanticsLabel('Your coach’s avatar'), findsOneWidget);
          await tapKey(tester, 'studio-tab-voice');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(
            find.bySemanticsLabel(
              RegExp(r'^Warm, US English · AI voice\. Selected'),
            ),
            findsOneWidget,
          );
          handle.dispose();
        },
      );
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('iPhone SE, text $scale: no overflow on any tab', (
        tester,
      ) async {
        await signedIn().boot(tester);
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openStudio(tester);
        for (final (tab, last) in [
          ('avatar', 'avatar-more-soon'),
          ('voice', 'studio-save-voice'),
          ('background', 'studio-save-background'),
        ]) {
          await tapKey(tester, 'studio-tab-$tab');
          expect(tester.takeException(), isNull, reason: tab);
          await tapKey(tester, last);
          expect(tester.takeException(), isNull, reason: tab);
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, 5000),
          );
          await tester.pumpAndSettle();
        }
      });
    }
  });
}
