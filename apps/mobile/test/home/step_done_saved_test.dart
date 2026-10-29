import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/time/clock.dart';
import 'package:livewell/features/goals/data/goal_repository.dart';
import 'package:livewell/features/goals/domain/goal.dart';
import 'package:livewell/features/home/application/home_data.dart';
import 'package:livewell/features/track/application/track_data.dart';
import 'package:livewell/features/track/presentation/track_screen.dart'
    show streakProvider;

/// Wednesday 14 October 2026.
final now = DateTime(2026, 10, 14, 9);

ProviderContainer app(InMemoryGoalRepository goals) {
  final c = ProviderContainer(
    overrides: [
      goalRepositoryProvider.overrideWithValue(goals),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('Done is saved as today\'s daily_step log and survives a restart '
      '(D-60)', () async {
    final goals = InMemoryGoalRepository();
    final first = app(goals);
    first.listen(stepProgressProvider, (_, _) {});
    first.read(stepProgressActionsProvider).markDone();
    await settle();
    expect(goals.logs.keys, ['2026-10-14_$dailyStepHabitId']);

    // Tapping again (or an offline retry) writes the same document.
    first.read(stepProgressActionsProvider).markDone();
    await settle();
    expect(goals.logs, hasLength(1));

    // A fresh start of the app: Done comes back from the saved log.
    final second = app(goals);
    second.listen(stepProgressProvider, (_, _) {});
    expect(second.read(stepProgressProvider).done, isFalse);
    await settle();
    await settle();
    expect(second.read(stepProgressProvider).done, isTrue);
  });

  test('habits done fill the Track chart and the streak', () async {
    final goals = InMemoryGoalRepository();
    await goals.saveLog(
      const HabitLog(date: '2026-10-13', habitId: dailyStepHabitId),
    );
    await goals.saveLog(
      const HabitLog(date: '2026-10-14', habitId: 'support_1'),
    );
    final c = app(goals);
    c.listen(habitsWeekProvider, (_, _) {});
    c.listen(streakProvider, (_, _) {});
    await c.read(recentDoneDatesProvider.future);
    expect(c.read(habitsWeekProvider), [0, 1, 1, 0, 0, 0, 0]);
    expect(c.read(streakProvider)!.length, 2);
  });
}
