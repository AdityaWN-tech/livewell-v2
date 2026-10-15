@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_flow_test.dart' show atVoice, tapKey;

/// "Choose your coach's voice" and the library (T-ONB-03c), light and
/// dark, normal and 200% text. Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      for (final screen in ['voice', 'library']) {
        final name =
            '${screen}_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await atVoice(name: 'Priya Shah').boot(tester);
          tester.view.physicalSize = Size(1080, large ? 5600 : 2900);
          await tester.pumpAndSettle();
          if (screen == 'library') {
            await tapKey(tester, 'voice-another');
            await tapKey(tester, 'voice-lw-gentle');
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
