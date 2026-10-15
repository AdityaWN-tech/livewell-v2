@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';

import 'focus_flow_test.dart' show at, tapKey;

/// First check-in, focus choice and the activity check (T-ONB-03d), light
/// and dark, normal and 200% text. Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      for (final screen in ['checkin', 'focus', 'activity', 'limited']) {
        if (screen == 'checkin' && large) continue;
        final name =
            '${screen}_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final h = at(
            screen == 'checkin' ? ProfileStep.checkin : ProfileStep.focus,
          );
          await h.boot(tester);
          tester.view.physicalSize = Size(1080, large ? 5200 : 2400);
          await tester.pumpAndSettle();
          if (screen != 'checkin') {
            await tapKey(tester, 'focus-move_more');
            await tapKey(tester, 'focus-sleep_better');
          }
          if (screen == 'activity' || screen == 'limited') {
            await tapKey(tester, 'focus-continue');
          }
          if (screen == 'limited') await tapKey(tester, 'activity-yes');
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
