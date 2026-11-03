import '../../checkin/domain/checkin.dart';
import '../../starter_plan/domain/touchpoints.dart';
import 'routine.dart';
import 'routine_editing.dart';

/// Routine reminders (T-GOL-03d): which routine items notify, when, and in
/// which bundles. Pure, so it can be tested; scheduled together with the
/// plan's touchpoints (PlanScheduler).

/// "Routine reminders per day" (needs-product: default 6, at most 10). Its
/// own category, beside the coach's caps (FR-DLY-04, FR-TCH-01).
const routineRemindersDefault = 6;
const routineRemindersMax = 10;

/// Items this close to the first one share a notification.
const bundleWindowMinutes = 15;

/// Ignored this many scheduled days in a row: the coach asks once whether
/// to move or pause the item.
const ignoredDaysToAsk = 5;

/// How far ahead routine reminders are scheduled (rescheduled on every
/// change and app start).
const routineDaysAhead = 7;

/// One routine notification: one item, or a bundle of items close together.
class RoutineReminder {
  const RoutineReminder({
    required this.id,
    required this.when,
    required this.date,
    required this.itemIds,
  });

  /// Stable per date and position; its own range, apart from the plan's.
  final int id;
  final DateTime when;

  /// Local date, yyyy-mm-dd.
  final String date;
  final List<String> itemIds;

  String get payload => routinePayload(date, itemIds);
}

/// A reminder's tap payload: "routine:2026-10-14:id1,id2".
String routinePayload(String date, List<String> itemIds) =>
    'routine:$date:${itemIds.join(',')}';

/// The date and items of a routine payload, or null for another payload.
({String date, List<String> itemIds})? parseRoutinePayload(String payload) {
  final m = RegExp(r'^routine:(\d{4}-\d{2}-\d{2}):([A-Za-z0-9,-]+)$')
      .firstMatch(payload);
  if (m == null) return null;
  final ids = m.group(2)!.split(',').where(isValidItemId).toList();
  return ids.isEmpty ? null : (date: m.group(1)!, itemIds: ids);
}

/// Plan ids stay under 100,000,000; routine ids start at 1,000,000,000.
int routineReminderId(DateTime day, int n) =>
    1000000000 + (day.month * 100 + day.day) * 100 + n;

/// Routine reminders from [now] for [routineDaysAhead] days. An item
/// notifies when its reminder is on, it runs that day (life-event modes
/// shrink or rest the day), it isn't already done or skipped ([logged]:
/// date → item ids), its time is still ahead and outside quiet hours.
/// Items within [bundleWindowMinutes] of a bundle's first item join it.
/// At most [perDay] notifications a day, the earliest kept.
List<RoutineReminder> buildRoutineReminders({
  required Iterable<Routine> routines,
  required Iterable<RoutineItem> items,
  required Map<String, Set<String>> logged,
  required RoutineMode? mode,
  required QuietHours quiet,
  required DateTime now,
  required int perDay,
  bool consent = true,
}) {
  if (!consent || perDay <= 0) return const [];
  final out = <RoutineReminder>[];
  for (var d = 0; d < routineDaysAhead; d++) {
    final day = DateTime(now.year, now.month, now.day + d);
    final date = localDateKey(day);
    final done = logged[date] ?? const {};
    final due = [
      for (final i in activeItems(
        itemsForDay(routines, items, Weekday.of(day)),
        mode,
        date,
      ))
        if (i.reminder && !done.contains(i.itemId)) i,
    ];
    final bundles = <List<RoutineItem>>[];
    for (final i in due) {
      final m = minutesOf(i.time);
      final when = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
      if (!when.isAfter(now) || quiet.contains(ClockTime(m ~/ 60, m % 60))) {
        continue;
      }
      if (bundles.isNotEmpty &&
          m - minutesOf(bundles.last.first.time) <= bundleWindowMinutes) {
        bundles.last.add(i);
      } else {
        bundles.add([i]);
      }
    }
    for (final (n, b) in bundles.take(perDay).indexed) {
      final m = minutesOf(b.first.time);
      out.add(
        RoutineReminder(
          id: routineReminderId(day, n),
          when: DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
          date: date,
          itemIds: [for (final i in b) i.itemId],
        ),
      );
    }
  }
  return out;
}

/// The "Routine reminders per day" setting, kept within 0..10 (0 = off).
int routineRemindersPerDay(Object? stored) => stored is int
    ? stored.clamp(0, routineRemindersMax)
    : routineRemindersDefault;

/// How many of [item]'s recent days, in a row up to yesterday, passed with
/// its reminder on and nothing marked (done or skipped). Days it doesn't
/// fall on are passed over; days before it was added don't count.
int ignoredDays(
  RoutineItem item,
  Iterable<Routine> routines,
  Map<String, Set<String>> logged,
  DateTime today, {
  DateTime? addedOn,
}) {
  if (!item.reminder) return 0;
  final days = daysOf(item, routines);
  var count = 0;
  // Two weeks back covers 5 scheduled days even for a twice-a-week item.
  for (var k = 1; k <= 14 && count < ignoredDaysToAsk; k++) {
    final day = DateTime(today.year, today.month, today.day - k);
    if (addedOn != null &&
        day.isBefore(DateTime(addedOn.year, addedOn.month, addedOn.day))) {
      break;
    }
    if (!days.contains(Weekday.of(day))) continue;
    if (logged[localDateKey(day)]?.contains(item.itemId) ?? false) break;
    count++;
  }
  return count;
}
