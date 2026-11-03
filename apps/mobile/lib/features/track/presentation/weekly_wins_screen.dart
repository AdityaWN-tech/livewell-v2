import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../checkin/domain/checkin.dart';
import '../../dev/application/preview_mode.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal.dart';
import '../../plan/application/plan_data.dart';
import '../../plan/domain/plan_models.dart';
import '../../routine/application/routine_week_data.dart';
import '../application/track_data.dart';
import '../domain/track_stats.dart';
import '../domain/weekly_wins.dart';
import 'track_screen.dart' show scaleWord;

/// The last 7 days' habit ticks; refreshed when today's change.
final _weekHabitLogsProvider = FutureProvider<List<HabitLog>>((ref) async {
  final now = ref.watch(clockProvider)();
  ref.watch(todayHabitLogsProvider);
  final from = localDateKey(DateTime(now.year, now.month, now.day - 6));
  try {
    return await ref
        .watch(goalRepositoryProvider)
        .logsBetween(from, localDateKey(now));
  } catch (_) {
    return const [];
  }
});

/// The last 7 days (today and the 6 before), from the phone's data.
final weeklyWinsProvider = Provider<WeeklyWins>((ref) {
  if (ref.watch(previewModeProvider)) {
    return const WeeklyWins(
      checkInDays: 5,
      habitTicks: 9,
      routineDone: 14,
      usualMood: 4,
      steadyStep: 'a morning walk',
      steadyDays: 5,
      hasHabits: true,
    );
  }
  final now = ref.watch(clockProvider)();
  final from = localDateKey(DateTime(now.year, now.month, now.day - 6));
  final week = [
    for (final c in ref.watch(trackHistoryProvider).value ?? const <CheckIn>[])
      if (c.date.compareTo(from) >= 0) c,
  ];
  final win = ref.watch(routineWinProvider);
  return WeeklyWins(
    checkInDays: {for (final c in week) c.date}.length,
    habitTicks: (ref.watch(_weekHabitLogsProvider).value ?? const []).length,
    routineDone: ref.watch(routineWeeklyDoneProvider),
    usualMood: WeeklyWins.usualOf(week.map((c) => c.mood)),
    steadyStep: win?.spokenName,
    steadyDays: win?.days ?? 0,
    hasHabits: ref
        .watch(planHabitsProvider)
        .any((h) => h.role == HabitRole.supporting),
  );
});

/// Weekly wins (Step 4b, D-54), from Track's Weekly Reflection card and
/// MY GOAL DO IT's Optimism: what went well in the last 7 days, said kindly
/// (no zeros, nothing to feel bad about), and one small change for next
/// week from fixed rules.
class WeeklyWinsScreen extends ConsumerWidget {
  const WeeklyWinsScreen({super.key});

  static const path = '/track/weekly';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final w = ref.watch(weeklyWinsProvider);
    final mood = w.usualMood;
    final wins = <(Key, IconData, String)>[
      if (w.checkInDays > 0)
        (
          const Key('wins-checkins'),
          Icons.wb_sunny_outlined,
          l.winsCheckIns(w.checkInDays),
        ),
      // Only a good-enough week's mood is a win; a low one isn't listed.
      if (mood != null && mood >= 3)
        (
          const Key('wins-mood'),
          Icons.sentiment_satisfied_outlined,
          l.winsMood(scaleWord(l, TrackMetric.mood, mood)),
        ),
      if (w.habitTicks > 0)
        (
          const Key('wins-habits'),
          Icons.check_circle_outline,
          l.winsHabits(w.habitTicks),
        ),
      if (w.routineDone > 0)
        (
          const Key('wins-routine'),
          Icons.event_available_outlined,
          l.winsRoutine(w.routineDone),
        ),
      if (w.steadyStep case final step? when w.steadyDays > 1)
        (
          const Key('wins-steady'),
          Icons.star_outline,
          l.winsSteady(step, w.steadyDays),
        ),
    ];
    final (changeTitle, changeBody) = switch (w.change) {
      NextWeekChange.firstCheckIn => (l.winsFirstTitle, l.winsFirstBody),
      NextWeekChange.moreCheckIns => (l.winsMoreTitle, l.winsMoreBody),
      NextWeekChange.smallerHabit => (l.winsSmallerTitle, l.winsSmallerBody),
      NextWeekChange.keepGoing => (l.winsKeepTitle, l.winsKeepBody),
    };
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          LwPageTitle(l.winsTitle),
          Text(l.winsSubtitle, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.md),
          if (wins.isEmpty)
            LwCard(
              key: const Key('wins-empty'),
              title: l.winsEmptyTitle,
              body: l.winsEmptyBody,
            )
          else
            Card(
              key: const Key('wins-list'),
              child: Column(
                children: [
                  for (final (key, icon, text) in wins)
                    ListTile(
                      key: key,
                      leading: Icon(icon, color: p.primaryDark),
                      title: Text(text, style: t.bodyLarge),
                    ),
                ],
              ),
            ),
          LwSectionHeader(l.winsNextTitle),
          LwCard(
            key: Key('wins-change-${w.change.name}'),
            title: changeTitle,
            body: changeBody,
          ),
          const SizedBox(height: LwSpacing.md),
          FilledButton(
            key: const Key('wins-open-plan'),
            onPressed: () => context.go('/plan'),
            child: Text(l.winsOpenPlan),
          ),
        ],
      ),
    );
  }
}
