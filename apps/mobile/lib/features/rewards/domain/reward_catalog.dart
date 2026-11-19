/// The reward catalogue (T-GAM-01, FR-GAM-01..03, D-87): a copy of
/// content/rewards/catalog.json. Badges, weekly challenges and avatar
/// unlockables, all earned only through consistency, learning, recovery and
/// function (spec 6.9). [RewardPolicy] is the check that keeps banned reward
/// types out; a test runs it over the bundled file.
library;

import 'dart:convert';

/// What a reward is for (FR-GAM-01). Nothing else can be rewarded.
enum RewardBasis {
  consistency,
  learning,
  recovery,
  function;

  static RewardBasis? byName(String name) =>
      values.where((b) => b.name == name).firstOrNull;
}

/// What a badge counts. Every rule counts days or finished items, never an
/// amount of food, weight, exercise or time (no reward for doing more than
/// the plan).
enum BadgeRuleType {
  /// Days with any habit done (the streak engine's input).
  daysDone('days_done'),

  /// The best kind streak (grace of a rest day a week, FR-DLY-07).
  streakDays('streak_days'),

  /// Coming back after a missed day (Restart badges, FR-DLY-07).
  restarts('restarts'),

  /// Lessons finished in the Learn reader.
  lessonsCompleted('lessons_completed'),

  /// Weekly challenges finished.
  challengesCompleted('challenges_completed');

  const BadgeRuleType(this.id);

  final String id;

  static BadgeRuleType? byId(String id) =>
      values.where((t) => t.id == id).firstOrNull;
}

/// Cosmetic unlockable kinds (FR-GAM-03). Outfits need the Media Service
/// (Adjust) and come later (D-87).
enum UnlockKind {
  background,
  celebration;

  static UnlockKind? byName(String name) =>
      values.where((k) => k.name == name).firstOrNull;
}

/// The Done celebration's falling shapes. [leaves] is everyone's; the rest
/// are unlockables.
enum CelebrationStyle {
  leaves,
  petals,
  stars,
  hearts,
  bubbles,
  confetti;

