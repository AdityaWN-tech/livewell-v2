@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'avatar_flow_test.dart' show atAvatar, tapKey;

/// "Create your coach" and the creator (T-ONB-03b), light and dark, normal
/// and 200% text. Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      for (final screen in ['start', 'creator']) {
        final name =
            'avatar_${screen}_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await atAvatar().boot(tester);
          tester.view.physicalSize = Size(
            1080,
            large ? 6000 : (screen == 'creator' ? 2400 : 3000),
          );
          await tester.pumpAndSettle();
          if (screen == 'creator') {
            await tapKey(tester, 'avatar-cartoon');
            await tapKey(tester, 'avatar-skin-7');
            await tapKey(tester, 'avatar-covering-Hijab');
          } else {
            await tapKey(tester, 'avatar-look-woman');
          }
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
