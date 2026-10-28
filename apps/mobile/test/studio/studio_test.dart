import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/features/avatar/data/avatar_maker_api.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
import 'package:livewell/features/studio/presentation/studio_screen.dart';
import 'package:livewell/features/studio/presentation/studio_widgets.dart';
import 'package:livewell/features/voice/domain/voice.dart';
import 'package:livewell/l10n/app_localizations.dart';
import 'package:livewell/features/avatar/domain/coaches.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';

/// Build my own and Adjust on (the Media Service is set up in the fake).
const maker = FeatureFlags(avatarMaker: true);

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
  // The Studio's list (its name field has a scrollable of its own).
  final studio = find.descendant(
    of: find.byKey(const Key('studio')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: studio.evaluate().isEmpty
        ? find.byType(Scrollable).last
        : studio.first,
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

/// The coaches shown as picked in the grid.
/// The Studio's list (its name field has a scrollable of its own).
Finder studioList() => find
    .descendant(
      of: find.byKey(const Key('studio')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls the Studio back to the top (the preview and name field).
Future<void> toTop(WidgetTester tester) async {
  await tester.drag(studioList(), const Offset(0, 5000));
  await tester.pumpAndSettle();
}

/// Scrolls [key] into view without tapping it.
Future<void> reveal(WidgetTester tester, String key) => tester
    .scrollUntilVisible(find.byKey(Key(key)), 300, scrollable: studioList());

Set<ReadyCoach> selected(WidgetTester tester) => {
  for (final c in ReadyCoach.values)
    if (tester
            .widget<Semantics>(find.byKey(Key('coach-${c.id}')))
            .properties
            .selected ==
        true)
      c,
};

/// The background the Studio's preview shows.
Color previewBackground(WidgetTester tester) => tester
    .widget<AvatarView>(find.byKey(const Key('avatar-preview')))
    .background!;

void main() {
  group('Avatar Studio (T-AVT-08b)', () {
    testWidgets('the tabs; opens on the saved coach; pick another, save', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = const CoachChoice(coach: ReadyCoach.greyGlasses);
      await h.boot(tester);
      await openStudio(tester);
      // Flags off (prod today): the ways that need the Media Service are
      // hidden, never "coming soon" (Step 1, D-50).
      for (final tab in [
        StudioTab.coaches,
        StudioTab.background,
        StudioTab.voice,
      ]) {
        expect(find.byKey(Key('studio-tab-${tab.name}')), findsOneWidget);
      }
      for (final tab in [StudioTab.photo, StudioTab.build, StudioTab.adjust]) {
        expect(find.byKey(Key('studio-tab-${tab.name}')), findsNothing);
      }
      expect(find.byKey(const Key('studio-stage')), findsOneWidget);
      expect(selected(tester), {ReadyCoach.greyGlasses});
      await tapKey(tester, 'coach-wheelchair');
      expect(selected(tester), {ReadyCoach.wheelchair});
      // Nothing is saved until "Use this coach".
      expect(h.avatars.saved!.coach, ReadyCoach.greyGlasses);
      await tapKey(tester, 'studio-save-avatar');
      expect(h.avatars.saved!.coach, ReadyCoach.wheelchair);
      expect(h.avatars.saved!.source, CoachSource.readyMade);
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets(
      'rename: saved with the avatar; letters only; empty is "Coach"',
      (tester) async {
        final h = signedIn();
        await h.boot(tester);
        await openStudio(tester);
        final name = find.byKey(const Key('studio-coach-name'));
        await tester.enterText(name, '42');
        await tester.pump();
        expect(find.text('Use 1 to 20 letters.'), findsOneWidget);
        await reveal(tester, 'studio-save-avatar');
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('studio-save-avatar')))
              .onPressed,
          isNull,
        );
        await toTop(tester);
        await tester.enterText(name, '  Asha ');
        await tester.pump();
        await tapKey(tester, 'studio-save-avatar');
        expect(h.avatars.saved!.coachName, 'Asha');
        // Let "Saved." go so it doesn't cover the button.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await toTop(tester);
        await tester.enterText(name, '');
        await tester.pump();
        await tapKey(tester, 'studio-save-avatar');
        expect(h.avatars.saved!.coachName, isNull);
      },
    );

    testWidgets('switching tabs keeps the choice; the background shows on '
        'the preview', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'coach-long_black_hair');
      await tapKey(tester, 'studio-tab-background');
      await tapKey(tester, 'studio-bg-4');
      await toTop(tester);
      expect(previewBackground(tester), AvatarColours.background[4]);
      await tapKey(tester, 'studio-tab-coaches');
      expect(selected(tester), {ReadyCoach.longBlackHair});
      await tapKey(tester, 'studio-save-avatar');
      expect(
        (h.avatars.saved!.coach, h.avatars.saved!.background),
        (ReadyCoach.longBlackHair, 4),
      );
    });

    testWidgets('no "coming soon" anywhere in the Studio', (tester) async {
      await signedIn().boot(tester);
      await openStudio(tester);
      for (final tab in ['coaches', 'background']) {
        await tapKey(tester, 'studio-tab-$tab');
        expect(
          find.textContaining(RegExp('coming', caseSensitive: false)),
          findsNothing,
          reason: tab,
        );
      }
    });

    testWidgets('flag on but the Media Service not set up: still hidden', (
      tester,
    ) async {
      final h = signedIn(flags: maker);
      h.avatarMaker.available = false;
      await h.boot(tester);
      await openStudio(tester);
      expect(find.byKey(const Key('studio-tab-build')), findsNothing);
      expect(find.byKey(const Key('studio-tab-adjust')), findsNothing);
    });

    testWidgets('dev build: the coaches show their placeholder frames; '
        'prod: the initial circle until the art is final', (tester) async {
      await signedIn().boot(tester);
      await openStudio(tester);
      final view = tester.widget<AvatarView>(
        find.byKey(const Key('avatar-preview')),
      );
      expect(view.images, isNull, reason: 'prod: placeholder art hidden');
    });

    testWidgets('dev build: the picked coach plays its placeholder frames', (
      tester,
    ) async {
      final h = Harness(
        flavor: Flavor.dev,
        auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
      );
      h.profiles.existing[uid] = ProfileStep.assessment;
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'coach-navy_turban');
      await toTop(tester);
      // The frames load from the asset bundle (real IO).
      AvatarImages? images;
      for (var i = 0; i < 50 && images == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        images = tester
            .widget<AvatarView>(find.byKey(const Key('avatar-preview')))
            .images;
      }
      expect(
        images![AvatarFrame.neutral],
        const AssetImage(
          'assets/avatar/frames/coaches/navy_turban/neutral@2x.webp',
        ),
      );
    });
  });

  testWidgets('FR-AVT-01: switching coach type keeps the voice and the '
      'history', (tester) async {
    final h = signedIn(flags: maker);
    h.avatars.saved = const CoachChoice(
      source: CoachSource.built,
      framesVersion: 2,
      coachName: 'Asha',
    );
    h.voices.chosen = const VoiceChoice(
      voiceId: 'lw-deep',
      speed: 1.1,
      style: VoiceStyle.energetic,
    );
    h.checkIns.days['2026-10-13'] = const CheckIn(
      date: '2026-10-13',
      mood: 4,
      gentleDay: false,
    );
    await h.boot(tester);
    await openStudio(tester);
    // From a coach built for you back to a ready-made one.
    await tapKey(tester, 'coach-navy_turban');
    await tapKey(tester, 'studio-save-avatar');
    expect(h.avatars.saved!.source, CoachSource.readyMade);
    expect(h.avatars.saved!.coach, ReadyCoach.navyTurban);
    expect(h.avatars.saved!.coachName, 'Asha', reason: 'the name stays');
    expect(
      h.voices.chosen,
      const VoiceChoice(
        voiceId: 'lw-deep',
        speed: 1.1,
        style: VoiceStyle.energetic,
      ),
    );
    expect(h.checkIns.days.keys, ['2026-10-13']);
    expect(h.checkIns.saves, 0);
  });

  group('Build my own and Adjust (Step 1, FR-AVT-02)', () {
    testWidgets('Build my own: every category, then "Make my coach"', (
      tester,
    ) async {
      final h = signedIn(flags: maker);
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-build');
      expect(find.byKey(const Key('studio-build-options')), findsOneWidget);
      // The inclusive lists (FR-AVT-02).
      for (final key in [
        'avatar-opt-body_type-broad',
        'avatar-opt-head_covering-kippah',
        'avatar-opt-accessories-wheelchair',
        'avatar-opt-accessories-hearing_aid',
        'avatar-opt-hairstyle-locs',
      ]) {
        await reveal(tester, key);
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      await tapKey(tester, 'avatar-opt-body_type-broad');
      await tapKey(tester, 'avatar-opt-head_covering-kippah');
      await tapKey(tester, 'studio-build-make');
      final (source, options) = h.avatarMaker.requests.single;
      expect(source, 'built');
      expect(options['body_type'], 'broad');
      expect(options['head_covering'], 'kippah');
      // A full choice: one option per category.
      expect(options.length, 17);
      // The coach is being made; we say so and it can be left.
      await toTop(tester);
      expect(find.byKey(const Key('studio-making')), findsOneWidget);
      // The watcher asks the service and the coach arrives.
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('studio-making')), findsNothing);
    });

    testWidgets('a refusal is said kindly, with what to do instead', (
      tester,
    ) async {
      final h = signedIn(flags: maker);
      h.avatarMaker.refuse = const AvatarMakerError('avatar_daily_limit');
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-build');
      await tapKey(tester, 'studio-build-make');
      expect(
        find.textContaining("You've made 3 coaches today"),
        findsOneWidget,
      );
    });

    testWidgets('Adjust a ready-made coach: offers Build my own instead', (
      tester,
    ) async {
      final h = signedIn(flags: maker);
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-adjust');
      expect(find.byKey(const Key('studio-adjust-ready-made')), findsOneWidget);
      await tapKey(tester, 'studio-adjust-to-build');
      expect(find.byKey(const Key('studio-build-options')), findsOneWidget);
      expect(h.avatarMaker.requests, isEmpty);
    });

    testWidgets('Adjust a made-for-you coach: only the changes are sent', (
      tester,
    ) async {
      final h = signedIn(flags: maker);
      h.avatars.saved = const CoachChoice(
        source: CoachSource.built,
        framesVersion: 2,
      );
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-adjust');
      expect(find.byKey(const Key('studio-adjust-options')), findsOneWidget);
      // Face, skin, age and build aren't changed by Adjust.
      expect(find.byKey(const Key('avatar-opt-skin-tone_1')), findsNothing);
      await reveal(tester, 'studio-adjust-make');
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const Key('studio-adjust-make')),
            )
            .onPressed,
        isNull,
        reason: 'nothing to change yet',
      );
      await tapKey(tester, 'avatar-opt-glasses-round');
      await tapKey(tester, 'avatar-opt-outfit_colour-plum');
      // Tapping a chosen one again un-chooses it.
      await tapKey(tester, 'avatar-opt-glasses-round');
      await tapKey(tester, 'studio-adjust-make');
      final (source, changes) = h.avatarMaker.requests.single;
      expect(source, 'adjust');
      expect(changes, {'outfit_colour': 'plum'});
      // Let the job finish (the watcher asks every 10 s).
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
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

    testWidgets('clone, loved one and Dr. Gokula off: not shown, no consent '
        'banner, no "Coming soon"', (tester) async {
      await signedIn().boot(tester);
      await openStudio(tester, row: 'profile-voice');
      for (final id in ['voice-own', 'voice-loved-one', 'voice-dr-gokula']) {
        expect(find.byKey(Key(id)), findsNothing, reason: id);
      }
      expect(find.textContaining('oming soon'), findsNothing);
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

    testWidgets('Dr. Gokula flag on but the voice not in the library yet: '
        'still hidden, never a row that can\'t be chosen', (tester) async {
      await signedIn(flags: const FeatureFlags(drGokulaVoice: true))
          .boot(tester);
      await openStudio(tester, row: 'profile-voice');
      expect(find.byKey(const Key('voice-dr-gokula')), findsNothing);
    });

    testWidgets('loved-one flag on (Phase 2): the row shows', (tester) async {
      await signedIn(flags: const FeatureFlags(lovedOneVoice: true))
          .boot(tester);
      await openStudio(tester, row: 'profile-voice');
      await tester.scrollUntilVisible(
        find.byKey(const Key('voice-loved-one')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester
            .widget<VoiceRow>(find.byKey(const Key('voice-loved-one')))
            .detail,
        'AI voice',
      );
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
    testWidgets('pick a colour and save; no scene placeholders', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = const CoachChoice(coach: ReadyCoach.shortCurls);
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-tab-background');
      await tapKey(tester, 'studio-bg-3');
      await toTop(tester);
      expect(previewBackground(tester), AvatarColours.background[3]);
      await tapKey(tester, 'studio-save-avatar');
      expect(h.avatars.saved!.background, 3);
      expect(h.avatars.saved!.coach, ReadyCoach.shortCurls, reason: 'kept');
      // Scenes come with their art; until then they aren't shown at all.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('studio-scene-'),
        ),
        findsNothing,
      );
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
          // No textContrastGuideline: it reads screenshot pixels over the whole
          // coach tile (one button) and counts the circle's green ring against
          // the label. Label and surface pairs are checked exactly in
          // test/design/tokens_test.dart.
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
        await signedIn(
          flags: const FeatureFlags(avatarMaker: true, avatarFromPhoto: true),
        ).boot(tester);
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openStudio(tester);
        for (final (tab, last) in [
          ('coaches', 'studio-save-avatar'),
          ('photo', 'photo-start'),
          ('build', 'studio-build-make'),
          ('adjust', 'studio-adjust-to-build'),
          ('background', 'studio-save-avatar'),
          ('voice', 'studio-save-voice'),
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
        // "Make my coach" started a job: let it finish.
        await tester.pump(const Duration(seconds: 25));
        await tester.pumpAndSettle();
      });
    }
  });
}
