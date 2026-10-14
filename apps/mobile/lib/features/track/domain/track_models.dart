/// One evening reflection per local date (FR-DLY-05):
/// "What went well today?"
class Reflection {
  const Reflection({required this.date, required this.text});

  /// Local date, YYYY-MM-DD.
  final String date;
  final String text;

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
  });

  final int length;
  final int best;

  /// Monday to Sunday.
  final List<StreakDay> week;

  bool get isPersonalBest => length > 0 && length >= best;
}
