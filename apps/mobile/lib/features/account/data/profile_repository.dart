import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';

/// Onboarding steps after the account exists (users/{uid}.onboarding_step).
abstract final class ProfileStep {
  /// Create your coach (T-ONB-03b), the first step after sign-up.
  static const avatar = 'avatar';

  /// Choose your coach's voice (T-ONB-03c), after the avatar.
  static const voice = 'voice';

  /// First check-in, then "What would you like to work on?" (T-ONB-03d),
  /// after the Why.
  static const checkin = 'checkin';
  static const focus = 'focus';

  /// "Your 7 days" starter plan (T-ONB-03e), the last onboarding step.
  static const plan = 'plan';
  static const why = 'why';

  /// The 8-driver assessment (T-ASM-01..03, not built yet). Until it exists,
  /// people at this step go to Home.
  static const assessment = 'assessment';
}

/// The parts of users/{uid} the app reads.
class Profile {
  const Profile({
    required this.uid,
    this.displayName,
    this.region,
    this.whyStatement,
    this.onboardingStep,
    this.createdAt,
    this.edSafeMode = false,
    this.focusChoices = const [],
    this.activityLimited,
    this.settings = const {},
  });

  final String uid;
  final String? displayName;
  final String? region;
  final String? whyStatement;
  final String? onboardingStep;

  /// When the account was created (for "Day N" on Home).
  final DateTime? createdAt;

  /// Server-set after a disordered-eating flag (FR-SAF-04); blocks portal
  /// cards and diet content.
  final bool edSafeMode;

  /// "What would you like to work on" ids, main focus first (T-ONB-03d).
  final List<String> focusChoices;

  /// FR-GOL-03: a clinician limit or warning signs; then no movement plans.
  final bool? activityLimited;

  /// Profile settings (T-ONB-03f): coach_name, appearance, quiet_hours,
  /// notification_categories, touchpoints. Raw maps; see the readers below.
  final Map<String, dynamic> settings;

  String? get coachName => settings['coach_name'] as String?;

  static Profile fromData(String uid, Map<String, dynamic> d) => Profile(
    uid: uid,
    displayName: d['display_name'] as String?,
    region: d['region'] as String?,
    whyStatement: d['why_statement'] as String?,
    onboardingStep: d['onboarding_step'] as String?,
    createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    edSafeMode: d['ed_safe_mode'] as bool? ?? false,
    focusChoices: [...?(d['focus_choices'] as List?)?.cast<String>()],
    activityLimited: d['activity_limited'] as bool?,
    settings: {
      for (final k in ProfileSettings.keys)
        if (d[k] != null) k: d[k],
    },
  );
}

/// Settings the app may change on the profile (T-ONB-03f, FR-SET-01),
/// checked by the rules.
abstract final class ProfileSettings {
  static const coachName = 'coach_name';
  static const appearance = 'appearance';
  static const quietHours = 'quiet_hours';
  static const notificationCategories = 'notification_categories';
  static const touchpoints = 'touchpoints';
  static const displayName = 'display_name';

  static const keys = [
    coachName,
    appearance,
    quietHours,
    notificationCategories,
    touchpoints,
  ];
}

/// The users/{uid} root profile (spec 11). Only client-writable fields are
/// sent; the rules reject anything else.
abstract class ProfileRepository {
  Future<Profile?> get(String uid);

  Future<bool> exists(String uid) async => await get(uid) != null;

  /// Live profile, null while it doesn't exist.
  Stream<Profile?> watch(String uid);

  /// Creates the profile. Only allowed with age_confirmed = true (FR-ONB-04).
  Future<void> create(String uid, NewProfile profile);

  /// Saves the personal Why and moves onboarding to [nextStep] (FR-ONB-05).
  Future<void> saveWhy(String uid, String why, {required String nextStep});

  /// Moves onboarding to [step] (FR-ONB-06: resumes there).
  Future<void> setStep(String uid, String step);

  /// Changes settings ([ProfileSettings] keys or display_name).
  Future<void> updateSettings(String uid, Map<String, Object> fields);

  /// Saves the focus choices (1 or 2 ids), the main driver and the FR-GOL-03
  /// answer (null when not asked: no movement focus), then moves onboarding
  /// to [nextStep].
  Future<void> saveFocus(
    String uid, {
    required List<String> choices,
    required String driver,
    required bool? activityLimited,
    required String nextStep,
  });
}

class NewProfile {
  const NewProfile({
    this.displayName,
    this.email,
    this.locale,
    this.region,
    this.onboardingStep = ProfileStep.avatar,
  });

  final String? displayName;
  final String? email;
  final String? locale;

  /// 'IN' or 'US'; null when it couldn't be determined (D-03).
  final String? region;

  /// Next onboarding step once the account exists (FR-ONB-06).
  final String onboardingStep;
}

class FirestoreProfileRepository extends ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<Profile?> get(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists ? Profile.fromData(uid, snap.data()!) : null;
  }

  @override
  Stream<Profile?> watch(String uid) =>
      _doc(uid)
          .snapshots()
          .map((s) => s.exists ? Profile.fromData(uid, s.data()!) : null);

  @override
  Future<void> create(String uid, NewProfile p) async {
    final now = FieldValue.serverTimestamp();
    await _doc(uid).set({
      'display_name': ?p.displayName,
      'email': ?p.email,
      'locale': ?p.locale,
      'region': ?p.region,
      'age_confirmed': true,
      'onboarding_step': p.onboardingStep,
      'created_at': now,
      'updated_at': now,
      'schema_version': 1,
    });
  }

  @override
  Future<void> saveFocus(
    String uid, {
    required List<String> choices,
    required String driver,
    required bool? activityLimited,
    required String nextStep,
  }) => _doc(uid).update({
    'focus_choices': choices,
    'focus_driver': driver,
    'activity_limited': ?activityLimited,
    'onboarding_step': nextStep,
    'updated_at': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> updateSettings(String uid, Map<String, Object> fields) =>
      _doc(uid)
          .update({...fields, 'updated_at': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 3), onTimeout: () {});

  @override
  Future<void> setStep(String uid, String step) => _doc(uid).update({
    'onboarding_step': step,
    'updated_at': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> saveWhy(String uid, String why, {required String nextStep}) =>
      _doc(uid).update({
        'why_statement': why.trim(),
        'onboarding_step': nextStep,
        'updated_at': FieldValue.serverTimestamp(),
      });
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(ref.watch(firestoreProvider)),
);

/// The signed-in person's profile, live. Null when signed out, in preview
/// mode, or before the profile exists.
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  if (ref.watch(previewModeProvider)) return Stream.value(null);
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(uid);
});
