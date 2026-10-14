import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../domain/lesson.dart';
import '../domain/portal.dart';

/// Lessons, portal offers and the person's portal events.
abstract class LearnRepository {
  /// Approved lessons (content_items).
  Stream<List<Lesson>> watchLessons();

  /// Active and approved portal offers (portal_offers).
  Stream<List<PortalOffer>> watchOffers();

  /// The person's portal events from the last [days] days.
  Stream<List<PortalEventRecord>> watchEvents({int days = 14});

  /// Appends card_shown, clicked or dismissed. Only ids, never health data.
  Future<void> logEvent(String event, String offerId, {String? clickId});
}

class FirestoreLearnRepository implements LearnRepository {
  FirestoreLearnRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  @override
  Stream<List<Lesson>> watchLessons() => _db
      .collection('content_items')
      // Must match the rules (approved only), or the query is rejected.
      .where('review_status', isEqualTo: 'approved')
      .where('type', isEqualTo: 'lesson')
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
            ),
        ],
      );

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
  Future<void> logEvent(String event, String offerId, {String? clickId}) {
    final now = FieldValue.serverTimestamp();
    // Not awaited past the local write: offline it syncs later.
    return _events
        .add({
          'event': event,
          'offer_id': offerId,
          'surface': 'learn',
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

  @override
  Stream<List<Lesson>> watchLessons() => Stream.value(PreviewSamples.lessons);

  @override
  Stream<List<PortalOffer>> watchOffers() =>
      Stream.value([PreviewSamples.offer]);

  @override
  Stream<List<PortalEventRecord>> watchEvents({int days = 14}) async* {
    yield List.of(_events);
    yield* _changes.stream.map((_) => List.of(_events));
  }

  @override
  Future<void> logEvent(String event, String offerId, {String? clickId}) async {
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
