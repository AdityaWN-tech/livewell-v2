import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/rewards/domain/reward_catalog.dart';

/// T-GAM-01 "Done when": FR-GAM-01..03; banned reward types absent.
/// The reward catalogue (content/rewards/catalog.json) is checked here:
/// only consistency, learning, recovery and function are rewarded; no
/// reward is tied to weight, calories, fasting, restriction, exercise volume
/// above the plan or ranking people; unlocks are cosmetic only; and the
/// words are kind and make no health claims.
void main() {
  final source = File('../../content/rewards/catalog.json').readAsStringSync();
  final catalog = RewardCatalog.parse(source);

  test('the app copy matches content/rewards/catalog.json', () {
    expect(File('assets/rewards/catalog.json').readAsStringSync(), source);
  });

  test('pending clinical review (prod shows no rewards until approved)', () {
    expect(catalog.reviewStatus, 'pending');
  });

  group('banned reward types are absent (FR-GAM-01)', () {
    test('the policy finds no problem in the catalogue', () {
      expect(RewardPolicy.violations(catalog), isEmpty);
    });

    test('only consistency, learning, recovery and function', () {
      expect(catalog.allowedBases.toSet(), {
        'consistency',
        'learning',
        'recovery',
        'function',
      });
      final raw = jsonDecode(source) as Map<String, dynamic>;
      for (final key in ['badges', 'challenges']) {
        for (final item in (raw[key] as List).cast<Map<String, dynamic>>()) {
          expect(
            catalog.allowedBases,
            contains(item['basis']),
            reason: '${item['id']}',
          );
        }
      }
    });

    test('badges count days or finished items, never an amount', () {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      for (final b in (raw['badges'] as List).cast<Map<String, dynamic>>()) {
        final rule = b['rule'] as Map<String, dynamic>;
        expect(rule.keys.toSet(), {'type', 'count'}, reason: '${b['id']}');
        expect(
          BadgeRuleType.byId(rule['type'] as String),
          isNotNull,
          reason: '${b['id']}',
        );
      }
      // The rule types themselves: nothing about weight, food or volume.
      for (final t in BadgeRuleType.values) {
        expect(RewardPolicy.bannedIn(t.id, t.id.replaceAll('_', ' ')), isEmpty);
      }
    });

    test('challenges are counted in days (1..7), never in amounts', () {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      for (final c
          in (raw['challenges'] as List).cast<Map<String, dynamic>>()) {
        expect(c.keys.toSet(), {
          'id',
          'basis',
          'movement',
          'food',
          'target_days',
          'title',
          'how',
        }, reason: '${c['id']}: no minutes, steps, calories or weight');
      }
      for (final c in catalog.challenges) {
        expect(c.targetDays, inInclusiveRange(1, 7));
      }
    });

    test('no banned words anywhere in the reward copy', () {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      final problems = <String>[];
      void scan(String where, Object? v) {
        if (v is String) problems.addAll(RewardPolicy.bannedIn(where, v));
        if (v is Map) v.forEach((k, x) => scan('$where.$k', x));
        if (v is List) {
          for (final (i, x) in v.indexed) {
            scan('$where[$i]', x);
          }
        }
      }

      // Everything a person can see; the note explains the ban itself.
      for (final key in ['badges', 'challenges', 'unlockables']) {
        scan(key, raw[key]);
      }
      // And the screen's own words (app_en.arb, rewards*).
      final arb = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final e in arb.entries) {
        if (e.key.startsWith('rewards') && e.value is String) {
          problems.addAll(RewardPolicy.bannedIn(e.key, e.value as String));
        }
      }
      expect(problems, isEmpty);
    });

    test('the check catches banned rewards (it is not a no-op)', () {
      Map<String, dynamic> base() => jsonDecode(source) as Map<String, dynamic>;

      // A banned basis or rule type can't even be read.
      final weightBasis = base();
      (weightBasis['badges'] as List).add({
        'id': 'slimmer',
        'basis': 'weight_loss',
        'rule': {'type': 'days_done', 'count': 1},
        'title': 'x',
        'line': 'x',
      });
      expect(
        () => RewardCatalog.parse(jsonEncode(weightBasis)),
        throwsFormatException,
      );
      final calorieRule = base();
      (calorieRule['badges'] as List).add({
        'id': 'deficit',
        'basis': 'consistency',
        'rule': {'type': 'calories_under', 'count': 1500},
        'title': 'x',
        'line': 'x',
      });
      expect(
        () => RewardCatalog.parse(jsonEncode(calorieRule)),
        throwsFormatException,
      );

      // Banned words, a non-cosmetic unlock and an over-the-plan target.
      final words = base();
      (words['badges'] as List).add({
        'id': 'lost_5',
        'basis': 'consistency',
        'rule': {'type': 'days_done', 'count': 1},
        'title': 'Lose 5 kg',
        'line': 'Top of the leaderboard!',
      });
      (words['challenges'] as List).add({
        'id': 'fast',
        'basis': 'function',
        'movement': false,
        'food': true,
        'target_days': 14,
        'title': 'Intermittent fasting',
        'how': 'Skip a meal and burn calories.',
      });
      (words['unlockables'] as List).add({
        'id': 'extra_plan_days',
        'kind': 'background',
        'cosmetic': false,
        'background': 6,
        'unlocked_by': 'first_step',
        'title': 'Bonus',
      });
      final problems = RewardPolicy.violations(
        RewardCatalog.parse(jsonEncode(words)),
      );
      for (final expected in [
        'banned "lose"',
        'banned "kg"',
        'banned "leaderboard"',
        'banned "fasting"',
        'banned "skip a meal"',
        'banned "burn"',
        'banned "calories"',
        'target_days must be 1..7',
        'unlocks must be cosmetic',
      ]) {
        expect(
          problems.any((p) => p.contains(expected)),
          isTrue,
          reason: expected,
        );
      }
      // Whole words only: "breakfast" is fine, "fast" is not.
      expect(RewardPolicy.bannedIn('x', 'With breakfast'), isEmpty);
      expect(RewardPolicy.bannedIn('x', 'Fast today'), isNotEmpty);
    });
  });

  group('FR-GAM-01: what is rewarded', () {
    test('streaks, Restart badges, lesson badges and challenge badges', () {
      final rules = {for (final b in catalog.badges) b.rule};
      expect(
        rules,
        containsAll([
          BadgeRuleType.streakDays,
          BadgeRuleType.restarts,
          BadgeRuleType.lessonsCompleted,
          BadgeRuleType.challengesCompleted,
        ]),
      );
      expect(catalog.badge('restart')?.basis, RewardBasis.recovery);
    });

    test('the five weekly challenges of the spec', () {
      expect(
        catalog.challenges.map((c) => c.id),
        containsAll([
          'post_meal_walk',
          'plant_variety',
          'steady_bedtime',
          'strength_balance',
          'travel_ready',
        ]),
      );
      // Movement and food are marked, so they can be held back (FR-GOL-03,
      // eating-disorder safe mode).
      expect(catalog.challenge('post_meal_walk')!.movement, isTrue);
      expect(catalog.challenge('strength_balance')!.movement, isTrue);
      expect(catalog.challenge('plant_variety')!.food, isTrue);
    });
  });

  group('FR-GAM-03: avatar unlockables', () {
    test('at least 12 at launch, all cosmetic, each from a badge', () {
      expect(catalog.unlockables.length, greaterThanOrEqualTo(12));
      final badges = {for (final b in catalog.badges) b.id};
      for (final u in catalog.unlockables) {
        expect(u.cosmetic, isTrue, reason: u.id);
        expect(badges, contains(u.unlockedBy), reason: u.id);
      }
      expect(
        {for (final u in catalog.unlockables) u.kind},
        {UnlockKind.background, UnlockKind.celebration},
      );
    });

    test('backgrounds 6..12 are distinct and unlockable only', () {
      final indexes = [
        for (final u in catalog.unlockables)
          if (u.kind == UnlockKind.background) u.background!,
      ];
      expect(indexes.toSet().length, indexes.length);
      expect(indexes.every((i) => i >= 6 && i <= 12), isTrue);
    });
  });

  test('rewards never send notifications or analytics (D-71 cap)', () {
    // No new push types: rewards show only in the app. No analytics either,
    // so nothing about the person's habits leaves the phone this way.
    final files = Directory('lib/features/rewards')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final imports = f
          .readAsLinesSync()
          .where((l) => l.startsWith('import '))
          .join('\n')
          .toLowerCase();
      for (final banned in [
        'notification',
        'reminders',
        'analytics',
        'firebase_messaging',
      ]) {
        expect(imports.contains(banned), isFalse, reason: '${f.path}: $banned');
      }
    }
  });
}
