import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/travel_content.dart';
import '../domain/trip.dart';

/// The bundled travel content (copy of content/travel/travel.json).
final travelContentProvider = FutureProvider<TravelContent>(
  (ref) async => TravelContent.parse(
    await rootBundle.loadString('assets/travel/travel.json', cache: false),
  ),
);

/// users/{uid}/trips (FR-TRV-01, D-86). Past trips are kept so the streak
/// stays protected for their days.
abstract class TripRepository {
  /// Every trip, live.
  Stream<List<Trip>> watch();

  /// Creates or changes a trip. Works offline (the write is queued).
  Future<void> save(Trip trip);

  /// Removes a trip that hasn't started (cancelled plans).
  Future<void> delete(String id);
}

class FirestoreTripRepository implements TripRepository {
  FirestoreTripRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  static const schemaVersion = 1;
  static const serverWait = Duration(seconds: 3);

  CollectionReference<Map<String, dynamic>> get _trips =>
      _db.collection('users').doc(_uid()).collection('trips');

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

  @override
  Stream<List<Trip>> watch() => _trips.snapshots().map(
    (s) => [
      for (final d in s.docs)
        if (_valid(d.data())) Trip.fromData(d.data()),
    ],
  );

  static bool _valid(Map<String, dynamic> d) =>
      d['start'] is String &&
      d['end'] is String &&
      d['tz'] is String &&
      d['home_tz'] is String;

  @override
  Future<void> save(Trip trip) async {
    final ref = _trips.doc(trip.id);
    final fields = {
      ...trip.toData(),
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': schemaVersion,
    };
    // created_at only on the first write (the rules keep it fixed).
    final write = await _exists(ref)
        ? ref.set(fields, SetOptions(merge: true))
        : ref.set({...fields, 'created_at': FieldValue.serverTimestamp()});
    // Offline, the write stays queued and the local copy updates at once.
    await write.timeout(serverWait, onTimeout: () {});
  }

  @override
  Future<void> delete(String id) async {
    await _trips.doc(id).delete().timeout(serverWait, onTimeout: () {});
  }
}

/// Nobody signed in, or the dev preview: trips live on this phone only.
class InMemoryTripRepository implements TripRepository {
  final _trips = <String, Trip>{};
  final _changes = StreamController<List<Trip>>.broadcast();

  List<Trip> get trips => _trips.values.toList();

  @override
  Stream<List<Trip>> watch() async* {
    yield trips;
    yield* _changes.stream;
  }

  @override
  Future<void> save(Trip trip) async {
    _trips[trip.id] = trip;
    _changes.add(trips);
  }

  @override
  Future<void> delete(String id) async {
    _trips.remove(id);
    _changes.add(trips);
  }
}

final _localTripsProvider = Provider<InMemoryTripRepository>(
  (ref) => InMemoryTripRepository(),
);

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return ref.watch(_localTripsProvider);
  }
  return FirestoreTripRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
