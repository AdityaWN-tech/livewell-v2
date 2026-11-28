/// Weekly wins (Step 4b, D-54; FR-DLY-06 without the coach's voice yet):
/// the last 7 days from what is already on the phone, and one small change
/// for next week picked by fixed rules from approved words, never by an AI.
library;

import '../../checkin/domain/checkin.dart';

/// A check-in answer that went the kind way since the week before
/// (FR-DLY-06 "check-in trends", T-DLY-07). Only improvements are named;
/// a harder week is never pointed out (nothing to feel bad about).
enum CheckInTrend { moodUp, energyUp, sleepUp, stressDown }

/// What the next week could try. Each maps to one approved sentence.
enum NextWeekChange {
  /// Nothing logged yet: start with one check-in a day.
  firstCheckIn,

  /// Fewer than 3 check-ins: tie the check-in to something daily.
  moreCheckIns,

  /// Habits exist but none ticked: make the easiest one smaller.
  smallerHabit,

  /// It's working: keep the same plan.
  keepGoing,
}

class WeeklyWins {
  const WeeklyWins({
    required this.checkInDays,
    required this.habitTicks,
    required this.routineDone,
    this.usualMood,
    this.steadyStep,
    this.steadyDays = 0,
    required this.hasHabits,
    this.streakDays = 0,
    this.trends = const [],
  });

  /// The current streak, in days (rest days don't break it, FR-DLY-07).
  final int streakDays;

  /// What went the kind way since the week before, in a fixed order.
  final List<CheckInTrend> trends;

  /// Answers needed in each week before comparing them.
  static const minAnswers = 3;

  /// How far the average must move (on the 1 to 5 scale) to count.
  static const minChange = 0.5;

  /// This week against the week before, by fixed rules: per answer, at
  /// least [minAnswers] in both weeks and an average at least [minChange]
  /// better (higher mood, energy and sleep; lower stress).
  static List<CheckInTrend> trendsOf(
    Iterable<CheckIn> thisWeek,
    Iterable<CheckIn> lastWeek,
  ) {
    double? avg(Iterable<CheckIn> w, int? Function(CheckIn) f) {
      final v = [for (final c in w) ?f(c)];
      return v.length < minAnswers
          ? null
          : v.reduce((a, b) => a + b) / v.length;
    }

    bool better(int? Function(CheckIn) f, {bool lowerIsBetter = false}) {
      final now = avg(thisWeek, f);
      final before = avg(lastWeek, f);
      if (now == null || before == null) return false;
      final change = lowerIsBetter ? before - now : now - before;
      return change >= minChange - 1e-9;
    }

    return [
      if (better((c) => c.mood)) CheckInTrend.moodUp,
      if (better((c) => c.energy)) CheckInTrend.energyUp,
      if (better((c) => c.sleep)) CheckInTrend.sleepUp,
      if (better((c) => c.stress, lowerIsBetter: true)) CheckInTrend.stressDown,
    ];
  }

  /// Days with a check-in, 0..7.
  final int checkInDays;

  /// Habit Done ticks (own and plan supporting habits).
  final int habitTicks;

  /// Routine steps marked done.
  final int routineDone;

  /// The mood answered most often (1..5), or null without check-ins.
  final int? usualMood;

  /// The routine step done on most days, and on how many.
  final String? steadyStep;
  final int steadyDays;

  /// Whether the person has any supporting habit to tick.
  final bool hasHabits;

  bool get isEmpty => checkInDays == 0 && habitTicks == 0 && routineDone == 0;

  /// One small change, by fixed rules, in this order.
  NextWeekChange get change {
    if (isEmpty) return NextWeekChange.firstCheckIn;
    if (checkInDays < 3) return NextWeekChange.moreCheckIns;
    if (hasHabits && habitTicks == 0) return NextWeekChange.smallerHabit;
    return NextWeekChange.keepGoing;
  }

  /// The mood answered most often; on a tie, the kinder (higher) one.
  static int? usualOf(Iterable<int> moods) {
    final counts = <int, int>{};
    for (final m in moods) {
      counts[m] = (counts[m] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final best = counts.values.reduce((a, b) => a > b ? a : b);
    return counts.entries
        .where((e) => e.value == best)
        .map((e) => e.key)
        .reduce((a, b) => a > b ? a : b);
  }
}
