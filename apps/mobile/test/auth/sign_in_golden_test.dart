@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import 'sign_in_flow_test.dart' show readyStore;

/// Sign-in screen with the Google and Apple icons (T-ONB-03a), light and
/// dark, normal and 200% text. Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      final name =
          'sign_in_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
      testWidgets(name, (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await Harness(store: readyStore()).boot(tester);
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        if (large) tester.view.physicalSize = const Size(1080, 3600);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
