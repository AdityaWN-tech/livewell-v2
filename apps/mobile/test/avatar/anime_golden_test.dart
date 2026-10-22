@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../studio/studio_test.dart' show openStudio, signedIn;
import 'anime_style_test.dart' show tapKey;

/// T-AVT-06a golden images: the Studio after picking Anime, and the
/// creator on an Anime tab, light and dark, text at 100% and 200%.
/// Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final screen in ['studio', 'creator']) {
    for (final dark in [false, true]) {
      for (final (label, scale) in [('normal', 1.0), ('large', 2.0)]) {
        final name = 'anime_${screen}_${dark ? 'dark' : 'light'}_$label';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await signedIn().boot(tester);
          await openStudio(tester);
          await tapKey(tester, 'avatar-style-anime');
          if (screen == 'creator') {
            await tapKey(tester, 'studio-customize');
            await tapKey(tester, 'avatar-tab-eye_highlight');
            await tapKey(tester, 'avatar-anime-eye_highlight-star');
          }
          tester.view.physicalSize = Size(1080, scale > 1 ? 6000 : 3000);
          await tester.pumpAndSettle();
          // Back to the top, where the switch and preview are.
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 6000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
