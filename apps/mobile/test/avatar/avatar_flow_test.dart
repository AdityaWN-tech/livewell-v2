import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
import 'package:livewell/features/avatar/domain/coaches.dart';
import 'package:livewell/features/avatar/presentation/avatar_screen.dart';
import 'package:livewell/features/voice/presentation/voice_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';

/// Signed in, at the "Meet your coach" step.
Harness atAvatar() {
  final h = Harness(
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
  );
  h.profiles.existing[uid] = ProfileStep.avatar;
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

bool canUse(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const Key('studio-save-avatar')))
        .onPressed !=
    null;

/// T-ONB-03b with the Avatar Studio (T-AVT-08b): the first step after
/// sign-up. Nothing is guessed: "Use this coach" waits for a pick; "Skip"
/// takes the default coach.
void main() {
  test('resumes at the avatar step (FR-ONB-06)', () {
    expect(routeForProfileStep(ProfileStep.avatar), '/onboarding/avatar');
  });

  group('the avatar document', () {
    test('round-trips; bad values fall back safely', () {
      const c = CoachChoice(
        coach: ReadyCoach.navyTurban,
        coachName: 'Arjun',
        background: 3,
      );
      expect(CoachChoice.fromMap(c.toMap()), c);
      expect(c.toMap()['type'], '3d_adult');
      expect(c.toMap()['source'], 'default');
      expect(c.toMap(), isNot(contains('frames_version')));
      final bad = CoachChoice.fromMap({
        'coach_id': 'nobody',
        'background': 9,
        'coach_name': '   ',
        'source': 'magic',
      });
      expect(bad, CoachChoice.fallback);
    });

    test('an older cartoon document keeps its background', () {
      final old = CoachChoice.fromMap({
        'type': 'stylized',
        'style_config': {'background': 4, 'skin': 2},
      });
      expect((old.coach, old.background), (ReadyCoach.brownHair, 4));
    });

    test('a made-for-you set is read, never written by the app', () {
      final made = CoachChoice.fromMap({
        'type': '3d_adult',
        'source': 'selfie',
        'frames_version': 3,
      });
      expect((made.source, made.framesVersion), (CoachSource.selfie, 3));
      expect(made.toMap(), isNot(contains('frames_version')));
      // Picking a ready-made coach leaves it.
      final picked = made.copyWith(coach: ReadyCoach.shortCurls);
      expect(
        (picked.source, picked.framesVersion),
        (CoachSource.readyMade, null),
      );
    });

    test('names: trimmed, at most 20, letters only', () {
      expect(CoachChoice.cleanName('  Maya '), 'Maya');
      expect(CoachChoice.cleanName(''), isNull);
      expect(CoachChoice.validName('Anne-Marie'), isTrue);
      expect(CoachChoice.validName("D'Souza"), isTrue);
      expect(CoachChoice.validName('R2D2'), isFalse);
      expect(CoachChoice.validName(''), isTrue);
    });
  });

  testWidgets('the 8 coaches; "Use this coach" waits for a pick', (
    tester,
  ) async {
    await atAvatar().boot(tester);
    expect(find.byType(AvatarScreen), findsOneWidget);
    for (final c in ReadyCoach.values) {
      expect(find.byKey(Key('coach-${c.id}')), findsOneWidget, reason: c.id);
    }
    // No Voice tab here: the voice step comes next.
    expect(find.byKey(const Key('studio-tab-voice')), findsNothing);
    expect(canUse(tester), isFalse);
    await tapKey(tester, 'coach-green_hijab');
    expect(canUse(tester), isTrue);
  });

  testWidgets('pick, name and use: saved, then the voice step', (tester) async {
    final h = atAvatar();
    await h.boot(tester);
    await tapKey(tester, 'coach-grey_glasses');
    await tester.enterText(find.byKey(const Key('studio-coach-name')), 'Ravi');
    await tester.pump();
    await tapKey(tester, 'studio-save-avatar');
    expect(
      h.avatars.saved,
      const CoachChoice(coach: ReadyCoach.greyGlasses, coachName: 'Ravi'),
    );
    expect(h.profiles.existing[uid], ProfileStep.voice);
    expect(find.byType(VoiceScreen), findsOneWidget);
  });

  testWidgets('"Skip" never blocks: the default coach', (tester) async {
    final h = atAvatar();
    await h.boot(tester);
    await tapKey(tester, 'avatar-skip');
    expect(h.avatars.saved, CoachChoice.fallback);
    expect(find.byType(VoiceScreen), findsOneWidget);
  });

  testWidgets('a save error says so and stays', (tester) async {
    final h = atAvatar();
    h.avatars.fail = true;
    await h.boot(tester);
    await tapKey(tester, 'avatar-skip');
    expect(
      find.text('We couldn’t save your coach. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(AvatarScreen), findsOneWidget);
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets('the step (${dark ? 'dark' : 'light'})', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await atAvatar().boot(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // No textContrastGuideline: it reads screenshot pixels over the whole
        // coach tile (one button) and counts the circle's green ring against
        // the label. Label and surface pairs are checked exactly in
        // test/design/tokens_test.dart.
        expect(find.bySemanticsLabel('Your coach’s avatar'), findsOneWidget);
        expect(find.bySemanticsLabel('Green hijab, 40s'), findsOneWidget);
        handle.dispose();
      });
    }
  });
}
