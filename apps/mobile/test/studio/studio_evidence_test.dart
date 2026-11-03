@Tags(['walkthrough'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/domain/coaches.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import 'studio_test.dart' show openStudio, tapKey, toTop;

/// Screenshots of the Avatar Studio in a dev build (placeholder coach
/// frames), light and dark, for the T-AVT-08b evidence. Only on demand:
///   flutter test --update-goldens --run-skipped --tags walkthrough test/studio/studio_evidence_test.dart
void main() {
  Future<void> decode(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await decode(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('frames/$name.png'),
    );
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('studio ($theme)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      for (final c in ReadyCoach.values) {
        rootBundle.evict('${c.framesDir}/avatar_frames.json');
      }
      final h = Harness(
        flavor: Flavor.dev,
        auth: FakeAuthService(signedIn: const AuthUser(uid: 'u1')),
      );
      h.profiles.existing['u1'] = ProfileStep.assessment;
      await h.boot(tester);
      tester.view.physicalSize = const Size(1080, 3400);
      await openStudio(tester);
      await tapKey(tester, 'coach-green_hijab');
      await toTop(tester);
      await shot(tester, '${theme}_1_coaches');
      await tapKey(tester, 'studio-tab-background');
      await tapKey(tester, 'studio-bg-1');
      await toTop(tester);
      await shot(tester, '${theme}_2_background');
      await tapKey(tester, 'studio-tab-photo');
      await toTop(tester);
      await shot(tester, '${theme}_3_photo');
    });

    testWidgets('onboarding ($theme)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      for (final c in ReadyCoach.values) {
        rootBundle.evict('${c.framesDir}/avatar_frames.json');
      }
      final h = Harness(
        flavor: Flavor.dev,
        auth: FakeAuthService(signedIn: const AuthUser(uid: 'u1')),
      );
      h.profiles.existing['u1'] = ProfileStep.avatar;
      await h.boot(tester);
      tester.view.physicalSize = const Size(1080, 3400);
      await shot(tester, '${theme}_0_onboarding');
    });
  }
}
