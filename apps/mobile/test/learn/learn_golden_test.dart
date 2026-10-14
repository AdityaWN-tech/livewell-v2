@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;
import 'learn_screen_test.dart' show openLearn;

/// Learn (T-UI-01e) golden images: a real new account (empty) and the dev
/// preview (sample portal card and lessons), light and dark, normal and 200% text.
/// Regenerate after an intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      for (final state in ['empty', 'preview']) {
        final name =
            'learn_${state}_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          if (state == 'empty') {
            await signedIn().boot(tester);
          } else {
            await bootPreview(tester);
          }
          await openLearn(tester);
          // Taller than a phone at 200% so the whole screen is in the image.
          if (large) {
            tester.view.physicalSize = Size(
              1080,
              state == 'empty' ? 4000 : 6000,
            );
            await tester.pumpAndSettle();
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
