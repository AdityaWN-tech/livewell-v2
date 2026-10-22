import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
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

/// T-ONB-03b after T-AVT-08a: the cartoon creator, the 7 cartoon characters
/// and the selfie suggestion are gone; the 3D Avatar Studio replaces them
/// in T-AVT-08b. The step shows the coach and never blocks.
void main() {
  test('resumes at the avatar step (FR-ONB-06)', () {
    expect(routeForProfileStep(ProfileStep.avatar), '/onboarding/avatar');
  });

  test('style_config round-trips, and bad values fall back safely', () {
    final c = AvatarConfig.forLook(AvatarLook.woman)
        .copyWith(skin: 9, headCovering: HeadCovering.hijab, background: 3);
    expect(AvatarConfig.fromMap(c.toMap()), c);
    final bad = AvatarConfig.fromMap({'skin': 99, 'hair': 'mohawk'});
    expect(bad.skin, AvatarConfig.fallback.skin);
    expect(bad.hair, AvatarConfig.fallback.hair);
  });

  testWidgets('shows the coach and what is coming; no creator, characters '
      'or selfie', (tester) async {
    await atAvatar().boot(tester);
    expect(find.byType(AvatarScreen), findsOneWidget);
    expect(find.byKey(const Key('avatar-preview')), findsOneWidget);
    expect(find.byKey(const Key('avatar-more-soon')), findsOneWidget);
    for (final gone in [
      'avatar-cartoon',
      'avatar-selfie',
      'avatar-skip',
      'avatar-character-hoodie',
      'studio-next',
    ]) {
      expect(find.byKey(Key(gone)), findsNothing, reason: gone);
    }
  });

  testWidgets('Continue saves the default and goes to the voice step', (
    tester,
  ) async {
    final h = atAvatar();
    await h.boot(tester);
    await tapKey(tester, 'avatar-use');
    expect(h.avatars.saved, AvatarConfig.fallback);
    expect(h.profiles.existing[uid], ProfileStep.voice);
    expect(find.byType(VoiceScreen), findsOneWidget);
  });

  testWidgets('a save error says so and stays', (tester) async {
    final h = atAvatar();
    h.avatars.fail = true;
    await h.boot(tester);
    await tapKey(tester, 'avatar-use');
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
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(find.bySemanticsLabel('Your coach'), findsOneWidget);
        handle.dispose();
      });
    }
  });
}
