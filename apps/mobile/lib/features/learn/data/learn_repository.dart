import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../domain/breathing.dart';
import '../domain/course.dart';
import '../domain/lesson.dart';
import '../domain/portal.dart';

/// Lessons, portal offers and the person's portal events.
abstract class LearnRepository {
  /// Approved lessons and audio sessions (content_items).
  Stream<List<Lesson>> watchLessons();

  /// Courses this person may see (D-113): approved, for everyone or for
  /// their sign-in email.
  Stream<List<Course>> watchCourses();

  /// Where the person is in each item (content_progress), by item id.
  Stream<Map<String, ContentProgress>> watchProgress();

  /// Saves where the person is in [itemId] (0..1). Offline it is kept and
  /// synced later.
  Future<void> saveProgress(
    String itemId, {
    required double progress,
    required bool completed,
  });

  /// Active and approved portal offers (portal_offers).
  Stream<List<PortalOffer>> watchOffers();

  /// The person's portal events from the last [days] days.
  Stream<List<PortalEventRecord>> watchEvents({int days = 14});

  /// Appends card_shown, clicked or dismissed on [surface] (`learn` or
  /// `lesson_end`). Only ids, never health data.
  Future<void> logEvent(
    String event,
    String offerId, {
    String? clickId,
    String surface = 'learn',
  });
}

class FirestoreLearnRepository implements LearnRepository {
  FirestoreLearnRepository(this._db, this._uid, [String? Function()? email])
    : _email = email ?? (() => null);

  final FirebaseFirestore _db;
  final String Function() _uid;
  final String? Function() _email;

  static List<Course> _courses(QuerySnapshot<Map<String, dynamic>> q) => [
    for (final d in q.docs)
      Course(
        id: d.id,
        title: d.data()['title'] as String? ?? '',
        category: d.data()['category'] as String? ?? '',
        summary: d.data()['summary'] as String?,
        lessonIds: [
          for (final x in (d.data()['lesson_ids'] as List?) ?? const [])
            if (x is String) x,
        ],
      ),
  ];

  /// Two queries, each matching the rules exactly: courses for everyone,
  /// and courses that list this person's email.
  @override
  Stream<List<Course>> watchCourses() {
    final courses = _db.collection('courses');
    final forAll = courses
        .where('review_status', isEqualTo: 'approved')
        .where('visibility', isEqualTo: 'all')
        .snapshots()
        .map(_courses);
    final email = _email()?.trim().toLowerCase();
    if (email == null || email.isEmpty) return forAll;
    final forMe = courses
        .where('review_status', isEqualTo: 'approved')
        .where('allowed_emails', arrayContains: email)
        .snapshots()
        .map(_courses);
    var a = const <Course>[];
    var b = const <Course>[];
    final out = StreamController<List<Course>>();
    StreamSubscription<List<Course>>? sa;
    StreamSubscription<List<Course>>? sb;
    void emit() => out.add(
      {
        for (final c in [...a, ...b]) c.id: c,
      }.values.toList()..sort((x, y) => x.title.compareTo(y.title)),
    );
    out.onListen = () {
      sa = forAll.listen((v) {
        a = v;
        emit();
      }, onError: out.addError);
      sb = forMe.listen((v) {
        b = v;
        emit();
      }, onError: (_) {});
    };
    out.onCancel = () async {
      await sa?.cancel();
      await sb?.cancel();
    };
    return out.stream;
  }

