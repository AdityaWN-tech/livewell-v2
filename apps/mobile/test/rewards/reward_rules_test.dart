import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/rewards/domain/reward_catalog.dart';
import 'package:livewell/features/rewards/domain/reward_rules.dart';
import 'package:livewell/features/track/domain/streak.dart';

/// T-GAM-01: the fixed rules behind badges, unlocks and challenges.
void main() {
  final catalog = RewardCatalog.parse(
    File('../../content/rewards/catalog.json').readAsStringSync(),
  );

  group('badges', () {
    test('nothing earned before anything is done', () {
      expect(RewardRules.earned(catalog, const RewardProgress()), isEmpty);
    });

    test('earned from consistency, recovery, learning and challenges', () {
      final earned = RewardRules.earned(
        catalog,
        const RewardProgress(
          daysDone: 10,
          bestStreak: 8,
          restarts: 1,
          lessonsCompleted: 1,
          challengesCompleted: 1,
        ),
      );
      expect(earned, {
        'first_step',
        'steady_7',
        'restart',
        'lesson_1',
        'challenge_1',
      });
    });

    test('unlocks come only from earned badges', () {
      final unlocked = RewardRules.unlocked(catalog, {'restart'});
      expect(
        unlocked.map((u) => u.id),
        unorderedEquals(['bg_sand', 'anim_stars']),
      );
      expect(unlocked.every((u) => u.cosmetic), isTrue);
      expect(RewardRules.unlocked(catalog, const {}), isEmpty);
    });
  });

  group('the Restart badge comes from the streak engine (FR-DLY-07)', () {
    final now = DateTime(2026, 10, 30); // a Friday

    test('coming back after a missed day counts as a restart', () {
      final s = streakFrom({'2026-10-26', '2026-10-28', '2026-10-29'}, now)!;
      expect(s.restarts, 1);
      // The rest day is the week's grace: the streak didn't break.
      expect(s.length, 3);
    });

    test('a day without a step today is not a restart yet', () {
      final s = streakFrom({'2026-10-28', '2026-10-29'}, now)!;
      expect(s.restarts, 0);
    });

    test('two breaks and two returns: two restarts', () {
      final s = streakFrom({
        '2026-10-19',
        '2026-10-21',
        '2026-10-22',
        '2026-10-25',
        '2026-10-26',
      }, now)!;
      expect(s.restarts, 2);
    });
  });

  group('challenges', () {
    test('movement only after the activity check said "no limits"', () {
      List<String> ids(bool? limited) => RewardRules.offered(
        catalog,
        activityLimited: limited,
        edSafeMode: false,
      ).map((c) => c.id).toList();
      expect(ids(false), contains('post_meal_walk'));
      // Limited, or never asked: no movement (the conservative choice).
      for (final limited in [true, null]) {
        expect(ids(limited), isNot(contains('post_meal_walk')));
        expect(ids(limited), isNot(contains('strength_balance')));
        expect(ids(limited), contains('steady_bedtime'));
      }
    });

    test('nothing about food in eating-disorder safe mode', () {
      final offered = RewardRules.offered(
        catalog,
        activityLimited: false,
        edSafeMode: true,
      );
      expect(offered.any((c) => c.food), isFalse);
      expect(offered, isNotEmpty);
    });

    test('one challenge a week, the same all week, turning weekly', () {
      final offered = catalog.challenges;
      final a = RewardRules.forWeek(offered, '2026-10-26');
      final b = RewardRules.forWeek(offered, '2026-11-02');
      expect(a, isNotNull);
      expect(a!.id, isNot(b!.id));
      expect(RewardRules.forWeek(offered, '2026-10-26')!.id, a.id);
      expect(RewardRules.forWeek(const [], '2026-10-26'), isNull);
      expect(RewardRules.weekOf(DateTime(2026, 10, 30, 21)), '2026-10-26');
      expect(RewardRules.weekOf(DateTime(2026, 10, 26)), '2026-10-26');
    });

    test('finished on the target number of days, one mark a day', () {
      final c = catalog.challenge('steady_bedtime')!;
      var e = const ChallengeEntry(
        week: '2026-10-26',
        challengeId: 'steady_bedtime',
      );
      e = e.withDay('2026-10-26').withDay('2026-10-26').withDay('2026-10-27');
      expect(e.days.length, 2);
      expect(e.completeFor(c), isFalse);
      expect(e.withDay('2026-10-29').completeFor(c), isTrue);
    });
  });

  group('quiet: no pressure around a hard time (D-87)', () {
    test('gentle day, safe mode or a safety event not ruled out', () {
      bool quiet({bool g = false, bool ed = false, bool clear = true}) =>
          RewardRules.quiet(gentleDay: g, edSafeMode: ed, safetyClear: clear);
      expect(quiet(), isFalse);
      expect(quiet(g: true), isTrue);
      expect(quiet(ed: true), isTrue);
      // Unknown counts as not clear (the 72-hour rule, as for portal cards).
      expect(quiet(clear: false), isTrue);
    });
  });
}
