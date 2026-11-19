@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/goals/domain/goal.dart';
import 'package:livewell/features/rewards/domain/reward_rules.dart';
import 'package:livewell/features/rewards/presentation/rewards_screen.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../plan/plan_screen_test.dart' show openTab, scrollTo;

/// Badges and challenges (T-GAM-01) golden images: a joined challenge, a
/// few badges earned and their unlocks, light and dark, text at 100% and
/// 200%. Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  const size = Size(1080, 2400);
  const dpr = 2.625;
  for (final dark in [false, true]) {
    for (final (label, scale) in [('normal', 1.0), ('large', 2.0)]) {
      final name = 'rewards_${dark ? 'dark' : 'light'}_$label';
      testWidgets(name, (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final h = signedIn(flavor: Flavor.dev)..safetyClear = true;
        for (final d in ['2026-10-10', '2026-10-12', '2026-10-13']) {
          h.goals.logs['${d}_$dailyStepHabitId'] = HabitLog(
            date: d,
            habitId: dailyStepHabitId,
          );
        }
        h.rewards.challenges['2026-10-12'] = const ChallengeEntry(
          week: '2026-10-12',
          challengeId: 'steady_bedtime',
          days: {'2026-10-13'},
        );
        await h.boot(tester);
        await openTab(tester, 'Track');
        await scrollTo(tester, find.byKey(const Key('track-rewards')));
        await tester.tap(find.byKey(const Key('track-rewards')));
        await tester.pumpAndSettle();
        expect(find.byType(RewardsScreen), findsOneWidget);
        // Tall enough that the whole screen is in the image.
        final needed = size.height / dpr * (2.4 + (scale - 1) * 3.2);
        tester.view
          ..physicalSize = Size(size.width, needed * dpr)
          ..devicePixelRatio = dpr;
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
