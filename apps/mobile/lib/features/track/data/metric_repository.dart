import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/metric_point.dart';

/// Recorded measures, one document each (users/{uid}/metrics/{id};
/// T-GOL-02, D-72). Points are added or deleted, never edited.
abstract class MetricRepository {
  /// A new document id (made on the phone, so an offline add is idempotent).
  String newId();

  /// Points measured on or after [from], oldest first.
  Stream<List<MetricPoint>> watchSince(DateTime from);

  /// Saves [point]. Works offline: the write is queued.
  Future<void> add(MetricPoint point);

  Future<void> delete(String id);
}

/// Firestore implementation, offline through Firestore's persistence.
/// TODO(T-FND-08): move to the encrypted local database with its sync queue.
class FirestoreMetricRepository implements MetricRepository {
  FirestoreMetricRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  static const serverWait = Duration(seconds: 3);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid()).collection('metrics');

  @override
  String newId() => _col.doc().id;

  @override
  Stream<List<MetricPoint>> watchSince(DateTime from) => _col
      .where('measured_at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('measured_at')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (d.data()['measured_at'] case final Timestamp at)
              ?MetricPoint.fromData(d.id, d.data(), at.toDate()),
        ],
      );

  @override
  Future<void> add(MetricPoint p) async {
    await _col
        .doc(p.id)
        .set({
          'kind': p.kind.id,
          'source': p.source.id,
          'measured_at': Timestamp.fromDate(p.measuredAt),
          ...p.valueFields(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'schema_version': 1,
        })
        .timeout(serverWait, onTimeout: () {});
  }

  @override
  Future<void> delete(String id) =>
      _col.doc(id).delete().timeout(serverWait, onTimeout: () {});
}

/// Kept in memory: the dev preview and tests (nothing is saved).
class InMemoryMetricRepository implements MetricRepository {
  final points = <String, MetricPoint>{};
  final _changes = StreamController<void>.broadcast();
  final _random = Random();

  @override
  String newId() => [
    for (var i = 0; i < 20; i++)
      'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
  ].join();

  List<MetricPoint> _since(DateTime from) =>
      points.values.where((p) => !p.measuredAt.isBefore(from)).toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  @override
  Stream<List<MetricPoint>> watchSince(DateTime from) async* {
    yield _since(from);
    yield* _changes.stream.map((_) => _since(from));
  }

  @override
  Future<void> add(MetricPoint p) async {
    points[p.id] = p;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    points.remove(id);
    _changes.add(null);
  }
}

final _previewMetricsProvider = Provider<MetricRepository>(
  (ref) => InMemoryMetricRepository(),
);

final metricRepositoryProvider = Provider<MetricRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  // Dev preview or nobody signed in: nothing to read or save.
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return ref.watch(_previewMetricsProvider);
  }
  return FirestoreMetricRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
