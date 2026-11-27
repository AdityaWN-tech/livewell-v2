import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/assessment.dart';

/// The check's questions, the live driver names and the person's results.
abstract class AssessmentRepository {
  /// Approved questions (assessment_questions).
  Stream<List<AssessmentQuestion>> watchQuestions();

  /// The newest approved driver names (driver_sets), or null.
  Stream<List<String>?> watchDriverLabels();

  /// The person's latest driver scores, or null before the first check.
  Stream<Map<String, double>?> watchLatestScores();

  /// Saves a finished check (users/{uid}/assessments).
  Future<void> save({
    required String bankVersion,
    required Map<String, int> answers,
    required Map<String, double> scores,
  });
}

class FirestoreAssessmentRepository implements AssessmentRepository {
  FirestoreAssessmentRepository(this._db, this._uid);
  final FirebaseFirestore _db;
  final String? Function() _uid;

  @override
  Stream<List<AssessmentQuestion>> watchQuestions() => _db
      .collection('assessment_questions')
      // Must match the rules (approved only).
      .where('review_status', isEqualTo: 'approved')
      .snapshots()
      .map(
        (q) => askingOrder([
          for (final d in q.docs)
            AssessmentQuestion(
              id: d.id,
              driverId: d.data()['driver_id'] as String? ?? 'driver_1',
              text: d.data()['text'] as String? ?? '',
              order: (d.data()['order'] as num?)?.toInt() ?? 0,
              version: (d.data()['version'] as num?)?.toInt() ?? 1,
            ),
        ]),
      );

  @override
  Stream<List<String>?> watchDriverLabels() => _db
      .collection('driver_sets')
      .where('review_status', isEqualTo: 'approved')
      .snapshots()
      .map((q) {
        if (q.docs.isEmpty) return null;
        final newest = [...q.docs]
          ..sort(
            (a, b) => ((b.data()['version'] as num?) ?? 0).compareTo(
              (a.data()['version'] as num?) ?? 0,
            ),
          );
        final labels = [
          for (final x in (newest.first.data()['drivers'] as List?) ?? const [])
            if (x is Map) (x['label'] as String? ?? ''),
        ];
        return labels.length == 8 ? labels : null;
      });

  @override
  Stream<Map<String, double>?> watchLatestScores() {
    final uid = _uid();
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users/$uid/assessments')
        .orderBy('completed_at', descending: true)
        .limit(1)
        .snapshots()
        .map((q) {
          if (q.docs.isEmpty) return null;
          final m = q.docs.first.data()['driver_scores'];
          if (m is! Map) return null;
          return {
            for (final e in m.entries)
              if (e.value is num) '${e.key}': (e.value as num).toDouble(),
          };
        });
  }

  @override
  Future<void> save({
    required String bankVersion,
    required Map<String, int> answers,
    required Map<String, double> scores,
  }) async {
    final uid = _uid();
    if (uid == null) return;
    final now = FieldValue.serverTimestamp();
    await _db.collection('users/$uid/assessments').add({
      'bank_version': bankVersion,
      'answers': [
        for (final e in answers.entries)
          {'question_id': e.key, 'value': e.value},
      ],
      'driver_scores': scores,
      'red_flags': <String>[],
      'completed_at': now,
      'created_at': now,
      'updated_at': now,
      'schema_version': 1,
    });
  }
}

/// In memory: the dev preview and tests.
class InMemoryAssessmentRepository implements AssessmentRepository {
  List<AssessmentQuestion> questions = const [];
  List<String>? labels;
  Map<String, double>? latest;
  final saved = <Map<String, int>>[];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<AssessmentQuestion>> watchQuestions() =>
      Stream.value(askingOrder(questions));

  @override
  Stream<List<String>?> watchDriverLabels() => Stream.value(labels);

  @override
  Stream<Map<String, double>?> watchLatestScores() async* {
    yield latest;
    yield* _changes.stream.map((_) => latest);
  }

  @override
  Future<void> save({
    required String bankVersion,
    required Map<String, int> answers,
    required Map<String, double> scores,
  }) async {
    saved.add(answers);
    latest = scores;
    _changes.add(null);
  }
}

final _previewAssessmentProvider = Provider<AssessmentRepository>(
  (ref) => InMemoryAssessmentRepository(),
);

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  if (ref.watch(previewModeProvider)) {
    return ref.watch(_previewAssessmentProvider);
  }
  final auth = ref.watch(authServiceProvider);
  return FirestoreAssessmentRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser?.uid,
  );
});
