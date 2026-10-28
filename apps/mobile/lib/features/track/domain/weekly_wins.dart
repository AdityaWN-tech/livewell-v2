/// Weekly wins (Step 4b, D-54; FR-DLY-06 without the coach's voice yet):
/// the last 7 days from what is already on the phone, and one small change
/// for next week picked by fixed rules from approved words, never by an AI.
library;

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
  });

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
