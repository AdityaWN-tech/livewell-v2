import '../../checkin/domain/checkin.dart' show localDateKey;
import 'reward_catalog.dart';

/// What the badges count, from data the app already has: the streak engine
/// (habit_logs, D-60), the Learn reader (content_progress, D-57) and the
/// weekly challenges. Counts only, no health values.
class RewardProgress {
  const RewardProgress({
    this.daysDone = 0,
    this.bestStreak = 0,
    this.restarts = 0,
    this.lessonsCompleted = 0,
    this.challengesCompleted = 0,
  });

  final int daysDone;
  final int bestStreak;
  final int restarts;
  final int lessonsCompleted;
  final int challengesCompleted;

  int of(BadgeRuleType rule) => switch (rule) {
    BadgeRuleType.daysDone => daysDone,
    BadgeRuleType.streakDays => bestStreak,
    BadgeRuleType.restarts => restarts,
    BadgeRuleType.lessonsCompleted => lessonsCompleted,
    BadgeRuleType.challengesCompleted => challengesCompleted,
  };
}

/// The person's challenge for one week: users/{uid}/challenges/{monday}.
class ChallengeEntry {
  const ChallengeEntry({
    required this.week,
    required this.challengeId,
    this.days = const {},
  });

  /// The Monday of the week, YYYY-MM-DD (also the document id).
  final String week;
  final String challengeId;

  /// Days it was done (at most one per day, at most 7).
  final Set<String> days;

  bool doneOn(String date) => days.contains(date);

  bool completeFor(WeeklyChallenge c) => days.length >= c.targetDays;

  ChallengeEntry withDay(String date) => ChallengeEntry(
    week: week,
    challengeId: challengeId,
    days: {...days, date},
  );
}

/// The fixed rules (no AI): which badges are earned, what they unlock, which
/// challenge is offered this week, and when rewards must stay quiet.
abstract final class RewardRules {
  /// The badges [progress] has earned.
  static Set<String> earned(RewardCatalog catalog, RewardProgress progress) => {
    for (final b in catalog.badges)
      if (progress.of(b.rule) >= b.count) b.id,
  };

  /// Unlocks come only from earned badges and are cosmetic only.
  static List<Unlockable> unlocked(RewardCatalog catalog, Set<String> earned) =>
      [
        for (final u in catalog.unlockables)
          if (u.cosmetic && earned.contains(u.unlockedBy)) u,
      ];

  /// The challenges this person may be offered: no movement unless the
  /// FR-GOL-03 activity check said "no limits" (unknown counts as limited,
  /// the conservative choice), and nothing about food in eating-disorder
  /// safe mode (FR-SAF-04).
  static List<WeeklyChallenge> offered(
    RewardCatalog catalog, {
    required bool? activityLimited,
    required bool edSafeMode,
  }) => [
    for (final c in catalog.challenges)
      if (!(c.movement && activityLimited != false) && !(c.food && edSafeMode))
        c,
  ];

  /// One challenge a week (one primary action), turning in a fixed order.
  static WeeklyChallenge? forWeek(List<WeeklyChallenge> offered, String week) {
    if (offered.isEmpty) return null;
    final monday = DateTime.parse(week);
    final n =
        DateTime.utc(
          monday.year,
          monday.month,
          monday.day,
        ).difference(DateTime.utc(2024, 1, 1)).inDays ~/
        7;
    return offered[n % offered.length];
  }

  /// The Monday of [now]'s week.
  static String weekOf(DateTime now) =>
      localDateKey(DateTime(now.year, now.month, now.day - (now.weekday - 1)));

  /// Rewards stay quiet (no challenge invitation, no "days to go", no new
  /// badge fanfare) on a gentle day, in eating-disorder safe mode, and
  /// unless we know there was no safety event in the last 72 hours (unknown
  /// counts as not clear, as for portal cards; D-22, D-87). Badges already
  /// earned are still shown.
  static bool quiet({
    required bool gentleDay,
    required bool edSafeMode,
    required bool safetyClear,
  }) => gentleDay || edSafeMode || !safetyClear;
}
