@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_test.dart' show bootToShell;

/// Full-shell golden images at phone size, light + dark (T-FND-04).
/// Regenerate after an intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    testWidgets('shell golden at phone size (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625; // Pixel-class phone, 411 x 914 dp
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await bootToShell(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shell_home_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
