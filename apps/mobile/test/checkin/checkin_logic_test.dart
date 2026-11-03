import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';

void main() {
  group('localDateKey (the day follows the device clock)', () {
    test('midnight starts a new day', () {
      expect(localDateKey(DateTime(2026, 10, 14, 23, 59, 59)), '2026-10-14');
      expect(localDateKey(DateTime(2026, 10, 15)), '2026-10-15');
    });

    test('the same moment is a different local day in India and the US', () {
      // 2026-10-15 01:00 UTC = 06:30 in India (UTC+5:30), still 21:00 on
      // the 14th in New York (UTC-4). Each user gets their own "today".
      final utc = DateTime.utc(2026, 10, 15, 1);
      final india = utc.add(const Duration(hours: 5, minutes: 30));
      final newYork = utc.subtract(const Duration(hours: 4));
      String keyOf(DateTime wallClock) => localDateKey(
        DateTime(
          wallClock.year,
          wallClock.month,
          wallClock.day,
          wallClock.hour,
        ),
      );
      expect(keyOf(india), '2026-10-15');
      expect(keyOf(newYork), '2026-10-14');
    });

    test('pads months and days', () {
      expect(localDateKey(DateTime(2027, 1, 5, 9)), '2027-01-05');
    });
  });

  group('shouldAskToday (once per day)', () {
    test('asks on the first open of the day', () {
      expect(
        shouldAskToday(
          today: '2026-10-14',
          hasCheckinToday: false,
          lastAskedDay: null,
        ),
        isTrue,
      );
      expect(
        shouldAskToday(
          today: '2026-10-14',
          hasCheckinToday: false,
          lastAskedDay: '2026-10-13',
        ),
        isTrue,
      );
    });
    test('not again after it was shown today, even if closed', () {
      expect(
        shouldAskToday(
          today: '2026-10-14',
          hasCheckinToday: false,
          lastAskedDay: '2026-10-14',
        ),
        isFalse,
      );
    });
    test('not when today is already checked in', () {
      expect(
        shouldAskToday(
          today: '2026-10-14',
          hasCheckinToday: true,
          lastAskedDay: null,
        ),
        isFalse,
      );
    });
  });

  group('gentle day: mood <= 2 or stress >= 4', () {
    test('every mood and stress combination', () {
      for (var mood = 1; mood <= 5; mood++) {
        expect(isGentleDay(mood: mood), mood <= 2, reason: 'mood $mood');
        for (var stress = 1; stress <= 5; stress++) {
          expect(
            isGentleDay(mood: mood, stress: stress),
            mood <= 2 || stress >= 4,
            reason: 'mood $mood stress $stress',
          );
        }
      }
    });
  });

  test('Home response: gentle beats mood; 4-5 high; 3 steady', () {
    CheckIn c(int mood, {bool gentle = false}) =>
        CheckIn(date: 'd', mood: mood, gentleDay: gentle);
    expect(toneFor(c(5)), CheckInTone.high);
    expect(toneFor(c(4)), CheckInTone.high);
    expect(toneFor(c(3)), CheckInTone.steady);
    expect(toneFor(c(5, gentle: true)), CheckInTone.gentle);
    expect(toneFor(c(1, gentle: true)), CheckInTone.gentle);
  });

  test('steps answered counts answers, never their values', () {
    expect(
      const CheckIn(date: 'd', mood: 3, gentleDay: false).stepsAnswered,
      1,
    );
    expect(
      const CheckIn(
        date: 'd',
        mood: 3,
        energy: 2,
        sleep: 4,
        stress: 1,
        timeAvailable: 10,
        barrierText: 'Long day',
        gentleDay: false,
      ).stepsAnswered,
      6,
    );
    expect(
      const CheckIn(
        date: 'd',
        mood: 3,
        barrierText: '  ',
        gentleDay: false,
      ).stepsAnswered,
      1,
    );
  });

  test('the analytics API cannot carry mood or text (NFR-10)', () {
    // The only event method takes two ints; checked here so a future change
    // that adds a value or text parameter is caught in review.
    final src = File('lib/core/analytics/analytics.dart').readAsStringSync();
    final params = RegExp(r'checkinCompleted\(\{([^}]*)\}')
        .firstMatch(src)!
        .group(1)!;
    expect(params, contains('int durationSeconds'));
    expect(params, contains('int stepsAnswered'));
    expect(
      RegExp(r'\b(String|mood|energy|sleep|stress|barrier)\b').hasMatch(params),
      isFalse,
    );
  });
}
