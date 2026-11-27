import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/content.dart';

/// Lessons and courses (D-113/D-114). Free plan: the console writes
/// Firestore directly and the rules enforce the flow (author submits, a
/// different admin approves; editing a live item makes a new version).
abstract class ContentRepository {
  Stream<List<LessonDoc>> lessons();
  Stream<List<CourseDoc>> courses();

  /// Creates a draft (returns its id) or saves the words of an editable one.
  Future<String> saveLesson(LessonDoc l, {required String uid});
  Future<String> saveCourse(CourseDoc c, {required String uid});

  /// draft/rejected -> pending.
  Future<void> submit(String collection, String id);

  /// pending -> approved / rejected, by an admin who isn't the author.
  Future<void> review(
    String collection,
    String id, {
    required bool approve,
    required String uid,
  });

  /// approved -> draft (next version), so it can be changed.
  Future<void> reopen(String collection, String id, int version);

  /// approved -> retired (no longer shown).
  Future<void> retire(String collection, String id);
}

const lessonsCollection = 'content_items';
const coursesCollection = 'courses';

class FirestoreContentRepository implements ContentRepository {
  FirestoreContentRepository(this._db);
  final FirebaseFirestore _db;

  static List<String> _strings(Object? v) => [
    for (final x in (v as List?) ?? const [])
      if (x is String) x,
  ];

  @override
  Stream<List<LessonDoc>> lessons() => _db
      .collection(lessonsCollection)
      .where('type', whereIn: ['lesson', 'audio'])
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            LessonDoc(
              id: d.id,
              audio: d['type'] == 'audio',
              title: d.data()['title'] as String? ?? '',
              category: d.data()['category'] as String? ?? '',
              summary: d.data()['summary'] as String? ?? '',
              cards: _strings(d.data()['cards']),
              microhabitTitle:
                  (d.data()['microhabit'] as Map?)?['title'] as String? ?? '',
              microhabitMinutes:
                  ((d.data()['microhabit'] as Map?)?['minutes'] as num?)
                      ?.toInt(),
              readMinutes: (d.data()['read_minutes'] as num?)?.toInt(),
              breathing: d.data()['breathing'] as String?,
              state: ReviewState.of(d.data()['review_status']),
              authorUid: d.data()['author_uid'] as String? ?? '',
              reviewedBy: d.data()['reviewed_by'] as String?,
              version: (d.data()['version'] as num?)?.toInt() ?? 1,
            ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      );

  @override
  Stream<List<CourseDoc>> courses() => _db
      .collection(coursesCollection)
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            CourseDoc(
              id: d.id,
              title: d.data()['title'] as String? ?? '',
              category: d.data()['category'] as String? ?? '',
              summary: d.data()['summary'] as String? ?? '',
              lessonIds: _strings(d.data()['lesson_ids']),
              visibility: d.data()['visibility'] == 'selected'
                  ? CourseVisibility.selected
                  : CourseVisibility.all,
              allowedEmails: _strings(d.data()['allowed_emails']),
              state: ReviewState.of(d.data()['review_status']),
              authorUid: d.data()['author_uid'] as String? ?? '',
              reviewedBy: d.data()['reviewed_by'] as String?,
              version: (d.data()['version'] as num?)?.toInt() ?? 1,
            ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      );

  Future<String> _save(
    String collection,
    String? id,
    Map<String, Object> fields,
    String uid,
  ) async {
    final now = FieldValue.serverTimestamp();
    if (id == null) {
      final ref = _db.collection(collection).doc();
      await ref.set({
        ...fields,
        'review_status': 'draft',
        'author_uid': uid,
        'version': 1,
        'created_at': now,
        'updated_at': now,
      });
      return ref.id;
    }
    final ref = _db.collection(collection).doc(id);
    // Words only; optional fields left out are removed.
    final current = (await ref.get()).data() ?? const {};
    const optional = ['summary', 'microhabit', 'read_minutes', 'breathing'];
    await ref.update({
      ...fields,
      for (final k in optional)
        if (current.containsKey(k) && !fields.containsKey(k))
          k: FieldValue.delete(),
      'updated_at': now,
    });
    return id;
  }

  @override
  Future<String> saveLesson(LessonDoc l, {required String uid}) =>
      _save(lessonsCollection, l.id, l.contentFields(), uid);

  @override
  Future<String> saveCourse(CourseDoc c, {required String uid}) =>
      _save(coursesCollection, c.id, c.contentFields(), uid);

  @override
  Future<void> submit(String collection, String id) =>
      _db.collection(collection).doc(id).update({
        'review_status': 'pending',
        'updated_at': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> review(
    String collection,
    String id, {
    required bool approve,
    required String uid,
  }) => _db.collection(collection).doc(id).update({
    'review_status': approve ? 'approved' : 'rejected',
    'reviewed_by': uid,
    'reviewed_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> reopen(String collection, String id, int version) =>
      _db.collection(collection).doc(id).update({
        'review_status': 'draft',
        'version': version + 1,
        'updated_at': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> retire(String collection, String id) =>
      _db.collection(collection).doc(id).update({
        'review_status': 'retired',
        'updated_at': FieldValue.serverTimestamp(),
      });
}

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => throw UnimplementedError('contentRepositoryProvider not overridden'),
);

final lessonsProvider = StreamProvider<List<LessonDoc>>(
  (ref) => ref.watch(contentRepositoryProvider).lessons(),
);
final coursesProvider = StreamProvider<List<CourseDoc>>(
  (ref) => ref.watch(contentRepositoryProvider).courses(),
);
