import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/track/domain/health_summary.dart';

DateTime t(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

void main() {
  group('average sleep a night (Step 4f)', () {
    test('no sessions: null, so Track shows the check-in', () {
      expect(averageSleepMinutes([]), isNull);
    });

    test('a session belongs to the night it ends on; nights average', () {
      expect(
        averageSleepMinutes([
          (t(12, 23), t(13, 6)), // 7 h
          (t(13, 22), t(14, 7)), // 9 h
        ]),
        8 * 60,
      );
    });

    test('a nap and a night on the same day add up', () {
      expect(
        averageSleepMinutes([
          (t(13, 0), t(13, 6)), // 6 h
          (t(13, 14), t(13, 14, 30)), // 30 min
        ]),
        6 * 60 + 30,
      );
    });

    test('overlapping sessions from two apps count once', () {
      expect(
        averageSleepMinutes([(t(12, 23), t(13, 6)), (t(13, 0), t(13, 7))]),
        8 * 60,
      );
    });

    test('empty or backwards sessions are ignored', () {
      expect(averageSleepMinutes([(t(13, 6), t(13, 6))]), isNull);
      expect(averageSleepMinutes([(t(13, 7), t(13, 6))]), isNull);
    });
  });

  test('the steps bar defaults to 8,000', () {
    expect(
      const HealthSummary(stepsWeek: [0, 0, 0, 0, 0, 0, 0]).stepsGoal,
      8000,
    );
  });
}
