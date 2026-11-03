@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';

import 'plan_preview_test.dart' show atPlan, today;

/// "Your 7 days" (T-ONB-03e), light and dark, normal and 200% text.
/// Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      final name =
          'plan_preview_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
      testWidgets(name, (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await atPlan(
          focus: const ['move_more', 'sleep_better'],
          checkIn: const CheckIn(
            date: today,
            mood: 4,
            timeAvailable: 10,
            gentleDay: false,
          ),
        ).boot(tester);
        tester.view.physicalSize = Size(1080, large ? 12000 : 6200);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
