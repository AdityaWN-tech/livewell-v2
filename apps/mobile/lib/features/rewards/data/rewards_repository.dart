import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../domain/reward_rules.dart';

/// users/{uid}/rewards/current (`earned`: badge id -> local date earned;
/// `celebration`: the chosen Done celebration) and
/// users/{uid}/challenges/{monday} (T-GAM-01, D-87). Ids, dates and counts
/// only, never a health value or free text.
abstract class RewardsRepository {
  /// Badges earned so far, by id, with the local date each was earned. Live.
  Stream<Map<String, String>> watchBadges();

  /// Adds badges (never removes one: an earned badge stays earned).
  Future<void> addBadges(Map<String, String> earned);

  /// The chosen celebration style's name, or null for the default. Live.
  Stream<String?> watchCelebration();

  /// Chooses a celebration style (a cosmetic unlock).
  Future<void> saveCelebration(String style);

  /// Every week's challenge entry. Live.
  Stream<List<ChallengeEntry>> watchChallenges();

  /// Creates or replaces a week's entry. Works offline (queued).
  Future<void> saveChallenge(ChallengeEntry entry);
}

class FirestoreRewardsRepository implements RewardsRepository {
  FirestoreRewardsRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String Function() _uid;

  static const _wait = Duration(seconds: 3);
  static const schemaVersion = 1;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid());
  DocumentReference<Map<String, dynamic>> get _badges =>
      _user.collection('rewards').doc('current');
  CollectionReference<Map<String, dynamic>> get _challenges =>
      _user.collection('challenges');

  @override
  Stream<Map<String, String>> watchBadges() => _badges.snapshots().map(
    (s) => {
      for (final e
          in ((s.data()?['earned'] as Map<String, dynamic>?) ?? const {})
              .entries)
        if (e.value is String) e.key: e.value as String,
    },
  );

  @override
  Future<void> addBadges(Map<String, String> earned) async {
    if (earned.isEmpty) return;
    // A merge keeps the badges already there.
    await _upsert(_badges, {'earned': earned});
  }

  @override
  Stream<String?> watchCelebration() =>
      _badges.snapshots().map((s) => s.data()?['celebration'] as String?);

  @override
  Future<void> saveCelebration(String style) =>
      _upsert(_badges, {'celebration': style});

  @override
  Stream<List<ChallengeEntry>> watchChallenges() => _challenges.snapshots().map(
    (s) => [
      for (final d in s.docs)
        if (d.data()['challenge_id'] case final String id)
          ChallengeEntry(
            week: d.id,
            challengeId: id,
            days: {
              ...((d.data()['days'] as List?) ?? const []).whereType<String>(),
            },
          ),
    ],
  );

  @override
  Future<void> saveChallenge(ChallengeEntry entry) => _upsert(
    _challenges.doc(entry.week),
    {'challenge_id': entry.challengeId, 'days': entry.days.toList()..sort()},
  );

  /// Writes [data] with updated_at and schema_version; created_at only on
  /// the first write (the rules keep it fixed). As in the goal repository.
  Future<void> _upsert(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, Object> data,
  ) async {
    final fields = {
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': schemaVersion,
    };
    final write = await _exists(ref)
        ? ref.set(fields, SetOptions(merge: true))
        : ref.set({...fields, 'created_at': FieldValue.serverTimestamp()});
    // Offline, the write stays queued and the local copy updates at once.
    await write.timeout(_wait, onTimeout: () {});
  }

  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get().timeout(_wait)).exists;
    } catch (_) {
      try {
        return (await ref.get(const GetOptions(source: Source.cache))).exists;
      } on FirebaseException {
        return false;
      }
    }
  }
}

/// Dev preview and tests: kept in memory.
class InMemoryRewardsRepository implements RewardsRepository {
  final badges = <String, String>{};
  final challenges = <String, ChallengeEntry>{};
  String? celebration;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<Map<String, String>> watchBadges() async* {
    yield {...badges};
    yield* _changes.stream.map((_) => {...badges});
  }

  @override
  Future<void> addBadges(Map<String, String> earned) async {
    badges.addAll(earned);
    _changes.add(null);
  }

  @override
  Stream<String?> watchCelebration() async* {
    yield celebration;
    yield* _changes.stream.map((_) => celebration);
  }

  @override
  Future<void> saveCelebration(String style) async {
    celebration = style;
    _changes.add(null);
  }

  @override
  Stream<List<ChallengeEntry>> watchChallenges() async* {
    yield challenges.values.toList();
    yield* _changes.stream.map((_) => challenges.values.toList());
  }

  @override
  Future<void> saveChallenge(ChallengeEntry entry) async {
    challenges[entry.week] = entry;
    _changes.add(null);
  }
}

final _previewRewardsProvider = Provider<RewardsRepository>(
  (ref) => InMemoryRewardsRepository(),
);

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  final auth = ref.watch(authServiceProvider);
  // Dev preview or nobody signed in: nothing to read or save.
  if (ref.watch(previewModeProvider) ||
      ref.watch(signedInUidProvider) == null) {
    return ref.watch(_previewRewardsProvider);
  }
  return FirestoreRewardsRepository(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
  );
});
