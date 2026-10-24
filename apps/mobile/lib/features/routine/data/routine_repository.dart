import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/routine.dart';
import '../domain/routine_catalog.dart';

/// The approved activity catalog (copy of content/routine/catalog.json).
final routineCatalogProvider = FutureProvider<RoutineCatalog>(
  (ref) async => RoutineCatalog.parse(
    await rootBundle.loadString('assets/routine/catalog.json', cache: false),
  ),
);

/// users/{uid}/routines, routine_items and routine_logs (T-GOL-03a).
abstract class RoutineRepository {
  /// Every routine, active or paused, live.
  Stream<List<Routine>> watchRoutines();

  /// Creates or replaces [routine]. Works offline (the write is queued).
  Future<void> saveRoutine(Routine routine);

  /// Every routine item, live.
  Stream<List<RoutineItem>> watchItems();

  /// Creates or replaces [item]. Works offline.
  Future<void> saveItem(RoutineItem item);

  /// Removes an item (the screen offers undo by saving it again).
  Future<void> deleteItem(String itemId);

  /// The day's logs (yyyy-mm-dd), live.
  Stream<List<RoutineLog>> watchLogs(String date);

  /// Marks an item done or skipped for a day. Idempotent: the log's id is
  /// date_itemId, so the same item marked twice is one log.
  Future<void> saveLog(RoutineLog log);

  /// A new id for a routine or an item (letters and digits).
  String newId();
}

/// Firestore implementation. Offline support comes from Firestore's own
/// offline persistence for now.
/// TODO(T-FND-08): move routines into the encrypted local database
/// (Drift + SQLCipher) with its sync queue.
class FirestoreRoutineRepository implements RoutineRepository {
  FirestoreRoutineRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  static const serverWait = Duration(seconds: 3);
  static const schemaVersion = 1;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid());
  CollectionReference<Map<String, dynamic>> get _routines =>
      _user.collection('routines');
  CollectionReference<Map<String, dynamic>> get _items =>
      _user.collection('routine_items');
  CollectionReference<Map<String, dynamic>> get _logs =>
      _user.collection('routine_logs');

  @override
  String newId() => _routines.doc().id;

  @override
  Stream<List<Routine>> watchRoutines() => _routines.snapshots().map(
    (s) => [for (final d in s.docs) ?routineFrom(d.id, d.data())],
  );

  @override
  Future<void> saveRoutine(Routine r) {
    if (!r.isValid) throw ArgumentError('invalid routine ${r.routineId}');
    return _upsert(_routines.doc(r.routineId), routineData(r));
  }

  @override
  Stream<List<RoutineItem>> watchItems() => _items.snapshots().map(
    (s) => [for (final d in s.docs) ?itemFrom(d.id, d.data())],
  );

  @override
  Future<void> saveItem(RoutineItem item) {
    if (!item.isValid) throw ArgumentError('invalid item ${item.itemId}');
    return _upsert(_items.doc(item.itemId), itemData(item));
  }

  @override
  Future<void> deleteItem(String itemId) =>
      _items.doc(itemId).delete().timeout(serverWait, onTimeout: () {});

  @override
  Stream<List<RoutineLog>> watchLogs(String date) => _logs
      .where('date', isEqualTo: date)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?logFrom(d.data())]);

  @override
  Future<void> saveLog(RoutineLog log) {
    if (!isValidItemId(log.itemId)) {
      throw ArgumentError('invalid item id ${log.itemId}');
    }
    return _upsert(_logs.doc(log.id), {
      'date': log.date,
      'item_id': log.itemId,
      'status': log.status.name,
      'source': log.source.name,
    });
  }

  /// Writes [data] with updated_at and schema_version; created_at only on
  /// the first write, so a second (offline) save never changes it (the
  /// rules require that).
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

  /// The routine document's fields (without the meta fields).
  static Map<String, Object> routineData(Routine r) => {
    'name': r.name,
    'days': _dayNames(r.days),
    'active': r.active,
  };

  /// The item document's fields (without the meta fields). A catalog item
  /// has catalog_id, a custom one custom: true, never both.
  static Map<String, Object> itemData(RoutineItem i) => {
    'routine_id': i.routineId,
    if (i.catalogId != null) 'catalog_id': i.catalogId! else 'custom': true,
    'label': i.label,
    'icon': i.icon,
    'time': i.time,
    'duration_min': i.durationMin,
    if (i.days != null) 'days': _dayNames(i.days!),
    'reminder': i.reminder,
    'avatar_announce': i.avatarAnnounce,
    'order': i.order,
  };

  static List<String> _dayNames(Set<Weekday> days) => [
    for (final d in Weekday.values)
      if (days.contains(d)) d.name,
  ];

  static Set<Weekday> _days(Object? list) => {
    for (final s in (list as List? ?? const []).cast<String>())
      ?Weekday.parse(s),
  };

  /// Null for a document this version can't read (skipped, not a crash).
  static Routine? routineFrom(String id, Map<String, dynamic> d) {
    try {
      return Routine(
        routineId: id,
        name: d['name'] as String,
        days: _days(d['days']),
        active: d['active'] as bool? ?? true,
      );
    } on TypeError {
      return null;
    }
  }

  static RoutineItem? itemFrom(String id, Map<String, dynamic> d) {
    try {
      return RoutineItem(
        itemId: id,
        routineId: d['routine_id'] as String,
        catalogId: d['catalog_id'] as String?,
        label: d['label'] as String,
        icon: d['icon'] as String,
        time: d['time'] as String,
        durationMin: d['duration_min'] as int,
        days: d.containsKey('days') ? _days(d['days']) : null,
        reminder: d['reminder'] as bool? ?? false,
        avatarAnnounce: d['avatar_announce'] as bool? ?? false,
        order: d['order'] as int? ?? 0,
      );
    } on TypeError {
      return null;
    }
  }

  static RoutineLog? logFrom(Map<String, dynamic> d) {
    final status = RoutineStatus.values
        .where((s) => s.name == d['status'])
        .firstOrNull;
    final source = RoutineSource.values
        .where((s) => s.name == d['source'])
        .firstOrNull;
    if (status == null || source == null) return null;
    return RoutineLog(
      date: d['date'] as String,
      itemId: d['item_id'] as String,
      status: status,
      source: source,
    );
  }
}

