import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/goal.dart';

/// users/{uid}/goals/primary, habits/{support_1|support_2} and habit_logs
/// (Step 4a, D-53).
abstract class GoalRepository {
  /// The 30-day goal, or null before one is set. Live.
  Stream<Goal?> watchGoal();

  /// Creates or replaces the goal. Works offline (the write is queued).
  Future<void> saveGoal(Goal goal);

  /// The person's own habits, active or stopped. Live.
  Stream<List<UserHabit>> watchHabits();

  /// Creates or replaces a habit. Works offline.
  Future<void> saveHabit(UserHabit habit);

  /// The day's done logs (yyyy-mm-dd). Live.
  Stream<List<HabitLog>> watchLogs(String date);

  /// Marks a habit done for a day; the same habit twice is one log.
  Future<void> saveLog(HabitLog log);

  /// Done logs from [from] to [to] (yyyy-mm-dd, inclusive). Offline: what
  /// the phone has.
  Future<List<HabitLog>> logsBetween(String from, String to);
}

/// Firestore implementation, with Firestore's offline persistence.
/// TODO(T-FND-08): move into the encrypted local database with its sync
/// queue, like routines.
class FirestoreGoalRepository implements GoalRepository {
  FirestoreGoalRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  static const serverWait = Duration(seconds: 3);
  static const schemaVersion = 1;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid());
  DocumentReference<Map<String, dynamic>> get _goal =>
      _user.collection('goals').doc(Goal.id);
  CollectionReference<Map<String, dynamic>> get _habits =>
      _user.collection('habits');
  CollectionReference<Map<String, dynamic>> get _logs =>
      _user.collection('habit_logs');

  @override
  Stream<Goal?> watchGoal() =>
      _goal.snapshots().map((s) => s.exists ? goalFrom(s.data()!) : null);

  @override
  Future<void> saveGoal(Goal goal) {
    if (!goal.isValid) throw ArgumentError('invalid goal');
    return _upsert(_goal, goalData(goal));
  }

  @override
  Stream<List<UserHabit>> watchHabits() => _habits.snapshots().map(
    (s) => [
      for (final d in s.docs)
        if (UserHabit.ids.contains(d.id)) ?habitFrom(d.id, d.data()),
    ],
  );

  @override
  Future<void> saveHabit(UserHabit habit) {
    if (!habit.isValid) throw ArgumentError('invalid habit ${habit.id}');
    return _upsert(_habits.doc(habit.id), habitData(habit));
  }

  @override
  Stream<List<HabitLog>> watchLogs(String date) => _logs
      .where('date', isEqualTo: date)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (d.data()['status'] == 'done') ?logFrom(d.data()),
        ],
      );

  @override
  Future<List<HabitLog>> logsBetween(String from, String to) async {
    final query = _logs
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.get().timeout(serverWait);
    } catch (_) {
      snap = await query.get(const GetOptions(source: Source.cache));
    }
    return [
      for (final d in snap.docs)
        if (d.data()['status'] == 'done') ?logFrom(d.data()),
    ];
  }

  static HabitLog? logFrom(Map<String, dynamic> d) {
    try {
      return HabitLog(
        date: d['date'] as String,
        habitId: d['habit_id'] as String,
        doneAt: (d['done_at'] as Timestamp?)?.toDate(),
      );
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> saveLog(HabitLog log) => _upsert(_logs.doc(log.id), {
    'date': log.date,
    'habit_id': log.habitId,
    'status': 'done',
    'source': 'app',
    if (log.doneAt != null) 'done_at': Timestamp.fromDate(log.doneAt!),
  });

  /// Writes [data] with updated_at and schema_version; created_at only on
  /// the first write (the rules keep it fixed).
  Future<void> _upsert(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, Object> data,
  ) async {
    final fields = {
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': schemaVersion,
    };
    final write = await _exists(ref)
        ? ref.set(fields, SetOptions(merge: true))
        : ref.set({...fields, 'created_at': FieldValue.serverTimestamp()});
    // Offline, the write stays queued and the local copy updates at once.
    await write.timeout(serverWait, onTimeout: () {});
  }

  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get().timeout(serverWait)).exists;
    } catch (_) {
      try {
        return (await ref.get(const GetOptions(source: Source.cache))).exists;
      } on FirebaseException {
        return false;
      }
    }
  }

  static Map<String, Object> goalData(Goal g) => {
    'action': g.action,
    'days_per_week': g.daysPerWeek,
    'minutes': g.minutes,
    'anchor': g.anchor.name,
    'barrier_plan': g.barrierPlan,
    'link_why': g.linkWhy,
    'status': g.status.name,
    'start_date': g.startDate,
  };

  static Map<String, Object> habitData(UserHabit h) => {
    'title': h.title,
    'anchor': h.anchor.name,
    'minutes': h.minutes,
    'active': h.active,
  };

  static T? _enum<T extends Enum>(List<T> values, Object? name) =>
      values.where((v) => v.name == name).firstOrNull;

  /// Null for a document this version can't read (skipped, not a crash).
  static Goal? goalFrom(Map<String, dynamic> d) {
    try {
      final anchor = _enum(HabitAnchor.values, d['anchor']);
      final status = _enum(GoalStatus.values, d['status']);
      if (anchor == null || status == null) return null;
      return Goal(
        action: d['action'] as String,
        daysPerWeek: d['days_per_week'] as int,
        minutes: d['minutes'] as int,
        anchor: anchor,
        barrierPlan: d['barrier_plan'] as String? ?? '',
        linkWhy: d['link_why'] as bool? ?? true,
        status: status,
        startDate: d['start_date'] as String,
      );
    } on TypeError {
      return null;
    }
  }

  static UserHabit? habitFrom(String id, Map<String, dynamic> d) {
    try {
      final anchor = _enum(HabitAnchor.values, d['anchor']);
      if (anchor == null) return null;
      return UserHabit(
        id: id,
        title: d['title'] as String,
        anchor: anchor,
        minutes: d['minutes'] as int,
        active: d['active'] as bool? ?? true,
      );
    } on TypeError {
      return null;
    }
  }
}

