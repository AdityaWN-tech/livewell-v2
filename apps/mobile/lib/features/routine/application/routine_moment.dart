import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/flavor.dart';
import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../home/application/home_data.dart' show firstNameProvider;
import '../../moments/domain/coach_message.dart';
import '../../starter_plan/domain/touchpoints.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';
import '../domain/routine_catalog.dart';
import '../domain/routine_editing.dart';
import '../domain/routine_reminders.dart';
import 'routine_data.dart';

/// Routine reminders and the coach (T-GOL-03d).

/// The items a routine reminder is about, in order (missing ones left out).
final routineReminderItemsProvider =
    FutureProvider.family<List<RoutineItem>, String>((ref, payload) async {
      final p = parseRoutinePayload(payload);
      if (p == null) return const [];
      final items = await ref.watch(routineItemsProvider.future);
      final byId = {for (final i in items) i.itemId: i};
      return [for (final id in p.itemIds) ?byId[id]];
    });

/// What the coach says for a routine reminder: an approved catalog line for
/// each item it announces, one after the other. A custom item gets a
/// general line; its words are shown as text, never spoken (FR-VOC-05).
/// Null when there is nothing it may say (lines not approved outside dev,
/// or "Coach announces it" off for every item).
final routineMessageProvider = FutureProvider.family<CoachMessage?, String>((
  ref,
  payload,
) async {
  final catalog = await ref.watch(routineCatalogProvider.future);
  final items = await ref.watch(routineReminderItemsProvider(payload).future);
  final firstName = ref.watch(firstNameProvider);
  final approvedOnly = ref.watch(flavorProvider) != Flavor.dev;
  final now = ref.watch(clockProvider)();
  // A different line each day, so the coach doesn't repeat itself.
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(now.year)).inDays;
  final ids = <String>[];
  final texts = <String>[];
  var usedName = false;
  for (final i in items.where((i) => i.avatarAnnounce)) {
    final line = catalog.pickLine(
      i,
      // The name once, in the first line.
      firstName: ids.isEmpty ? firstName : null,
      time: spokenTime(i.time),
      approvedOnly: approvedOnly,
      pick: day,
    );
    if (line == null) continue;
    ids.add(line.id);
    texts.add(line.text);
    usedName = usedName || line.usedName;
  }
  if (texts.isEmpty) return null;
  return CoachMessage(
    messageId: 'routine.${ids.join('+')}@v${catalog.version}',
    moment: Moment.routineItem,
    text: texts.join(' '),
    emotion: CoachEmotion.encouraging,
    primaryAction: MomentAction.done,
    secondaryActions: const [MomentAction.notToday],
    containsUserText: usedName,
    approved: catalog.approved,
  );
});

/// Remembers which items the coach already asked about ("Want to move or
/// pause this one?"), so it asks once (a trivial UI flag; spec 10.4 allows
/// SharedPreferences).
abstract class RoutineAskStore {
  Future<Set<String>> asked();
  Future<void> markAsked(String itemId);
}

class SharedPrefsRoutineAskStore implements RoutineAskStore {
  static const _key = 'routine_ignored_asked';

  @override
  Future<Set<String>> asked() async => {
    ...?(await SharedPreferences.getInstance()).getStringList(_key),
  };

  @override
  Future<void> markAsked(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [...?prefs.getStringList(_key), itemId]);
  }
}

final routineAskStoreProvider = Provider<RoutineAskStore>(
  (ref) => SharedPrefsRoutineAskStore(),
);

/// Logs by date (date → item ids marked done or skipped).
Map<String, Set<String>> loggedByDate(Iterable<RoutineLog> logs) {
  final out = <String, Set<String>>{};
  for (final l in logs) {
    (out[l.date] ??= {}).add(l.itemId);
  }
  return out;
}

/// The first item whose reminder was ignored [ignoredDaysToAsk] days in a
/// row and that the coach hasn't asked about yet, or null.
final ignoredItemProvider = FutureProvider<RoutineItem?>((ref) async {
  final now = ref.watch(clockProvider)();
  final routines = await ref.watch(routinesProvider.future);
  final items = await ref.watch(routineItemsProvider.future);
  if (!items.any((i) => i.reminder)) return null;
  // Today's logs change as items are marked; they don't change the answer
  // (it looks at yesterday and before), but a new day does.
  final from = localDateKey(DateTime(now.year, now.month, now.day - 14));
  final to = localDateKey(DateTime(now.year, now.month, now.day - 1));
  final logged = loggedByDate(
    await ref.watch(routineRepositoryProvider).logsBetween(from, to),
  );
  final asked = await ref.watch(routineAskStoreProvider).asked();
  for (final i in items) {
    if (asked.contains(i.itemId)) continue;
    if (ignoredDays(i, routines, logged, now, addedOn: i.addedAt) >=
        ignoredDaysToAsk) {
      return i;
    }
  }
  return null;
});

/// The routine reminders to schedule from [now] (with the plan's, by
/// PlanScheduler). Empty when routine reminders are off or anything can't
/// be read: the routine still works in the app.
Future<List<RoutineReminder>> routineRemindersFor(
  Ref ref, {
  required DateTime now,
  required Map<String, dynamic> settings,
  required QuietHours quiet,
}) async {
  final perDay = routineRemindersPerDay(
    settings[ProfileSettings.routineRemindersPerDay],
  );
  if (perDay == 0) return const [];
  try {
    final repo = ref.read(routineRepositoryProvider);
    final items = await repo.watchItems().first;
    if (!items.any((i) => i.reminder)) return const [];
    final logs = await repo.logsBetween(
      localDateKey(now),
      localDateKey(
        DateTime(now.year, now.month, now.day + routineDaysAhead - 1),
      ),
    );
    return buildRoutineReminders(
      routines: await repo.watchRoutines().first,
      items: items,
      logged: loggedByDate(logs),
      mode: RoutineMode.fromData(settings[ProfileSettings.routineMode]),
      quiet: quiet,
      now: now,
      perDay: perDay,
    );
  } catch (_) {
    return const [];
  }
}

/// Marks the items of a routine reminder done or skipped from its moment
/// (source: notification) or the widget. Idempotent by date and item.
Future<void> markFromReminder(
  Ref ref,
  String payload,
  RoutineStatus status, {
  RoutineSource source = RoutineSource.notification,
}) async {
  final p = parseRoutinePayload(payload);
  if (p == null) return;
  final repo = ref.read(routineRepositoryProvider);
  for (final id in p.itemIds) {
    await repo.saveLog(
      RoutineLog(date: p.date, itemId: id, status: status, source: source),
    );
  }
}

final routineReminderActionsProvider = Provider<RoutineReminderActions>(
  RoutineReminderActions.new,
);

/// The same, reachable from widgets.
class RoutineReminderActions {
  RoutineReminderActions(this._ref);

  final Ref _ref;

  Future<void> mark(
    String payload,
    RoutineStatus status, {
    RoutineSource source = RoutineSource.notification,
  }) => markFromReminder(_ref, payload, status, source: source);
}
