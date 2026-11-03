@Tags(['walkthrough'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/avatar/application/coach_job_watcher.dart';
import 'package:livewell/features/avatar/data/avatar_maker_api.dart';

import '../studio/studio_test.dart' show openStudio, tapKey;
import 'from_photo_test.dart' show face, photoOn, settle;

/// Screenshots of "Make me from my photo" (T-AVT-08e), light and dark, with
/// the faked camera (its picture area stays empty in a test). Only on demand:
///   flutter test --update-goldens --run-skipped --tags walkthrough test/avatar/from_photo_evidence_test.dart
void main() {
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('from my photo ($theme)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final h = photoOn();
      h.avatarMaker.statuses = [
        const AvatarJobStatus(status: 'running'),
        const AvatarJobStatus(status: 'running'),
        const AvatarJobStatus(status: 'rejected', messageId: 'avatar_not_made'),
      ];
      await h.boot(tester);
      tester.view.physicalSize = const Size(1080, 2700);
      var n = 0;
      Future<void> shot(String name) async {
        n++;
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('frames/photo_${theme}_${n}_$name.png'),
        );
      }

      await openStudio(tester);
      await tapKey(tester, 'studio-tab-photo');
      await shot('intro');
      await tapKey(tester, 'photo-start');
      await shot('consent');
      await tester.tap(find.byKey(const Key('photo-consent-yes')));
      await tester.pumpAndSettle();
      h.selfieCapture.see(face());
      await settle(tester);
      await shot('blink');
      h.selfieCapture.blink();
      await settle(tester);
      await shot('ready');
      await tester.tap(find.byKey(const Key('selfie-take')));
      await settle(tester);
      await shot('making');
      for (var i = 0; i < 3; i++) {
        await tester.pump(CoachJobWatcher.pollEvery);
      }
      await settle(tester);
      await shot('not_made');
    });
  }
}
