@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';

import 'profile_test.dart' show openProfile, signedIn;

/// Profile (T-ONB-03f), light and dark, normal and 200% text.
/// Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      final name =
          'profile_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
      testWidgets(name, (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await signedIn(
          flavor: Flavor.dev,
          providers: ['password', 'google.com'],
        ).boot(tester);
        await openProfile(tester);
        tester.view.physicalSize = Size(1080, large ? 16000 : 9000);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