  static CelebrationStyle? byName(String? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

class RewardBadge {
  const RewardBadge({
    required this.id,
    required this.basis,
    required this.rule,
    required this.count,
    required this.title,
    required this.line,
  });

  final String id;
  final RewardBasis basis;
  final BadgeRuleType rule;
  final int count;
  final String title;
  final String line;
}

class WeeklyChallenge {
  const WeeklyChallenge({
    required this.id,
    required this.basis,
    required this.movement,
    required this.food,
    required this.targetDays,
    required this.title,
    required this.how,
  });

  final String id;
  final RewardBasis basis;

  /// Movement: offered only after the FR-GOL-03 activity check said no
  /// limits.
  final bool movement;

  /// About food: never offered in eating-disorder safe mode (FR-SAF-04).
  final bool food;

  /// Days in the week (1..7) that finish it. Never an amount.
  final int targetDays;
  final String title;
  final String how;
}

class Unlockable {
  const Unlockable({
    required this.id,
    required this.kind,
    required this.cosmetic,
    required this.unlockedBy,
    required this.title,
    this.background,
    this.celebration,
  });

  final String id;
  final UnlockKind kind;

  /// Always true: unlocks change only how things look (FR-GAM-03).
  final bool cosmetic;

  /// The badge that unlocks it.
  final String unlockedBy;
  final String title;

  /// For [UnlockKind.background]: the AvatarColours index.
  final int? background;

  /// For [UnlockKind.celebration].
  final CelebrationStyle? celebration;
}

class RewardCatalog {
  const RewardCatalog({
    required this.reviewStatus,
    required this.allowedBases,
    required this.badges,
    required this.challenges,
    required this.unlockables,
  });

  final String reviewStatus;

  /// As written in the file; the policy checks it equals [RewardBasis].
  final List<String> allowedBases;
  final List<RewardBadge> badges;
  final List<WeeklyChallenge> challenges;
  final List<Unlockable> unlockables;

  RewardBadge? badge(String id) => badges.where((b) => b.id == id).firstOrNull;

  WeeklyChallenge? challenge(String id) =>
      challenges.where((c) => c.id == id).firstOrNull;

  /// Throws [FormatException] on anything unknown, so a banned reward type
  /// can't slip in as a new rule or basis.
  static RewardCatalog parse(String json) {
    final d = jsonDecode(json) as Map<String, dynamic>;
    RewardBasis basis(Object? v) =>
        RewardBasis.byName(v as String) ??
        (throw FormatException('reward basis not allowed: $v'));
    List<Map<String, dynamic>> list(String key) =>
        (d[key] as List).cast<Map<String, dynamic>>();
    return RewardCatalog(
      reviewStatus: d['review_status'] as String,
      allowedBases: (d['allowed_bases'] as List).cast<String>(),
      badges: [
        for (final b in list('badges'))
          RewardBadge(
            id: b['id'] as String,
            basis: basis(b['basis']),
            rule:
                BadgeRuleType.byId(
                  (b['rule'] as Map<String, dynamic>)['type'] as String,
                ) ??
                (throw FormatException('badge rule not allowed: ${b['rule']}')),
            count: (b['rule'] as Map<String, dynamic>)['count'] as int,
            title: b['title'] as String,
            line: b['line'] as String,
          ),
      ],
      challenges: [
        for (final c in list('challenges'))
          WeeklyChallenge(
            id: c['id'] as String,
            basis: basis(c['basis']),
            movement: c['movement'] as bool,
            food: c['food'] as bool,
            targetDays: c['target_days'] as int,
            title: c['title'] as String,
            how: c['how'] as String,
          ),
      ],
      unlockables: [
        for (final u in list('unlockables'))
          Unlockable(
            id: u['id'] as String,
            kind:
                UnlockKind.byName(u['kind'] as String) ??
                (throw FormatException(
                  'unlock kind not allowed: ${u['kind']}',
                )),
            cosmetic: u['cosmetic'] as bool,
            unlockedBy: u['unlocked_by'] as String,
            title: u['title'] as String,
            background: u['background'] as int?,
            celebration: CelebrationStyle.byName(u['celebration'] as String?),
          ),
      ],
    );
  }
}

/// The banned reward types (spec 6.9 FR-GAM-01, 4.1 principle 3, 1.1):
/// nothing tied to weight, calories, fasting, restriction or exercise volume
/// above the plan; no leaderboards or comparing people; and, as for all
/// copy, no cure or reversal promises, no medication talk and nothing
/// fear-based or guilt-based.
abstract final class RewardPolicy {
  /// Whole words or phrases; matched case-insensitively.
  static const bannedTerms = [
    // Weight and body size.
    'weight', 'weigh', 'kg', 'kgs', 'lb', 'lbs', 'pound', 'pounds', 'bmi',
    'slim', 'thin', 'thinner', 'fat', 'lose', 'loss', 'lost', 'waist',
    'inches', 'body shape',
    // Calories, fasting and restriction.
    'calorie', 'calories', 'kcal', 'fast', 'fasting', 'skip a meal',
    'skip meals', 'diet', 'dieting', 'restrict', 'restriction', 'cut out',
    'cut back', 'no sugar', 'no carbs', 'carbs', 'cheat day', 'clean eating',
    'guilt-free', 'burn',
    // Exercise volume above the plan.
    'more steps', '10,000 steps', '10000 steps', 'extra workout', 'harder',
    'push yourself', 'no pain', 'max', 'personal record', 'double',
    // Ranking and comparing people.
    'leaderboard', 'rank', 'ranking', 'beat', 'compete', 'competition',
    'top 10', 'winner', 'better than others',
    // Health claims, medication, fear and guilt.
    'cure', 'cures', 'reverse', 'reversal', 'reverses', 'medication',
    'medicine', 'dose', 'insulin', 'pills', 'disease', 'diabetes',
    "don't lose", 'lose your streak', 'break your streak', 'fail', 'failed',
    'lazy', 'shame', 'warning',
  ];

  /// What a badge may count (never an amount).
  static const allowedRules = BadgeRuleType.values;

  /// Every problem in [catalog]; empty when it is fine.
  static List<String> violations(RewardCatalog catalog) {
    final problems = <String>[];
    final allowed = {for (final b in RewardBasis.values) b.name};
    if (!catalog.allowedBases.toSet().containsAll(allowed) ||
        !allowed.containsAll(catalog.allowedBases)) {
      problems.add('allowed_bases must be exactly $allowed');
    }
    for (final b in catalog.badges) {
      if (b.count < 1) problems.add('${b.id}: count must be at least 1');
      problems.addAll(bannedIn('${b.id}.title', b.title));
      problems.addAll(bannedIn('${b.id}.line', b.line));
    }
    for (final c in catalog.challenges) {
      if (c.targetDays < 1 || c.targetDays > 7) {
        problems.add('${c.id}: target_days must be 1..7');
      }
      problems.addAll(bannedIn('${c.id}.title', c.title));
      problems.addAll(bannedIn('${c.id}.how', c.how));
    }
    final badgeIds = {for (final b in catalog.badges) b.id};
    for (final u in catalog.unlockables) {
      if (!u.cosmetic) problems.add('${u.id}: unlocks must be cosmetic');
      if (!badgeIds.contains(u.unlockedBy)) {
        problems.add('${u.id}: unknown badge ${u.unlockedBy}');
      }
      if (u.kind == UnlockKind.background && u.background == null) {
        problems.add('${u.id}: background index missing');
      }
      if (u.kind == UnlockKind.celebration &&
          (u.celebration == null || u.celebration == CelebrationStyle.leaves)) {
        problems.add('${u.id}: celebration style missing');
      }
      problems.addAll(bannedIn('${u.id}.title', u.title));
    }
    return problems;
  }

  /// The banned words or phrases found in [text], as problems for [where].
  static List<String> bannedIn(String where, String text) => [
    for (final term in bannedTerms)
      if (RegExp(
        '(^|[^a-z0-9])${RegExp.escape(term)}(\$|[^a-z0-9])',
        caseSensitive: false,
      ).hasMatch(text))
        '$where: banned "$term"',
  ];
}
