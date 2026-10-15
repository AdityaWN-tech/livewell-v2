/// Today's one next step (FR-DLY-03): one primary action sized to the time
/// the user has, plus "make it smaller".
class TodayStep {
  const TodayStep({
    required this.driver,
    required this.title,
    required this.reason,
    required this.minutes,
    this.smallerTitle,
    this.smallerMinutes,
  });

  /// Driver label, for example "Driver 3".
  final String driver;
  final String title;
  final String reason;
  final int minutes;

  /// Null when the step is already the smallest size.
  final String? smallerTitle;
  final int? smallerMinutes;
}

/// Progress for the companion milestone card.
class Milestone {
  const Milestone({
    required this.phase,
    required this.phaseCount,
    required this.habitsKept,
    required this.habitsPlanned,
  });

  final int phase;
  final int phaseCount;
  final int habitsKept;
  final int habitsPlanned;

  double get progress =>
      habitsPlanned == 0 ? 0 : (habitsKept / habitsPlanned).clamp(0.0, 1.0);
}

/// Day N of the journey: 1 on the day the account was created, counted in
/// local calendar days (so it changes at midnight, not 24 h later).
int dayNumber(DateTime createdAt, DateTime now) {
  final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final today = DateTime(now.year, now.month, now.day);
  // Rounded, so a daylight-saving change can't make a day 23 or 25 h long.
  return (today.difference(start).inHours / 24).round() + 1;
}
