import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/track/domain/streak.dart';
import 'package:livewell/features/track/domain/track_models.dart';

/// Wednesday 14 October 2026.
final now = DateTime(2026, 10, 14, 9);

Set<String> days(List<int> octoberDays) => {
  for (final d in octoberDays) '2026-10-${d.toString().padLeft(2, '0')}',
};

void main() {
  group('streak from habits done (D-60)', () {
    test('nothing ever done: no streak yet', () {
      expect(streakFrom({}, now), isNull);
    });

    test('done every day up to yesterday: today not done yet keeps it', () {
      final s = streakFrom(days([10, 11, 12, 13]), now)!;
      expect(s.length, 4);
      expect(s.best, 4);
      expect(s.week, [
        StreakDay.done,
        StreakDay.done,
        StreakDay.today,
        StreakDay.upcoming,
        StreakDay.upcoming,
        StreakDay.upcoming,
        StreakDay.upcoming,
      ]);
    });

    test('the first missed day of a week is a rest day, the second breaks '
        'the streak (and offers a restart)', () {
      // Mon 5 .. Sun 11 last week: one rest (Wed 7), a second miss Fri 9.
      final s = streakFrom(days([5, 6, 8, 10, 11, 12, 13, 14]), now)!;
      expect(s.length, 5, reason: '10, 11, 12, 13, 14');
      expect(s.best, 5);
      // This week: Mon 12, Tue 13, Wed 14 done.
      expect(s.week.take(3), everyElement(StreakDay.done));
    });

    test('a rest day this week shows as rest, not as a miss', () {
      final s = streakFrom(days([11, 13, 14]), now)!;
      expect(s.week[0], StreakDay.rest, reason: 'Mon 12 missed');
      expect(s.length, 3);
    });

    test('best remembers an earlier, longer run', () {
      final s = streakFrom(days([1, 2, 3, 4, 5, 6, 7, 8, 14]), now)!;
      expect(s.best, greaterThan(s.length));
    });
  });

  group('habits per day this week', () {
    test('counts each log on its day, Monday first', () {
      expect(habitsPerDay(['2026-10-12', '2026-10-12', '2026-10-14'], now), [
        2,
        0,
        1,
        0,
        0,
        0,
        0,
      ]);
    });

    test('none this week: null (the empty state)', () {
      expect(habitsPerDay(['2026-10-05'], now), isNull);
    });
  });
}
