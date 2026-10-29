import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';
import 'package:livewell/features/voice/data/voice_repository.dart';
import 'package:livewell/features/studio/presentation/studio_widgets.dart';
import 'package:livewell/features/voice/domain/voice.dart';
import 'package:livewell/features/voice/presentation/voice_library_screen.dart';
import 'package:livewell/features/voice/presentation/voice_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';

/// Signed in, at the voice step.
Harness atVoice({String? name, FeatureFlags flags = const FeatureFlags()}) {
  final h = Harness(
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
    flags: flags,
  );
  h.profiles.existing[uid] = ProfileStep.voice;
  if (name != null) h.profiles.names[uid] = name;
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  test('resumes at the voice step (FR-ONB-06)', () {
    expect(routeForProfileStep(ProfileStep.voice), '/onboarding/voice');
  });

  test('speed stays within 0.8x to 1.2x', () {
    expect(VoiceChoice.fallback.copyWith(speed: 2).speed, 1.2);
    expect(VoiceChoice.fallback.copyWith(speed: 0.1).speed, 0.8);
  });

  test('6 library voices, each with a bundled calm and energetic preview', () {
    expect(VoiceLibrary.all, hasLength(greaterThanOrEqualTo(6)));
    expect(VoiceLibrary.all.map((v) => v.id).toSet(), hasLength(6));
    for (final v in VoiceLibrary.all) {
      expect(v.id, matches(RegExp(r'^lw-[a-z0-9-]{1,30}$')), reason: 'rules');
      for (final s in VoiceStyle.values) {
        expect(File(v.previewAsset(s)).existsSync(), isTrue, reason: v.id);
      }
    }
    expect(File(VoiceLibrary.greetingAsset).existsSync(), isTrue);
    final licences = File('../../docs/voices.md').readAsStringSync();
    for (final v in VoiceLibrary.all) {
      expect(licences, contains('`${v.id}`'), reason: 'licence recorded');
    }
  });

  group('default voice', () {
    testWidgets('greets in the default voice, with the AI voice label', (
      tester,
    ) async {
      final h = atVoice(name: 'Priya Shah');
      final handle = tester.ensureSemantics();
      await h.boot(tester);
      expect(find.text('Choose your coach’s voice'), findsOneWidget);
      expect(find.text('Hi Priya, I’m your Live Well coach.'), findsOneWidget);
      expect(find.bySemanticsLabel('This is an AI voice'), findsOneWidget);
      expect(h.player.played, [(VoiceLibrary.greetingAsset, 1.0)]);
      await tapKey(tester, 'voice-replay');
      expect(h.player.played, hasLength(2));
      handle.dispose();
    });

    for (final key in ['voice-ok', 'voice-skip']) {
      testWidgets('$key: default voice saved, then the Why', (tester) async {
        final h = atVoice();
        await h.boot(tester);
        await tapKey(tester, key);
        expect(h.voices.chosen, VoiceChoice.fallback);
        expect(h.profiles.existing[uid], ProfileStep.why);
        expect(h.voiceDrafts.draft, isNull);
        expect(h.player.stops, greaterThan(0));
        expect(find.byType(WhyScreen), findsOneWidget);
      });
    }

    testWidgets('a save error says so and stays', (tester) async {
      final h = atVoice();
      h.voices.fail = true;
      await h.boot(tester);
      await tapKey(tester, 'voice-ok');
      expect(
        find.text('We couldn’t save your coach’s voice. Please try again.'),
        findsOneWidget,
      );
      expect(h.profiles.existing[uid], ProfileStep.voice);
    });
  });

  group('choose another voice', () {
    testWidgets('the settings say how the voice is made (FR-VOC-08)', (
      tester,
    ) async {
      await atVoice().boot(tester);
      await tapKey(tester, 'voice-another');
      await tester.scrollUntilVisible(
        find.byKey(const Key('voice-how-made')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('How this voice is made'), findsOneWidget);
      expect(find.textContaining('text-to-speech'), findsOneWidget);
      expect(
        find.textContaining('not a copy of a real person'),
        findsOneWidget,
      );
    });

    testWidgets('preview, style, speed, then use it', (tester) async {
      final h = atVoice();
      await h.boot(tester);
      await tapKey(tester, 'voice-another');
      expect(find.byType(VoiceLibraryScreen), findsOneWidget);
      expect(find.byKey(const Key('ai-voice-label')), findsOneWidget);

      await tapKey(tester, 'voice-play-lw-clear');
      expect(h.player.played.last, ('assets/voices/lw-clear_calm.m4a', 1.0));

      // Back to the top of the library, where the style buttons are.
      await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Energetic'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const Key('voice-speed')),
      );
      slider.onChanged!(1.2);
      await tester.pumpAndSettle();
      expect(find.text('1.2x'), findsOneWidget);
      await tapKey(tester, 'voice-play-lw-clear');
      expect(h.player.played.last, (
        'assets/voices/lw-clear_energetic.m4a',
        1.2,
      ));

      await tapKey(tester, 'voice-use');
      expect(
        h.voices.chosen,
        const VoiceChoice(
          voiceId: 'lw-clear',
          speed: 1.2,
          style: VoiceStyle.energetic,
        ),
      );
      expect(find.byType(WhyScreen), findsOneWidget);
    });

    testWidgets('closed script: only bundled previews are ever played', (
      tester,
    ) async {
      final h = atVoice();
      await h.boot(tester);
      await tapKey(tester, 'voice-another');
      for (final v in VoiceLibrary.all) {
        await tapKey(tester, 'voice-play-${v.id}');
      }
      for (final (asset, _) in h.player.played) {
        expect(asset, startsWith('assets/voices/'));
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });

    testWidgets('closing the app in the library: it reopens there', (
      tester,
    ) async {
      final h = atVoice();
      h.voiceDrafts.draft = const VoiceDraft(
        choice: VoiceChoice(
          voiceId: 'lw-gentle',
          speed: 0.9,
          style: VoiceStyle.energetic,
        ),
        inLibrary: true,
      );
      await h.boot(tester);
      expect(find.byType(VoiceLibraryScreen), findsOneWidget);
      final row = tester.widget<VoiceRow>(
        find.byKey(const Key('voice-lw-gentle')),
      );
      expect(row.selected, isTrue);
      expect(row.status, 'Active');
      expect(find.text('0.9x'), findsOneWidget);
    });

    testWidgets('going back keeps the choice but not the library', (
      tester,
    ) async {
      final h = atVoice();
      await h.boot(tester);
      await tapKey(tester, 'voice-another');
      await tapKey(tester, 'voice-lw-steady');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(VoiceScreen), findsOneWidget);
      expect(h.voiceDrafts.draft!.inLibrary, isFalse);
      expect(h.voiceDrafts.draft!.choice.voiceId, 'lw-steady');
    });
  });

  group('use my own voice', () {
    testWidgets('flag off: not shown at all (Step 4d, no dead ends)', (
      tester,
    ) async {
      await atVoice().boot(tester);
      expect(find.byKey(const Key('voice-own')), findsNothing);
      expect(find.textContaining('oming soon'), findsNothing);
    });

    testWidgets('flag on: an entry point that explains, builds nothing', (
      tester,
    ) async {
      final h = atVoice(flags: const FeatureFlags(voiceClone: true));
      await h.boot(tester);
      await tapKey(tester, 'voice-own');
      expect(find.byKey(const Key('voice-own-sheet')), findsOneWidget);
      expect(h.voices.chosen, isNull);
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets('voice step and library (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await atVoice().boot(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tapKey(tester, 'voice-another');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(find.byTooltip('Play Warm'), findsOneWidget);
        handle.dispose();
      });
    }
  });
}
