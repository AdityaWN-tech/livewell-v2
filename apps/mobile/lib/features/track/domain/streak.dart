import '../../checkin/domain/checkin.dart' show localDateKey;
import 'track_models.dart';

/// The streak from the days with at least one habit done (Gap 2, D-60),
/// until the server's streak engine (users/{uid}/streaks) exists.
///
/// Kind by design (spec 4.1, FR-DLY-07): the first missed day in a Monday
/// to Sunday week is a rest day (the weekly grace) and doesn't break the
/// streak; a second one does. Today not done yet never breaks it. Null
/// when nothing was ever done (the card shows its start state).
StreakSummary? streakFrom(Set<String> doneDates, DateTime now) {
  if (doneDates.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int back) => DateTime(today.year, today.month, today.day - back);
  bool done(DateTime d) => doneDates.contains(localDateKey(d));
  String weekOf(DateTime d) =>
      localDateKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));

  // Walk forward through the history so "best" sees every run.
  final first = doneDates.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  final start = DateTime.parse(first);
  var run = 0;
  var best = 0;
  final graceUsed = <String>{};
  for (
    var d = start;
    !d.isAfter(today);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (done(d)) {
      run++;
    } else if (d == today) {
      // Not done yet today: the streak still stands.
    } else if (graceUsed.add(weekOf(d))) {
      // The week's rest day.
    } else {
      run = 0;
    }
    if (run > best) best = run;
  }

  final monday = day(today.weekday - 1);
  final restInWeek = <String>{};
  final week = [
    for (var i = 0; i < 7; i++)
      () {
        final d = DateTime(monday.year, monday.month, monday.day + i);
        if (d.isAfter(today)) return StreakDay.upcoming;
        if (done(d)) return StreakDay.done;
        if (d == today) return StreakDay.today;
        return restInWeek.add(weekOf(d)) ? StreakDay.rest : StreakDay.restart;
      }(),
  ];
  return StreakSummary(length: run, best: best, week: week);
}

/// Habits done per day, Monday to Sunday of [now]'s week, from the done
/// logs' dates; null when none this week (Track shows its empty state).
List<int>? habitsPerDay(Iterable<String> doneDates, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final counts = List.filled(7, 0);
  for (final date in doneDates) {
    final d = DateTime.parse(date);
    final i = DateTime(d.year, d.month, d.day).difference(monday).inDays;
    if (i >= 0 && i < 7) counts[i]++;
  }
  return counts.every((c) => c == 0) ? null : counts;
}