  @override
  Stream<List<Lesson>> watchLessons() => _db
      .collection('content_items')
      // Must match the rules (approved only), or the query is rejected.
      .where('review_status', isEqualTo: 'approved')
      .where('type', whereIn: ['lesson', 'audio'])
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            Lesson(
              id: d.id,
              category: d.data()['category'] as String? ?? '',
              title: d.data()['title'] as String? ?? '',
              summary: d.data()['summary'] as String?,
              readMinutes: (d.data()['read_minutes'] as num?)?.toInt(),
              kind: d.data()['type'] == 'audio'
                  ? LessonKind.audio
                  : LessonKind.lesson,
              art: d.data()['art_id'] as String?,
              cards: [
                for (final c in (d.data()['cards'] as List?) ?? const [])
                  if (c is String && c.trim().isNotEmpty) c.trim(),
              ],
              microhabit: _microhabit(d.data()['microhabit']),
              breathing: BreathingPattern.byId(
                d.data()['breathing'] as String?,
              ),
              version: (d.data()['version'] as num?)?.toInt() ?? 1,
              portalOfferId: _nonEmpty(d.data()['portal_offer_id']),
            ),
        ],
      );

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  static LessonMicrohabit? _microhabit(Object? m) {
    if (m is! Map) return null;
    final title = m['title'];
    if (title is! String || title.trim().isEmpty) return null;
    return LessonMicrohabit(
      title: title.trim(),
      minutes: (m['minutes'] as num?)?.toInt(),
    );
  }

  CollectionReference<Map<String, dynamic>> get _progress =>
      _db.collection('users').doc(_uid()).collection('content_progress');

  @override
  Stream<Map<String, ContentProgress>> watchProgress() =>
      _progress.snapshots().map(
        (s) => {
          for (final d in s.docs)
            d.id: ContentProgress(
              itemId: d.id,
              progress: ((d.data()['progress'] as num?)?.toDouble() ?? 0).clamp(
                0,
                1,
              ),
              completed: d.data()['completed'] as bool? ?? false,
              // Pending server time: treat as now.
              updatedAt:
                  (d.data()['updated_at'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            ),
        },
      );

  @override
  Future<void> saveProgress(
    String itemId, {
    required double progress,
    required bool completed,
  }) async {
    final ref = _progress.doc(itemId);
    final fields = {
      'progress': progress.clamp(0, 1).toDouble(),
      'completed': completed,
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': 1,
    };
    // created_at only on the first write, so a second (offline) save never
    // changes it (the rules require that).
    final write = await _exists(ref)
        ? ref.set(fields, SetOptions(merge: true))
        : ref.set({...fields, 'created_at': FieldValue.serverTimestamp()});
    // Offline, the write stays queued and the local copy updates at once.
    await write.timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get().timeout(const Duration(seconds: 3))).exists;
    } catch (_) {
      try {
        return (await ref.get(const GetOptions(source: Source.cache))).exists;
      } on FirebaseException {
        return false;
      }
    }
  }

  @override
  Stream<List<PortalOffer>> watchOffers() => _db
      .collection('portal_offers')
      .where('active', isEqualTo: true)
      .where('review_status', isEqualTo: 'approved')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            PortalOffer(
              id: d.id,
              title: d.data()['title'] as String? ?? '',
              description: d.data()['description'] as String?,
              url: d.data()['url'] as String? ?? '',
              offerType: d.data()['offer_type'] as String? ?? 'course',
              priceDisplay: d.data()['price_display'] as String?,
              driverTags: [
                ...?(d.data()['driver_tags'] as List?)?.cast<String>(),
              ],
              topicTags: [
                ...?(d.data()['topic_tags'] as List?)?.cast<String>(),
              ],
            ),
        ],
      );

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('users').doc(_uid()).collection('portal_events');

  @override
  Stream<List<PortalEventRecord>> watchEvents({int days = 14}) => _events
      .where(
        'created_at',
        isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(Duration(days: days)),
        ),
      )
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            PortalEventRecord(
              event: d.data()['event'] as String,
              offerId: d.data()['offer_id'] as String,
              // Pending server time: treat as now.
              at:
                  (d.data()['created_at'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            ),
        ],
      );

  @override
  Future<void> logEvent(
    String event,
    String offerId, {
    String? clickId,
    String surface = 'learn',
  }) {
    final now = FieldValue.serverTimestamp();
    // Not awaited past the local write: offline it syncs later.
    return _events
        .add({
          'event': event,
          'offer_id': offerId,
          'surface': surface,
          'click_id': ?clickId,
          'created_at': now,
          'updated_at': now,
          'schema_version': 1,
        })
        .timeout(const Duration(seconds: 3), onTimeout: () => _events.doc())
        .then((_) {});
  }
}

/// Dev preview: sample lessons and offer, events in memory (nothing saved).
class PreviewLearnRepository implements LearnRepository {
  final _events = <PortalEventRecord>[];
  final _changes = StreamController<void>.broadcast();

  /// The sample "Pick up where you left off".
  final _progress = <String, ContentProgress>{
    PreviewSamples.lessons[PreviewSamples.continueIndex].id: ContentProgress(
      itemId: PreviewSamples.lessons[PreviewSamples.continueIndex].id,
      progress: PreviewSamples.continueProgress,
      completed: false,
      updatedAt: DateTime(2026),
    ),
  };
  final _progressChanges = StreamController<void>.broadcast();

  @override
  Stream<List<Lesson>> watchLessons() => Stream.value(PreviewSamples.lessons);

  @override
  Stream<List<Course>> watchCourses() => Stream.value(const []);

  @override
  Stream<Map<String, ContentProgress>> watchProgress() async* {
    yield Map.of(_progress);
    yield* _progressChanges.stream.map((_) => Map.of(_progress));
  }

  @override
  Future<void> saveProgress(
    String itemId, {
    required double progress,
    required bool completed,
  }) async {
    _progress[itemId] = ContentProgress(
      itemId: itemId,
      progress: progress,
      completed: completed,
      updatedAt: DateTime.now(),
    );
    _progressChanges.add(null);
  }

  @override
  Stream<List<PortalOffer>> watchOffers() =>
      Stream.value([PreviewSamples.offer]);

  @override
  Stream<List<PortalEventRecord>> watchEvents({int days = 14}) async* {
    yield List.of(_events);
    yield* _changes.stream.map((_) => List.of(_events));
  }

  @override
  Future<void> logEvent(
    String event,
    String offerId, {
    String? clickId,
    String surface = 'learn',
  }) async {
    _events.add(
      PortalEventRecord(event: event, offerId: offerId, at: DateTime.now()),
    );
    _changes.add(null);
  }
}

final _previewLearnProvider = Provider<LearnRepository>(
  (ref) => PreviewLearnRepository(),
);

final learnRepositoryProvider = Provider<LearnRepository>((ref) {
  if (ref.watch(previewModeProvider)) return ref.watch(_previewLearnProvider);
  final auth = ref.watch(authServiceProvider);
  return FirestoreLearnRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
    () => auth.currentUser?.email,
  );
});

/// Opens portal links in the in-app browser, so portal login cookies persist
/// (spec 13.2).
abstract class PortalBrowser {
  Future<bool> open(Uri url);
}

class InAppPortalBrowser implements PortalBrowser {
  @override
  Future<bool> open(Uri url) =>
      launchUrl(url, mode: LaunchMode.inAppBrowserView);
}

final portalBrowserProvider = Provider<PortalBrowser>(
  (ref) => InAppPortalBrowser(),
);
