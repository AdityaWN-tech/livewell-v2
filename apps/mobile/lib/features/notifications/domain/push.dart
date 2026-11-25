/// Server push (T-TCH-01, FR-TCH-01/02, D-77): what a push may carry and
/// how a tap on one opens the app. Pure, so it can be tested.
///
/// A push carries only a category and an ID (`data: {category, ref_id}`)
/// with fixed generic words chosen by the server (services/core-api
/// `src/push/copy.ts`). Nothing personal or health-related is ever in it,
/// and the app never shows text it received: in the foreground it shows its
/// own generic words for the category.
library;

import '../../starter_plan/domain/touchpoints.dart';

/// The push categories. The [key] is what the server sends; keep it in step
/// with `PUSH_CATEGORIES` in services/core-api/src/push/copy.ts.
enum PushCategory {
  greeting('greeting'),
  nudge('nudge'),
  reflection('reflection'),
  weekly('weekly'),

  /// The coach being made on the Media Service is ready (T-AVT-08).
  coachReady('coach_ready'),

  /// It couldn't be made.
  coachNotMade('coach_not_made');

  const PushCategory(this.key);

  final String key;

  static PushCategory? fromKey(String? key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// The plan touchpoint whose toggle (Profile > Daily plan) governs it.
  /// The coach notices have no toggle, like their local notice: they answer
  /// the person's own request and need only the notifications consent.
  TouchpointKind? get touchpoint => switch (this) {
    greeting => TouchpointKind.greeting,
    nudge => TouchpointKind.nudge,
    reflection => TouchpointKind.reflection,
    weekly => TouchpointKind.weekly,
    coachReady || coachNotMade => null,
  };
}

/// One push as the app sees it: the category and an optional ID, nothing
/// else (any other field is dropped).
class PushMessage {
  const PushMessage(this.category, {this.refId});

  final PushCategory category;
  final String? refId;

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Reads a push's data. Null for anything that isn't ours.
  static PushMessage? fromData(Map<String, dynamic> data) {
    final c = PushCategory.fromKey(data['category'] as String?);
    if (c == null) return null;
    final ref = data['ref_id'];
    return PushMessage(
      c,
      refId: ref is String && _id.hasMatch(ref) ? ref : null,
    );
  }

  /// The payload a tap hands to Home, the same as a local reminder's: a
  /// touchpoint opens its moment; a coach notice just opens the app.
  String get tapPayload => category.touchpoint?.name ?? category.key;
}

/// What is stored per device at users/{uid}/devices/{installId}: the FCM
/// token, the platform and the IANA time zone (for quiet hours and the
/// person's local day). No name, e-mail, phone or health data.
class DeviceRecord {
  const DeviceRecord({
    required this.token,
    required this.platform,
    required this.timeZone,
  });

  final String token;

  /// 'android' or 'ios'.
  final String platform;
  final String timeZone;
}
