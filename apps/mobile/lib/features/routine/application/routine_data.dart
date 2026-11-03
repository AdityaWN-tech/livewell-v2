import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';
import '../domain/routine_catalog.dart';
import '../domain/routine_editing.dart';
import '../domain/routine_editing.dart' as edit show applyTemplate, copyDay;

/// My Daily Routine for the screens (T-GOL-03b).

final routinesProvider = StreamProvider<List<Routine>>(
  (ref) => ref.watch(routineRepositoryProvider).watchRoutines(),
);

final routineItemsProvider = StreamProvider<List<RoutineItem>>(
  (ref) => ref.watch(routineRepositoryProvider).watchItems(),
);

/// The logs of a local date (yyyy-mm-dd), by item id.
final routineLogsProvider =
    StreamProvider.family<Map<String, RoutineLog>, String>(
      (ref, date) => ref
          .watch(routineRepositoryProvider)
          .watchLogs(date)
          .map((logs) => {for (final l in logs) l.itemId: l}),
    );

/// A mode just changed on this phone, shown at once (and in the dev
/// preview, where nothing is saved). Null = follow the profile.
class _LocalMode extends Notifier<(RoutineMode?,)?> {
  @override
  (RoutineMode?,)? build() => null;

  void set(RoutineMode? mode) => state = (mode,);
}

final _localModeProvider = NotifierProvider<_LocalMode, (RoutineMode?,)?>(
  _LocalMode.new,
);

/// The life-event mode (FR-DLY-09), or null.
final routineModeProvider = Provider<RoutineMode?>((ref) {
  final local = ref.watch(_localModeProvider);
  if (local != null) return local.$1;
  final profile = ref.watch(currentProfileProvider).value;
  return RoutineMode.fromData(profile?.settings[ProfileSettings.routineMode]);
});

/// The day's items, in order.
final routineDayProvider = Provider.family<List<RoutineItem>, Weekday>((
  ref,
  day,
) {
  final routines = ref.watch(routinesProvider).value ?? const [];
  final items = ref.watch(routineItemsProvider).value ?? const [];
  return itemsForDay(routines, items, day);
});

/// Today's routine: items still running (after any mode) and how many are
/// done, for the Plan card and, later, Home (GOL-03e).
final todayRoutineProvider = Provider<({int total, int done})>((ref) {
  final now = ref.watch(clockProvider)();
  final date = localDateKey(now);
  final day = activeItems(
    ref.watch(routineDayProvider(Weekday.of(now))),
    ref.watch(routineModeProvider),
    date,
  );
  final logs = ref.watch(routineLogsProvider(date)).value ?? const {};
  return (
    total: day.length,
    done: day.where((i) => logs[i.itemId]?.status == RoutineStatus.done).length,
  );
});

/// Everything the routine screen changes. Each method saves what the pure
/// functions in routine_editing.dart return.
class RoutineActions {
  RoutineActions(this._ref);

  final Ref _ref;

  RoutineRepository get _repo => _ref.read(routineRepositoryProvider);
  List<Routine> get _routines => _ref.read(routinesProvider).value ?? const [];
  List<RoutineItem> get _items =>
      _ref.read(routineItemsProvider).value ?? const [];

  String newId() => _repo.newId();

  /// Saves an item; a new one goes into "My routine" (made on first use).
  Future<void> save(RoutineItem item) async {
    if (item.routineId == myRoutineId &&
        !_routines.any((r) => r.routineId == myRoutineId)) {
      await _repo.saveRoutine(
        const Routine(
          routineId: myRoutineId,
          name: 'My routine',
          days: everyDay,
        ),
      );
    }
    await _repo.saveItem(item);
  }

  Future<void> delete(RoutineItem item) => _repo.deleteItem(item.itemId);

  /// Takes [day] out of [item]'s days (it stays on its other days).
  Future<void> removeFromDay(RoutineItem item, Weekday day) => _repo.saveItem(
    item.copyWith(days: daysOf(item, _routines).difference({day})),
  );

  Future<void> mark(RoutineItem item, RoutineStatus status) {
    final date = localDateKey(_ref.read(clockProvider)());
    return _repo.saveLog(
      RoutineLog(
        date: date,
        itemId: item.itemId,
        status: status,
        source: RoutineSource.app,
      ),
    );
  }

  /// Returns the days that were full and left out.
  Future<Set<Weekday>> copyDay(Weekday from, Set<Weekday> targets) async {
    final result = edit.copyDay(_routines, _items, from, targets);
    for (final i in result.changed) {
      await _repo.saveItem(i);
    }
    return result.full;
  }

  Future<void> reorder(
    List<RoutineItem> day,
    int oldIndex,
    int newIndex,
  ) async {
    for (final i in reorderDay(day, oldIndex, newIndex)) {
      await _repo.saveItem(i);
    }
  }

  /// Returns how many template items didn't fit (12 a day).
  Future<int> applyTemplate(
    RoutineTemplate t,
    RoutineCatalog catalog,
    Weekday selected,
  ) async {
    final result = edit.applyTemplate(
      t,
      catalog,
      selected: selected,
      routineId: _repo.newId(),
      routineName: t.label,
      newId: _repo.newId,
      activityLimited: _ref.read(currentProfileProvider).value?.activityLimited,
      routines: _routines,
      existing: _items,
    );
    await _repo.saveRoutine(result.routine);
    for (final i in result.items) {
      await _repo.saveItem(i);
    }
    return result.skipped;
  }

  /// Turns a life-event mode on (from today) or off (null).
  Future<void> setMode(ModeKind? kind) async {
    final mode = kind == null
        ? null
        : RoutineMode.start(kind, _ref.read(clockProvider)());
    _ref.read(_localModeProvider.notifier).set(mode);
    final uid = _ref.read(signedInUidProvider);
    if (uid == null) return;
    await _ref.read(profileRepositoryProvider).updateSettings(uid, {
      ProfileSettings.routineMode: mode?.toData() ?? modeOffData,
    });
  }
}

final routineActionsProvider = Provider<RoutineActions>(RoutineActions.new);
