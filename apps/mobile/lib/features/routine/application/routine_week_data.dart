import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../checkin/domain/checkin.dart';
import '../../track/domain/track_stats.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';
import '../domain/routine_editing.dart';
import '../domain/routine_week.dart';
import 'routine_data.dart';

/// My Daily Routine on Home, the widget, Track and the weekly review
/// (T-GOL-03e).

/// Today's next routine item (after any life-event mode), or null.
final nextRoutineProvider = Provider<RoutineItem?>((ref) {
  final now = ref.watch(clockProvider)();
  final today = localDateKey(now);
  final day = activeItems(
    ref.watch(routineDayProvider(Weekday.of(now))),
    ref.watch(routineModeProvider),
    today,
  );
  if (day.isEmpty) return null;
  final logs = ref.watch(routineLogsProvider(today)).value;
  if (logs == null) return null;
  return nextRoutineItem(day, logs.keys.toSet(), now);
});

/// Logs from [days] days ago to today; refreshed when today's change.
final _recentLogsProvider = FutureProvider.family<List<RoutineLog>, int>((
  ref,
  days,
) async {
  final now = ref.watch(clockProvider)();
  final today = localDateKey(now);
  ref.watch(routineLogsProvider(today));
  final from = localDateKey(DateTime(now.year, now.month, now.day - days));
  try {
    return await ref.watch(routineRepositoryProvider).logsBetween(from, today);
  } catch (_) {
    return const [];
  }
});

/// Track's Routine chip: items done each day, Monday to Sunday of this
/// week; null when there is no routine yet.
final routineWeekProvider = Provider<List<int>?>((ref) {
  final items = ref.watch(routineItemsProvider).value;
  if (items == null || items.isEmpty) return null;
  final now = ref.watch(clockProvider)();
  // This week's Monday is at most 6 days ago.
  final logs = ref.watch(_recentLogsProvider(now.weekday - 1)).value;
  if (logs == null) return null;
  return doneByDay(logs, weekDates(now));
});

/// Routine items done in the last 7 days, for "Weekly healthy actions"
/// (the North Star): they count there, never for the streak.
final routineWeeklyDoneProvider = Provider<int>((ref) {
  final logs = ref.watch(_recentLogsProvider(6)).value ?? const [];
  return doneCount(logs);
});

/// The last 7 days' routine win, for the weekly review, or null.
final routineWinProvider = Provider<({String spokenName, int days})?>((ref) {
  final logs = ref.watch(_recentLogsProvider(6)).value;
  final items = ref.watch(routineItemsProvider).value;
  final catalog = ref.watch(routineCatalogProvider).value;
  if (logs == null || items == null || catalog == null) return null;
  return routineWin(logs, {for (final i in items) i.itemId: i}, catalog);
});
