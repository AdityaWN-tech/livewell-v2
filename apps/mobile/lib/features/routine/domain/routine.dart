/// My Daily Routine (T-GOL-03a): routines the person builds for each day of
/// the week, beside the coach's plan. Routine items never count for the
/// streak; done items count as healthy actions in Track (GOL-03e).
library;

/// Days of the week, stored as their names (`mon` .. `sun`).
enum Weekday {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  /// The weekday of a local time (follows the device's time zone, FR-TRV).
  static Weekday of(DateTime local) => values[local.weekday - 1];

  static Weekday? parse(String? s) =>
      values.where((d) => d.name == s).firstOrNull;
}

const everyDay = {...Weekday.values};

/// Up to 12 routine items a day (T-GOL-03), across all of the day's routines.
const maxItemsPerDay = 12;

/// A routine's name and a custom item's label stay short.
const routineNameMaxLength = 40;
const customLabelMaxLength = 40;

/// Minutes an item may take.
const minDurationMin = 1;
const maxDurationMin = 180;

/// Item ids: letters, digits and dashes (they are part of a log id).
final _itemIdPattern = RegExp(r'^[A-Za-z0-9-]{1,40}$');
final _hhmm = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

bool isValidItemId(String id) => _itemIdPattern.hasMatch(id);
bool isValidTime(String hhmm) => _hhmm.hasMatch(hhmm);

/// Minutes since midnight of "HH:MM".
int minutesOf(String hhmm) =>
    int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

/// One step in a routine: an activity from the approved catalog, or a
/// custom one the person typed. A custom label is shown as text only and is
/// never spoken by the coach (FR-VOC-05).
class RoutineItem {
  const RoutineItem({
    required this.itemId,
    required this.routineId,
    this.catalogId,
    required this.label,
    required this.icon,
    required this.time,
    required this.durationMin,
    this.days,
    this.reminder = true,
    this.avatarAnnounce = true,
    this.order = 0,
    this.addedAt,
  });

  final String itemId;

  /// The routine it belongs to; the item falls on that routine's days
  /// unless it has its own [days].
  final String routineId;

  /// The catalog activity, or null for a custom item.
  final String? catalogId;
  final String label;

  /// An icon id from [routineIcons].
  final String icon;

  /// Local "HH:MM".
  final String time;
  final int durationMin;

  /// Days this item repeats, overriding its routine's days; null = the
  /// routine's days.
  final Set<Weekday>? days;
  final bool reminder;

  /// Whether the coach announces it (an Avatar Moment, GOL-03d).
  final bool avatarAnnounce;

  /// Position among items at the same time (drag to reorder).
  final int order;

  /// When it was first saved (the document's created_at); null until then.
  final DateTime? addedAt;

  bool get custom => catalogId == null;

  /// Everything the rules check, so the app never queues a write that would
  /// be refused when it syncs.
  bool get isValid =>
      isValidItemId(itemId) &&
      isValidItemId(routineId) &&
      label.trim().isNotEmpty &&
      label.length <= customLabelMaxLength &&
      routineIcons.contains(icon) &&
      isValidTime(time) &&
      durationMin >= minDurationMin &&
      durationMin <= maxDurationMin &&
      (days == null || days!.isNotEmpty);

  RoutineItem copyWith({
    String? label,
    String? icon,
    String? time,
    int? durationMin,
    Set<Weekday>? days,
    bool clearDays = false,
    bool? reminder,
    bool? avatarAnnounce,
    int? order,
    String? routineId,
  }) => RoutineItem(
    itemId: itemId,
    routineId: routineId ?? this.routineId,
    catalogId: catalogId,
    label: label ?? this.label,
    icon: icon ?? this.icon,
    time: time ?? this.time,
    durationMin: durationMin ?? this.durationMin,
    days: clearDays ? null : (days ?? this.days),
    reminder: reminder ?? this.reminder,
    avatarAnnounce: avatarAnnounce ?? this.avatarAnnounce,
    order: order ?? this.order,
    addedAt: addedAt,
  );
}

/// users/{uid}/routines/{routineId}: a named set of days (e.g. "Weekdays"
/// Mon–Fri, "Weekend" Sat–Sun). Its items are separate documents
/// (users/{uid}/routine_items, D-44).
class Routine {
  const Routine({
    required this.routineId,
    required this.name,
    required this.days,
    this.active = true,
  });

  final String routineId;
  final String name;
  final Set<Weekday> days;

  /// Off = paused (routines are never deleted, like habits).
  final bool active;

  bool get isValid =>
      isValidItemId(routineId) &&
      name.trim().isNotEmpty &&
      name.length <= routineNameMaxLength &&
      days.isNotEmpty;

  Routine copyWith({String? name, Set<Weekday>? days, bool? active}) => Routine(
    routineId: routineId,
    name: name ?? this.name,
    days: days ?? this.days,
    active: active ?? this.active,
  );
}

/// The day's routine items, from active routines only, in time order (then
/// the person's own order). An item's own days win over its routine's; an
/// item whose routine is gone is left out.
List<RoutineItem> itemsForDay(
  Iterable<Routine> routines,
  Iterable<RoutineItem> items,
  Weekday day,
) {
  final byId = {for (final r in routines) r.routineId: r};
  return [
    for (final i in items)
      if (byId[i.routineId] case final r? when r.active)
        if ((i.days ?? r.days).contains(day)) i,
  ]..sort((a, b) {
    final t = minutesOf(a.time).compareTo(minutesOf(b.time));
    return t != 0 ? t : a.order.compareTo(b.order);
  });
}

/// Whether one more item fits on [day] (the 12-a-day limit; the rules
/// can't count, so the app keeps it).
bool hasRoomOn(
  Iterable<Routine> routines,
  Iterable<RoutineItem> items,
  Weekday day,
) => itemsForDay(routines, items, day).length < maxItemsPerDay;

enum RoutineStatus { done, skipped }

/// Where an item was marked: in the app, from the widget, or from its
/// reminder notification.
enum RoutineSource { app, widget, notification }

/// users/{uid}/routine_logs/{date_itemId}: one per item per local day, so
/// marking the same item twice (offline, then from the widget) is one log.
class RoutineLog {
  const RoutineLog({
    required this.date,
    required this.itemId,
    required this.status,
    required this.source,
  });

  /// Local date, yyyy-mm-dd.
  final String date;
  final String itemId;
  final RoutineStatus status;
  final RoutineSource source;

  String get id => logId(date, itemId);
}

String logId(String date, String itemId) => '${date}_$itemId';

/// The icons a routine item may use (catalog and custom). The screen maps
/// each to a drawing (GOL-03b); the rules don't need them.
const routineIcons = {
  'sunrise',
  'water',
  'stretch',
  'walk',
  'breathe',
  'breakfast',
  'pause',
  'family',
  'book',
  'quiet',
  'screen_off',
  'moon',
  'bed',
  'star',
  'heart',
  'music',
};
