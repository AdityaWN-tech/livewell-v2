import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/avatar/domain/characters.dart';
import 'package:livewell/features/avatar/presentation/avatar_creator_screen.dart';
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

AvatarConfig preview(WidgetTester tester) =>
    tester.widget<AvatarView>(find.byKey(const Key('avatar-preview'))).config;

void main() {
  group('parts.json (the layered part list for T-AVT-06)', () {
    final m = jsonDecode(
      File('assets/avatar/parts.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cats = {
      for (final c in (m['categories'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: [
          for (final o in (c['options'] as List).cast<Map<String, dynamic>>())
            o['id'] as String,
        ],
    };

    test('every avatar option has a part, and nothing extra', () {
      List<String> names(List<Enum> v) => [for (final x in v) x.name];
      List<String> count(int n) => [for (var i = 0; i < n; i++) '$i'];
      expect(cats['hair'], names(HairStyle.values));
      expect(cats['eyes'], names(EyeShape.values));
      expect(cats['glasses'], names(Glasses.values));
      expect(cats['head_covering'], names(HeadCovering.values));
      expect(cats['clothing'], names(Clothing.values));
      expect(cats['skin'], count(AvatarColours.skin.length));
      expect(cats['hair_colour'], count(AvatarColours.hair.length));
      expect(cats['clothing_colour'], count(AvatarColours.clothing.length));
      expect(cats['background'], count(AvatarColours.background.length));
      expect(m['expressions'], names(AvatarExpression.values));
    });

    test('every part is a placeholder or final with its file', () {
      for (final c in (m['categories'] as List).cast<Map<String, dynamic>>()) {
        for (final o in (c['options'] as List).cast<Map<String, dynamic>>()) {
          expect(['placeholder', 'final'], contains(o['status']));
          if (o['status'] == 'final') {
            expect(File('assets/avatar/${o['file']}').existsSync(), isTrue);
          }
        }
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/avatar/'),
      );
    });
  });

  group('Avatar tab', () {
    testWidgets('opens on the saved look; arrows and characters change it', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = CoachCharacters.all[1].config;
      await h.boot(tester);
      await openStudio(tester);
      for (final tab in ['avatar', 'voice', 'background']) {
        expect(find.byKey(Key('studio-tab-$tab')), findsOneWidget);
      }
      expect(preview(tester), CoachCharacters.all[1].config);
      expect(find.text('Long hair'), findsWidgets);
      await tapKey(tester, 'studio-next');
      expect(CoachCharacters.indexOf(preview(tester)), 2);
      await tapKey(tester, 'avatar-character-older');
      expect(CoachCharacters.indexOf(preview(tester)), 6);
      await tapKey(tester, 'studio-save-avatar');
      expect(CoachCharacters.indexOf(h.avatars.saved!), 6);
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('Customize opens the creator; its look comes back', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-customize');
      expect(find.byType(AvatarCreatorScreen), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('avatar-skin-9')));
      await tester.tap(find.byKey(const Key('avatar-skin-9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-creator-use')));
      await tester.pumpAndSettle();
      expect(preview(tester).skin, 9);
      expect(find.text('Your own look'), findsOneWidget);
      // Nothing is saved until "Use this look".
      expect(h.avatars.saved, isNull);
      await tapKey(tester, 'studio-save-avatar');
      expect(h.avatars.saved!.skin, 9);
    });

    testWidgets('Use my selfie asks for consent first', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-selfie');
      expect(find.text('Use your selfie?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(h.photos.taken, 0);
      expect(h.consents.records, isEmpty);
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
      h.avatars.saved = CoachCharacters.all[0].config;
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-background');
      await tapKey(tester, 'studio-bg-3');
      expect(preview(tester).background, 3);
      await tapKey(tester, 'studio-save-background');
      expect(h.avatars.saved!.background, 3);
      expect(CoachCharacters.indexOf(h.avatars.saved!), 0);
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
          expect(find.byTooltip('Next look'), findsOneWidget);
          expect(find.byTooltip('Previous look'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Green hoodie. Not selected'),
            findsOneWidget,
          );
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
          ('avatar', 'studio-save-avatar'),
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
