import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart' show todayCheckInProvider;
import '../data/learn_repository.dart';
import '../domain/lesson.dart';
import '../domain/portal.dart';

/// The approved items the app can open (D-57): a lesson without its cards
/// or a session without anything to play is left out, never a dead end.
final lessonsProvider = StreamProvider<List<Lesson>>(
  (ref) => ref
      .watch(learnRepositoryProvider)
      .watchLessons()
      .map(
        (all) => [
          for (final x in all)
            if (x.opens) x,
        ],
      ),
);

/// One item by id, or null (not approved, can't open, or not loaded).
final lessonByIdProvider = Provider.family<Lesson?, String>(
  (ref, id) =>
      ref.watch(lessonsProvider).value?.where((x) => x.id == id).firstOrNull,
);

/// Where the person is in each item, by id.
final contentProgressProvider = StreamProvider<Map<String, ContentProgress>>(
  (ref) => ref.watch(learnRepositoryProvider).watchProgress(),
);

final portalOffersProvider = StreamProvider<List<PortalOffer>>(
  (ref) => ref.watch(learnRepositoryProvider).watchOffers(),
);

final portalEventsProvider = StreamProvider<List<PortalEventRecord>>(
  (ref) => ref.watch(learnRepositoryProvider).watchEvents(),
);

/// Whether we know there was no safety event in the last 72 hours.
/// Safety events aren't recorded yet (D-22), so the app can't know, and
/// unknown counts as not clear: no portal card for real accounts.
/// TODO(D-22): read the last safety event time once reportSafetyEvent exists.
final safetyClearProvider = Provider<bool>(
  (ref) => ref.watch(previewModeProvider),
);

/// The portal consent (FR-ONB-03 "portal linking").
final portalConsentProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(consentRepositoryProvider)
      .watchRecords()
      .map((r) => isGranted(currentConsents(r), ConsentType.portalLinking)),
);

/// The one portal card to show on Learn, or null (spec 13.3 step 1).
final portalCardProvider = Provider<PortalOffer?>((ref) {
  final offers = ref.watch(portalOffersProvider).value;
  final events = ref.watch(portalEventsProvider).value;
  // Not loaded yet: no card rather than a card that may be wrong.
  if (offers == null || offers.isEmpty || events == null) return null;
  final now = ref.watch(clockProvider)();
  final preview = ref.watch(previewModeProvider);
  final profile = ref.watch(currentProfileProvider).value;
  return PortalEligibility.pick(
    offers,
    PortalContext(
      now: now,
      // The dev preview shows the card so the design can be reviewed.
      flagOn: preview || ref.watch(featureFlagsProvider).portalCards,
      consentGranted:
          preview || (ref.watch(portalConsentProvider).value ?? false),
      gentleDay: ref.watch(todayCheckInProvider).value?.gentleDay ?? false,
      safetyClear: ref.watch(safetyClearProvider),
      edSafeMode: profile?.edSafeMode ?? false,
      accountCreated: preview
          ? now.subtract(const Duration(days: PreviewSamples.day))
          : profile?.createdAt,
      events: events,
    ),
  );
});

/// Where the person stopped, or null: the item opened most recently that
/// is started and not finished.
final continueLessonProvider = Provider<LessonProgress?>((ref) {
  final all = ref.watch(lessonsProvider).value;
  final progress = ref.watch(contentProgressProvider).value;
  if (all == null || progress == null) return null;
  final open = [
    for (final p in progress.values)
      if (!p.completed && p.progress > 0) p,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  for (final p in open) {
    final lesson = all.where((x) => x.id == p.itemId).firstOrNull;
    if (lesson != null) {
      return LessonProgress(lesson: lesson, progress: p.progress);
    }
  }
  return null;
});
