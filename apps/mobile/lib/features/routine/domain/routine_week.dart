import 'routine.dart';
import 'routine_catalog.dart';

/// My Daily Routine beyond its own screen (T-GOL-03e): the next item for
/// Home and the widget, items done per day for Track, and the week's win
/// for the weekly review. Pure, so it can be tested.

/// An item stays "next" this long after its time, then the one after it.
const nextGraceMinutes = 30;

/// Today's next item: the first one not yet marked whose time is at most
/// [nextGraceMinutes] ago. [day] is today's running items in order.
RoutineItem? nextRoutineItem(
  List<RoutineItem> day,
  Set<String> marked,
  DateTime now,
) {
  final nowMin = now.hour * 60 + now.minute;
  for (final i in day) {
    if (marked.contains(i.itemId)) continue;
    if (minutesOf(i.time) >= nowMin - nextGraceMinutes) return i;
  }
  return null;
}

/// Items done on each of [dates] (yyyy-mm-dd). Skipped ones don't count.
List<int> doneByDay(Iterable<RoutineLog> logs, List<String> dates) => [
  for (final d in dates)
    logs.where((l) => l.date == d && l.status == RoutineStatus.done).length,
];

/// Done items in [logs] (for "Weekly healthy actions", the North Star).
int doneCount(Iterable<RoutineLog> logs) =>
    logs.where((l) => l.status == RoutineStatus.done).length;

/// A routine win needs this many days in the week.
const winMinDays = 4;

/// The week's routine win for the weekly review: the catalog activity done
/// on the most days (at least [winMinDays]), by its approved spoken name.
/// Custom items never count: their words are never spoken (FR-VOC-05).
/// Ties go to the catalog's order.
({String spokenName, int days})? routineWin(
  Iterable<RoutineLog> logs,
  Map<String, RoutineItem> itemsById,
  RoutineCatalog catalog,
) {
  final days = <String, Set<String>>{};
  for (final l in logs) {
    if (l.status != RoutineStatus.done) continue;
    final a = catalog.byId(itemsById[l.itemId]?.catalogId);
    if (a == null) continue;
    (days[a.id] ??= {}).add(l.date);
  }
  ({String spokenName, int days})? best;
  for (final a in catalog.activities) {
    final n = days[a.id]?.length ?? 0;
    if (n >= winMinDays && (best == null || n > best.days)) {
      best = (spokenName: a.spokenName, days: n);
    }
  }
  return best;
}
