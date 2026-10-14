import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consent/data/consent_repository.dart';
import '../../features/consent/domain/consent.dart';

/// Product analytics (spec 12.2), deliberately narrow: one typed method per
/// event, taking only ids, counts and durations. There is no way to pass a
/// mood, a score or any free text (AGENTS.md, Sensitive values; NFR-10).
abstract class Analytics {
  /// `checkin_completed {surface: "app", duration_s, steps_answered}`.
  Future<void> checkinCompleted({
    required int durationSeconds,
    required int stepsAnswered,
  });
}

/// Firebase Analytics, only with the analytics consent (FR-ONB-03).
/// Automatic collection is off in the Android manifest and iOS Info.plist,
/// and is switched on only once the user has granted the consent.
class ConsentedFirebaseAnalytics implements Analytics {
  ConsentedFirebaseAnalytics(this._consents);

  final ConsentRepository _consents;

  Future<FirebaseAnalytics?> _allowed() async {
    if (Firebase.apps.isEmpty) return null;
    final granted = isGranted(
      currentConsents(await _consents.watchRecords().first),
      ConsentType.analytics,
    );
    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(granted);
    return granted ? analytics : null;
  }

  @override
  Future<void> checkinCompleted({
    required int durationSeconds,
    required int stepsAnswered,
  }) async {
    try {
      final analytics = await _allowed();
      await analytics?.logEvent(
        name: 'checkin_completed',
        parameters: {
          'surface': 'app',
          'duration_s': durationSeconds,
          'steps_answered': stepsAnswered,
        },
      );
    } catch (_) {
      // Analytics must never break the app.
    }
  }
}

final analyticsProvider = Provider<Analytics>(
  (ref) => ConsentedFirebaseAnalytics(ref.watch(consentRepositoryProvider)),
);
