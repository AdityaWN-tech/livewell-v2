import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';

/// The users/{uid} root profile (spec 11). Only client-writable fields are
/// sent; the rules reject anything else.
abstract class ProfileRepository {
  Future<bool> exists(String uid);

  /// Creates the profile. Only allowed with age_confirmed = true (FR-ONB-04).
  Future<void> create(String uid, NewProfile profile);
}

class NewProfile {
  const NewProfile({
    this.displayName,
    this.email,
    this.locale,
    this.region,
    this.onboardingStep = 'why',
  });

  final String? displayName;
  final String? email;
  final String? locale;

  /// 'IN' or 'US'; null when it couldn't be determined (D-03).
  final String? region;

  /// Next onboarding step once the account exists (FR-ONB-06).
  final String onboardingStep;
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<bool> exists(String uid) async =>
      (await _db.collection('users').doc(uid).get()).exists;

  @override
  Future<void> create(String uid, NewProfile p) async {
    final now = FieldValue.serverTimestamp();
    await _db.collection('users').doc(uid).set({
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
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(ref.watch(firestoreProvider)),
);
