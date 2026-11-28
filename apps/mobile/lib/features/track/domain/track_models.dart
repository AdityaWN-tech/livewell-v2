/// One evening reflection per local date (FR-DLY-05):
/// "What went well today?"
/// "What got in the way?" in the evening reflection (T-DLY-05, D-119):
/// fixed choices, never free text, so no AI is needed to act on it. Any of
/// them makes the next day's step the smaller one (FR-DLY-05).
enum ReflectionBarrier {
  noTime('no_time'),
  tired('tired'),
  feltUnwell('felt_unwell'),
  plansChanged('plans_changed'),
  forgot('forgot');

  const ReflectionBarrier(this.id);

  /// Stored id (the Firestore rules allow these only).
  final String id;

  static ReflectionBarrier? fromId(Object? id) =>
      values.where((b) => b.id == id).firstOrNull;
}

class Reflection {
  const Reflection({required this.date, this.text = '', this.barrier});

  /// Local date, YYYY-MM-DD.
  final String date;

  /// What went well; may be empty when only a barrier was chosen.
  final String text;

  /// What got in the way, or null.
  final ReflectionBarrier? barrier;

  /// Same limit as the Firestore rules.
  static const maxLength = 500;
}

/// How one day of the week looks in the streak row. Missed days are never
/// shown as an alarm (spec 4.1, FR-DLY-07): the first one in a week is a
/// "rest" day (the weekly grace), later ones offer a "restart".
enum StreakDay { done, rest, restart, today, upcoming }

/// The streak card's data.
class StreakSummary {
  const StreakSummary({
    required this.length,
    required this.best,
    required this.week,
    this.restarts = 0,
  });

  final int length;
  final int best;

  /// Times the person came back after a missed day (the Restart badge).
  final int restarts;

  /// Monday to Sunday.
  final List<StreakDay> week;

  bool get isPersonalBest => length > 0 && length >= best;
}
