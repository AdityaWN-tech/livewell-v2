import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../focus/domain/focus.dart';
import '../domain/starter_plan.dart';
import '../domain/touchpoints.dart';

/// The approved plan templates (copies of content/plan/templates).
class PlanTemplates {
  const PlanTemplates({required this.byFocus, required this.limited});

  final Map<FocusArea, PlanTemplate> byFocus;

  /// No-exercise days, used when activity is limited (FR-GOL-03).
  final PlanTemplate limited;

  Iterable<PlanTemplate> get all => [...byFocus.values, limited];
}

final planTemplatesProvider = FutureProvider<PlanTemplates>((ref) async {
  Future<PlanTemplate> load(String name) async => PlanTemplate.parse(
    await rootBundle.loadString(
      'assets/plan/templates/$name.json',
      cache: false,
    ),
  );
  return PlanTemplates(
    byFocus: {for (final f in FocusArea.values) f: await load(f.id)},
    limited: await load('limited'),
  );
});

/// users/{uid}/daily_plans/{date} for the starter plan, and the touchpoint
/// times on users/{uid}.
abstract class PlanRepository {
  Future<void> save(StarterPlan plan, TouchpointTimes times);
  Future<void> saveTimes(TouchpointTimes times);
  Future<TouchpointTimes> loadTimes();

  /// Today's planned step, live (Home).
  Stream<PlanDay?> watchDay(String date);

  /// The plan's dates from [from] on (for rescheduling reminders).
  Future<List<String>> datesFrom(String from);
}

class FirestorePlanRepository implements PlanRepository {
  FirestorePlanRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid());
  CollectionReference<Map<String, dynamic>> get _plans =>
      _user.collection('daily_plans');

  static const _wait = Duration(seconds: 3);

  @override
  Future<void> save(StarterPlan plan, TouchpointTimes times) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    final supporting = [
      for (final s in plan.supporting)
        {'id': s.id, 'title': s.title, 'anchor': s.anchor},
    ];
    for (final d in plan.days) {
      batch.set(_plans.doc(d.date), {
        'next_step': {
          'title': d.title,
          'reason': d.reason,
          'anchor': d.anchor,
          'minutes': d.minutes,
          'smaller_title': ?d.smallerTitle,
          'smaller_minutes': ?d.smallerMinutes,
          'focus': d.focus.id,
        },
        'alternatives': const <Object>[],
        'supporting': supporting,
        'mode': d.gentle ? 'gentle' : 'normal',
        'day_number': d.dayNumber,
        'source': 'starter_v1',
        'template_version': 1,
        'created_at': now,
        'updated_at': now,
        'schema_version': 1,
      });
    }
    batch.update(_user, {'touchpoints': times.toMap(), 'updated_at': now});
    // Offline: queued and synced later.
    await batch.commit().timeout(_wait, onTimeout: () {});
  }

  @override
  Future<void> saveTimes(TouchpointTimes times) => _user
      .update({
        'touchpoints': times.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      })
      .timeout(_wait, onTimeout: () {});

  @override
  Future<TouchpointTimes> loadTimes() async {
    try {
      final snap = await _user.get().timeout(_wait);
      return TouchpointTimes.fromMap(
        snap.data()?['touchpoints'] as Map<String, dynamic>?,
      );
    } catch (_) {
      return const TouchpointTimes();
    }
  }

  @override
  Stream<PlanDay?> watchDay(String date) => _plans
      .doc(date)
      .snapshots()
      .map((s) => s.data() == null ? null : _day(date, s.data()!));

  static PlanDay? _day(String date, Map<String, dynamic> d) {
    final step = d['next_step'];
    if (step is! Map<String, dynamic>) return null;
    return PlanDay(
      date: date,
      dayNumber: d['day_number'] as int? ?? 1,
      focus:
          FocusArea.byId(step['focus'] as String? ?? '') ?? FocusArea.moveMore,
      title: step['title'] as String? ?? '',
      reason: step['reason'] as String? ?? '',
      anchor: step['anchor'] as String? ?? '',
      minutes: step['minutes'] as int? ?? TimeSizes.fallback,
      smallerTitle: step['smaller_title'] as String?,
      smallerMinutes: step['smaller_minutes'] as int?,
      gentle: d['mode'] == 'gentle',
    );
  }

  @override
  Future<List<String>> datesFrom(String from) async {
    final snap = await _plans
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
        .get()
        .timeout(_wait);
    return [for (final d in snap.docs) d.id];
  }
}

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  return FirestorePlanRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
