import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/memory_fact.dart';

/// "What my coach remembers" (users/{uid}/memory_facts; FR-CNV-05,
/// T-AGT-05b). The Memory Agent writes proposals on the server; the app
/// only reads, keeps or deletes them (the Firestore rules allow nothing
/// else; a delete must wipe the text, D-100).
abstract class MemoryRepository {
  /// Proposed and saved facts, newest first. Deleted ones never appear.
  Stream<List<MemoryFact>> watch();

  /// proposed -> saved. The caller checks the consents first ([keepBlock]).
  Future<void> keep(String id);

  /// Final: the text is wiped and the fact is never shown or used again.
  Future<void> delete(String id);

  /// Deletes every fact in [ids].
  Future<void> deleteAll(Iterable<String> ids);
}

List<MemoryFact> _sorted(Iterable<MemoryFact> facts) =>
    facts.toList()..sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1; // pending (newest) first
      if (tb == null) return 1;
      return tb.compareTo(ta);
    });

class FirestoreMemoryRepository implements MemoryRepository {
  FirestoreMemoryRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  CollectionReference<Map<String, dynamic>> _col() =>
      _db.collection('users').doc(_uid()).collection('memory_facts');

  @override
  Stream<List<MemoryFact>> watch() => _col().snapshots().map(
    (q) => _sorted(
      q.docs.map((d) {
        final created = d.data()['created_at'];
        return MemoryFact.fromMap(
          d.id,
          d.data(),
          createdAt: created is Timestamp ? created.toDate() : null,
        );
      }).whereType<MemoryFact>(),
    ),
  );

  @override
  Future<void> keep(String id) => _col().doc(id).update({
    'status': 'saved',
    'updated_at': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> delete(String id) => _col().doc(id).update(_deleted());

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_col().doc(id), _deleted());
    }
    await batch.commit();
  }

  static Map<String, Object> _deleted() => {
    'status': 'deleted',
    'fact': '',
    'updated_at': FieldValue.serverTimestamp(),
  };
}

/// In memory only, for the dev preview (nothing is saved). Starts with a
/// few invented examples so the screen can be tried on a phone.
class InMemoryMemoryRepository implements MemoryRepository {
  InMemoryMemoryRepository([List<MemoryFact>? seed])
    : _facts = {for (final f in seed ?? previewSamples) f.id: f};

  final Map<String, MemoryFact> _facts;
  final _changes = StreamController<void>.broadcast();

  static final previewSamples = [
    MemoryFact(
      id: 'sample-1',
      fact: 'prefers walking after dinner',
      category: 'preference',
      sensitive: false,
      status: MemoryStatus.proposed,
      createdAt: DateTime(2026, 11, 20),
    ),
    MemoryFact(
      id: 'sample-2',
      fact: 'knee gets sore on stairs',
      category: 'physical',
      sensitive: false,
      status: MemoryStatus.saved,
      createdAt: DateTime(2026, 11, 18),
    ),
    MemoryFact(
      id: 'sample-3',
      fact: 'takes a morning tablet with breakfast',
      category: 'medication',
      sensitive: true,
      status: MemoryStatus.proposed,
      createdAt: DateTime(2026, 11, 19),
    ),
  ];

  List<MemoryFact> get _visible => _sorted(_facts.values);

  @override
  Stream<List<MemoryFact>> watch() async* {
    yield _visible;
    yield* _changes.stream.map((_) => _visible);
  }

  @override
  Future<void> keep(String id) async {
    final f = _facts[id];
    if (f == null) return;
    _facts[id] = MemoryFact(
      id: f.id,
      fact: f.fact,
      category: f.category,
      sensitive: f.sensitive,
      status: MemoryStatus.saved,
      createdAt: f.createdAt,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _facts.remove(id);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    ids.toList().forEach(_facts.remove);
    _changes.add(null);
  }
}

final _previewMemoryProvider = Provider<MemoryRepository>(
  (ref) => InMemoryMemoryRepository(),
);

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  if (ref.watch(previewModeProvider)) return ref.watch(_previewMemoryProvider);
  final auth = ref.watch(authServiceProvider);
  return FirestoreMemoryRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});

final memoryFactsProvider = StreamProvider<List<MemoryFact>>(
  (ref) => ref.watch(memoryRepositoryProvider).watch(),
);