/// Dev preview: kept in memory, nothing saved.
class InMemoryRoutineRepository implements RoutineRepository {
  final _routines = <String, Routine>{};
  final _items = <String, RoutineItem>{};
  final _logs = <String, RoutineLog>{};
  final _changes = StreamController<void>.broadcast();
  final _random = Random();

  @override
  String newId() => [
    for (var i = 0; i < 20; i++)
      'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
  ].join();

  @override
  Stream<List<Routine>> watchRoutines() async* {
    yield _routines.values.toList();
    yield* _changes.stream.map((_) => _routines.values.toList());
  }

  @override
  Future<void> saveRoutine(Routine routine) async {
    if (!routine.isValid) {
      throw ArgumentError('invalid routine ${routine.routineId}');
    }
    _routines[routine.routineId] = routine;
    _changes.add(null);
  }

  @override
  Stream<List<RoutineItem>> watchItems() async* {
    yield _items.values.toList();
    yield* _changes.stream.map((_) => _items.values.toList());
  }

  @override
  Future<void> saveItem(RoutineItem item) async {
    if (!item.isValid) throw ArgumentError('invalid item ${item.itemId}');
    _items[item.itemId] = item;
    _changes.add(null);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    _items.remove(itemId);
    _changes.add(null);
  }

  List<RoutineLog> _day(String date) =>
      _logs.values.where((l) => l.date == date).toList();

  @override
  Stream<List<RoutineLog>> watchLogs(String date) async* {
    yield _day(date);
    yield* _changes.stream.map((_) => _day(date));
  }

  @override
  Future<void> saveLog(RoutineLog log) async {
    _logs[log.id] = log;
    _changes.add(null);
  }
}

final _previewRoutinesProvider = Provider<RoutineRepository>(
  (ref) => InMemoryRoutineRepository(),
);

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  // Dev preview or nobody signed in: nothing to read or save.
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return ref.watch(_previewRoutinesProvider);
  }
  return FirestoreRoutineRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
