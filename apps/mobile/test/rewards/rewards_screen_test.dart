import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/routing/router.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/goals/domain/goal.dart';
import 'package:livewell/features/rewards/domain/reward_rules.dart';
import 'package:livewell/features/rewards/presentation/rewards_screen.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../plan/plan_screen_test.dart' show openTab, scrollTo;
import '../support/app_harness.dart';

/// T-GAM-01: badges, challenges and unlockables. Off in staging and prod
/// (not even routable) until the copy is reviewed; on in dev (D-87).
void main() {
  const week = '2026-10-12'; // Harness "now" is Wed 2026-10-14.

  /// Done logs on the days before "now", for the streak engine.
  void doneOn(Harness h, List<String> dates) {
    for (final d in dates) {
      h.goals.logs['${d}_$dailyStepHabitId'] = HabitLog(
        date: d,
        habitId: dailyStepHabitId,
      );
    }
  }

  Future<void> openRewards(WidgetTester tester) async {
    await openTab(tester, 'Track');
    expect(find.byType(TrackScreen), findsOneWidget);
    await scrollTo(tester, find.byKey(const Key('track-rewards')));
    await tester.tap(find.byKey(const Key('track-rewards')));
    await tester.pumpAndSettle();
    expect(find.byType(RewardsScreen), findsOneWidget);
  }

  for (final flavor in [Flavor.staging, Flavor.prod]) {
    testWidgets('${flavor.name}: Track has no badges card', (tester) async {
      final h = signedIn(flavor: flavor);
      doneOn(h, ['2026-10-12', '2026-10-13']);
      await h.boot(tester);
      await openTab(tester, 'Track');
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('track-reflection')), findsOneWidget);
      expect(find.byKey(const Key('track-rewards')), findsNothing);
    });

    test('${flavor.name}: the rewards screen is not registered', () {
      final container = ProviderContainer(
        overrides: [flavorProvider.overrideWithValue(flavor)],
      );
      addTearDown(container.dispose);
      final match = container
          .read(routerProvider)
          .configuration
          .findMatch(Uri.parse(RewardsScreen.path));
      expect(match.matches, isEmpty);
    });
  }

  test('dev: the rewards screen is registered', () {
    final container = ProviderContainer(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
    );
    addTearDown(container.dispose);
    final match = container
        .read(routerProvider)
        .configuration
        .findMatch(Uri.parse(RewardsScreen.path));
    expect(match.matches, isNotEmpty);
  });

  testWidgets('dev: earned badges show, are kept, and unlock looks', (
    tester,
  ) async {
    final h = signedIn(flavor: Flavor.dev);
    // A missed Sunday... then back on Monday: first step and a Restart.
    doneOn(h, ['2026-10-10', '2026-10-12', '2026-10-13']);
    await h.boot(tester);
    await openRewards(tester);
    expect(
      find.byKey(const Key('rewards-badge-first_step-earned')),
      findsOneWidget,
    );
    await scrollTo(
      tester,
      find.byKey(const Key('rewards-badge-restart-earned')),
    );
    expect(
      find.byKey(const Key('rewards-badge-steady_30-not-yet')),
      findsOneWidget,
    );
    // Saved, so they stay earned.
    expect(h.rewards.badges.keys, containsAll(['first_step', 'restart']));
    // Unlocks: first_step -> Meadow; restart -> Sand and Stars.
    await scrollTo(
      tester,
      find.byKey(const Key('rewards-unlock-bg_sand-open')),
    );
    expect(
      find.byKey(const Key('rewards-unlock-bg_blossom-locked')),
      findsOneWidget,
    );
    await scrollTo(tester, find.byKey(const Key('rewards-celebration-stars')));
    await tester.tap(find.byKey(const Key('rewards-celebration-stars')));
    await tester.pumpAndSettle();
    expect(h.rewards.celebration, 'stars');
  });

  testWidgets('dev: quiet by default for real accounts (72 h unknown)', (
    tester,
  ) async {
    // Safety events aren't recorded yet (D-22): unknown counts as not
    // clear, so no challenge invitation and no "how to earn" nudges.
    final h = signedIn(flavor: Flavor.dev);
    await h.boot(tester);
    await openRewards(tester);
    expect(find.byKey(const Key('rewards-challenge-quiet')), findsOneWidget);
    expect(find.byKey(const Key('rewards-challenge-join')), findsNothing);
    expect(find.text('Not yet'), findsWidgets);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('dev: a gentle day keeps challenges quiet too', (tester) async {
    final h = signedIn(flavor: Flavor.dev)..safetyClear = true;
    h.checkIns.days['2026-10-14'] = const CheckIn(
      date: '2026-10-14',
      mood: 1,
      gentleDay: true,
    );
    await h.boot(tester);
    await openRewards(tester);
    expect(find.byKey(const Key('rewards-challenge-quiet')), findsOneWidget);
  });

  testWidgets('dev: join this week\'s challenge, then mark today once', (
    tester,
  ) async {
    final h = signedIn(flavor: Flavor.dev)..safetyClear = true;
    await h.boot(tester);
    await openRewards(tester);
    // Activity check never answered: only non-movement challenges.
    final week0 = h.rewards.challenges[week];
    expect(week0, isNull);
    final join = find.byKey(const Key('rewards-challenge-join'));
    expect(join, findsOneWidget);
    // One primary action on the screen.
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(join);
    await tester.pumpAndSettle();
    final entry = h.rewards.challenges[week]!;
    expect([
      'post_meal_walk',
      'strength_balance',
    ], isNot(contains(entry.challengeId)));
    expect(find.byKey(const Key('rewards-challenge-progress')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rewards-challenge-mark')));
    await tester.pumpAndSettle();
    expect(h.rewards.challenges[week]!.days, {'2026-10-14'});
    expect(
      find.byKey(const Key('rewards-challenge-done-today')),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('dev: a finished challenge earns its badge', (tester) async {
    final h = signedIn(flavor: Flavor.dev)..safetyClear = true;
    h.rewards.challenges['2026-10-05'] = const ChallengeEntry(
      week: '2026-10-05',
      challengeId: 'steady_bedtime',
      days: {'2026-10-05', '2026-10-06', '2026-10-08'},
    );
    await h.boot(tester);
    await openRewards(tester);
    await scrollTo(
      tester,
      find.byKey(const Key('rewards-badge-challenge_1-earned')),
    );
    expect(h.rewards.badges.keys, contains('challenge_1'));
  });

  testWidgets('prod: flags on (after review) shows the same screen', (
    tester,
  ) async {
    final h = signedIn(
      flavor: Flavor.prod,
      flags: const FeatureFlags(rewards: true),
    );
    await h.boot(tester);
    await openRewards(tester);
  });

  test('unlocked backgrounds are valid coach backgrounds (0..12)', () {
    expect(coachBackgrounds, 13);
    expect(CoachChoice.fromMap(const {'background': 12}).background, 12);
    expect(CoachChoice.fromMap(const {'background': 13}).background, 0);
  });
}
