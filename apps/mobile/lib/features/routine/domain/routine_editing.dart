import 'routine.dart';
import 'routine_catalog.dart';

/// Editing a day of My Daily Routine (T-GOL-03b): copy a day, drag to
/// reorder, time clashes, templates and life-event modes. Pure functions,
/// so the screen only saves what they return.

/// The id of the routine that items added by hand go into (every day; an
/// item narrows its own days).
const myRoutineId = 'my-routine';

/// The days [item] falls on.
Set<Weekday> daysOf(RoutineItem item, Iterable<Routine> routines) =>
    item.days ??
    routines.where((r) => r.routineId == item.routineId).firstOrNull?.days ??
    const {};

/// "Copy this day to…": every item of [from] also falls on [targets]
/// (the same item, so a later edit changes it everywhere). A target day
/// that would go over 12 items is left out and returned in [full].
({List<RoutineItem> changed, Set<Weekday> full}) copyDay(
  Iterable<Routine> routines,
  Iterable<RoutineItem> items,
  Weekday from,
  Set<Weekday> targets,
) {
  final source = itemsForDay(routines, items, from);
  final full = <Weekday>{};
  final ok = <Weekday>{};
  for (final day in targets.difference({from})) {
    final there = itemsForDay(routines, items, day);
    final adding = source.where((i) => !there.contains(i)).length;
    if (there.length + adding > maxItemsPerDay) {
      full.add(day);
    } else {
      ok.add(day);
    }
  }
  final changed = [
    for (final i in source)
      if (!daysOf(i, routines).containsAll(ok))
        i.copyWith(days: {...daysOf(i, routines), ...ok}),
  ];
  return (changed: changed, full: full);
}

/// Drag to reorder: the moved item takes the time of the item it lands
/// after (or before, at the top), and the day's order is renumbered.
/// [newIndex] is where it ends up in the list without it. Returns the
/// items that changed.
List<RoutineItem> reorderDay(
  List<RoutineItem> day,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex == newIndex || day.length < 2) return const [];
  final list = [...day];
  final moved = list.removeAt(oldIndex);
  final neighbour = newIndex > 0 ? list[newIndex - 1] : list[0];
  list.insert(newIndex, moved.copyWith(time: neighbour.time));
  final changed = <RoutineItem>[];
  for (final (n, i) in list.indexed) {
    final original = day.firstWhere((d) => d.itemId == i.itemId);
    final next = i.copyWith(order: n);
    if (next.order != original.order || next.time != original.time) {
      changed.add(next);
    }
  }
  return changed;
}

/// Times with more than one item on the day ("Two things at 7:00").
List<String> clashes(List<RoutineItem> day) {
  final seen = <String, int>{};
  for (final i in day) {
    seen[i.time] = (seen[i.time] ?? 0) + 1;
  }
  return [
    for (final e in seen.entries)
      if (e.value > 1) e.key,
  ];
}

/// What applying a template adds: a routine for its days and its items.
/// Movement items are left out for people whose activity is limited
/// (FR-GOL-03: off by default); items that would push a day past 12 are
/// left out too ([skipped] counts them).
({Routine routine, List<RoutineItem> items, int skipped}) applyTemplate(
  RoutineTemplate t,
  RoutineCatalog catalog, {
  required Weekday selected,
  required String routineId,
  required String routineName,
  required String Function() newId,
  required bool? activityLimited,
  required Iterable<Routine> routines,
  required Iterable<RoutineItem> existing,
}) {
  final days = t.days.resolve(selected);
  final routine = Routine(routineId: routineId, name: routineName, days: days);
  var room = maxItemsPerDay;
  for (final d in days) {
    final left = maxItemsPerDay - itemsForDay(routines, existing, d).length;
    if (left < room) room = left;
  }
  final items = <RoutineItem>[];
  var skipped = 0;
  for (final (n, (catalogId, time)) in t.items.indexed) {
    final a = catalog.byId(catalogId);
    if (a == null) continue;
    if (catalog.needsClinicianCheck(a, activityLimited: activityLimited)) {
      continue;
    }
    if (items.length >= room) {
      skipped++;
      continue;
    }
    items.add(
      catalog.newItem(
        a,
        itemId: newId(),
        routineId: routineId,
        activityLimited: activityLimited,
        order: n,
        time: time,
      ),
    );
  }
  return (routine: routine, items: items, skipped: skipped);
}

/// Life-event modes (FR-DLY-09). Routine items never count for the
/// streak, so a mode only changes what is shown and reminded.
enum ModeKind {
  /// Away from home: the routine shrinks to a few items.
  travel,

  /// Unwell: the routine rests for the day.
  sick,

  /// A busy week: the routine shrinks to a few items.
  busy;

  /// How many days a mode lasts when turned on (the person can end it).
  int get lengthDays => switch (this) {
    travel => 7,
    sick => 1,
    busy => 7,
  };
}

/// The items kept on a shrunk day (the earliest ones).
const shrunkDayItems = 3;

/// users/{uid}.routine_mode: {kind, until} (until = last day, yyyy-mm-dd).
class RoutineMode {
  const RoutineMode({required this.kind, required this.until});

  final ModeKind kind;
  final String until;

  bool activeOn(String date) => date.compareTo(until) <= 0;

  static RoutineMode? fromData(Object? data) {
    if (data is! Map) return null;
    final kind = ModeKind.values.where((k) => k.name == data['kind']);
    final until = data['until'];
    if (kind.isEmpty || until is! String) return null;
    return RoutineMode(kind: kind.first, until: until);
  }

  Map<String, Object> toData() => {'kind': kind.name, 'until': until};

  /// Turned on today: lasts [ModeKind.lengthDays] days including today.
  static RoutineMode start(ModeKind kind, DateTime today) {
    final last = DateTime(
      today.year,
      today.month,
      today.day + kind.lengthDays - 1,
    );
    String two(int n) => n.toString().padLeft(2, '0');
    return RoutineMode(
      kind: kind,
      until: '${last.year}-${two(last.month)}-${two(last.day)}',
    );
  }
}

/// The mode's value when it is turned off (rules accept kind: none).
const modeOffData = {'kind': 'none'};

/// The items that still run on [date] under [mode]: all of them, the
/// earliest few on a shrunk day, none on a sick day. The others stay in the
/// routine, just quiet.
List<RoutineItem> activeItems(
  List<RoutineItem> day,
  RoutineMode? mode,
  String date,
) {
  if (mode == null || !mode.activeOn(date)) return day;
  return switch (mode.kind) {
    ModeKind.sick => const [],
    ModeKind.travel || ModeKind.busy => day.take(shrunkDayItems).toList(),
  };
}
