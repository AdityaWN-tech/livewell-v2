@Tags(['walkthrough'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../studio/studio_test.dart' show openStudio, signedIn;
import 'anime_style_test.dart' show tapKey;

/// Saves a frame after every step of switching the coach's style in the
/// Studio (T-AVT-06a), light then dark, for the evidence video
/// (docs/evidence/T-AVT-06/style_switch.mp4). Only on demand:
///   flutter test --update-goldens --run-skipped --tags walkthrough test/avatar
void main() {
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('style switch frames ($theme)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      var n = 0;
      Future<void> frame(String step) async {
        n++;
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'frames/${theme}_${n.toString().padLeft(2, '0')}_$step.png',
          ),
        );
      }

      await signedIn().boot(tester);
      await openStudio(tester);
      await frame('studio_illustrated');
      await tapKey(tester, 'avatar-style-anime');
      await frame('studio_anime');
      await tapKey(tester, 'avatar-style-illustrated');
      await frame('back_to_illustrated');
      await tapKey(tester, 'avatar-style-anime');
      await tapKey(tester, 'studio-customize');
      await frame('creator_face');
      for (final (tab, option) in [
        ('eye_highlight', 'star'),
        ('hair', 'braids'),
        ('bangs', 'curtain'),
        ('cap', 'beanie'),
      ]) {
        await tapKey(tester, 'avatar-tab-$tab');
        await tapKey(tester, 'avatar-anime-$tab-$option');
        await frame('${tab}_$option');
      }
      await tapKey(tester, 'avatar-tab-bangs');
      await frame('bangs_hidden_by_cap');
      await tapKey(tester, 'avatar-tab-background');
      await tapKey(tester, 'avatar-background-1');
      await frame('background_peach');
      await tapKey(tester, 'avatar-style-illustrated');
      await frame('creator_illustrated');
    });
  }
}