/// Dev preview and tests: kept in memory.
class InMemoryGoalRepository implements GoalRepository {
  Goal? goal;
  final habits = <String, UserHabit>{};
  final logs = <String, HabitLog>{};
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<Goal?> watchGoal() async* {
    yield goal;
    yield* _changes.stream.map((_) => goal);
  }

  @override
  Future<void> saveGoal(Goal g) async {
    if (!g.isValid) throw ArgumentError('invalid goal');
    goal = g;
    _changes.add(null);
  }

  @override
  Stream<List<UserHabit>> watchHabits() async* {
    yield habits.values.toList();
    yield* _changes.stream.map((_) => habits.values.toList());
  }

  @override
  Future<void> saveHabit(UserHabit h) async {
    if (!h.isValid) throw ArgumentError('invalid habit ${h.id}');
    habits[h.id] = h;
    _changes.add(null);
  }

  List<HabitLog> _day(String date) =>
      logs.values.where((l) => l.date == date).toList();

  @override
  Stream<List<HabitLog>> watchLogs(String date) async* {
    yield _day(date);
    yield* _changes.stream.map((_) => _day(date));
  }

  @override
  Future<void> saveLog(HabitLog log) async {
    logs[log.id] = log;
    _changes.add(null);
  }

  @override
  Future<List<HabitLog>> logsBetween(String from, String to) async => [
    for (final l in logs.values)
      if (l.date.compareTo(from) >= 0 && l.date.compareTo(to) <= 0) l,
  ];
}

final _previewGoalsProvider = Provider<GoalRepository>(
  (ref) => InMemoryGoalRepository(),
);

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  // Dev preview or nobody signed in: nothing to read or save.
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return ref.watch(_previewGoalsProvider);
  }
  return FirestoreGoalRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
