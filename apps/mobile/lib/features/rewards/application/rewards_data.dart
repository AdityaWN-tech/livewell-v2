import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../dev/application/preview_mode.dart';
import '../../home/application/home_data.dart' show todayCheckInProvider;
import '../../learn/application/learn_data.dart'
    show contentProgressProvider, safetyClearProvider;
import '../../track/application/track_data.dart' show recentDoneDatesProvider;
import '../../track/presentation/track_screen.dart' show streakProvider;
import '../data/rewards_repository.dart';
import '../domain/reward_catalog.dart';
import '../domain/reward_rules.dart';

export '../../../core/config/feature_flags.dart' show rewardsOnProvider;

/// content/rewards/catalog.json (copied to assets/rewards/).
final rewardCatalogProvider = FutureProvider<RewardCatalog>(
  (ref) async => RewardCatalog.parse(
    await rootBundle.loadString('assets/rewards/catalog.json', cache: false),
  ),
);

/// Badges already saved (an earned badge stays earned).
final savedBadgesProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(rewardsRepositoryProvider).watchBadges(),
);

/// The Done celebration's style: the chosen one while it is unlocked (and
/// rewards are on), else the leaves everyone has.
final celebrationStyleProvider = Provider<CelebrationStyle>((ref) {
  if (!ref.watch(rewardsOnProvider)) return CelebrationStyle.leaves;
  final chosen = CelebrationStyle.byName(
    ref.watch(_chosenCelebrationProvider).value,
  );
  final ok = ref
      .watch(unlockedProvider)
      .any((u) => u.celebration != null && u.celebration == chosen);
  return ok ? chosen! : CelebrationStyle.leaves;
});

final _chosenCelebrationProvider = StreamProvider<String?>(
  (ref) => ref.watch(rewardsRepositoryProvider).watchCelebration(),
);

/// Every week's challenge entry.
final challengesProvider = StreamProvider<List<ChallengeEntry>>(
  (ref) => ref.watch(rewardsRepositoryProvider).watchChallenges(),
);

/// What the badges count, from the streak engine, the Learn reader and the
/// challenges. Counts only.
final rewardProgressProvider = Provider<RewardProgress>((ref) {
  final streak = ref.watch(streakProvider);
  final catalog = ref.watch(rewardCatalogProvider).value;
  final entries = ref.watch(challengesProvider).value ?? const [];
  final preview = ref.watch(previewModeProvider);
  return RewardProgress(
    daysDone: preview
        ? 9
        : {...?ref.watch(recentDoneDatesProvider).value}.length,
    bestStreak: streak?.best ?? 0,
    restarts: preview ? 1 : streak?.restarts ?? 0,
    lessonsCompleted: [
      for (final p
          in (ref.watch(contentProgressProvider).value ?? const {}).values)
        if (p.completed) p,
    ].length,
    challengesCompleted: [
      for (final e in entries)
        if (catalog?.challenge(e.challengeId) case final c?
            when e.completeFor(c))
          e,
    ].length,
  );
});

/// Saved badges plus any newly earned (saved by [RewardsSync]).
final earnedBadgesProvider = Provider<Map<String, String>>((ref) {
  final catalog = ref.watch(rewardCatalogProvider).value;
  final saved = ref.watch(savedBadgesProvider).value ?? const {};
  if (catalog == null) return saved;
  final today = localDateKey(ref.watch(clockProvider)());
  return {
    for (final id in RewardRules.earned(
      catalog,
      ref.watch(rewardProgressProvider),
    ))
      id: today,
    ...saved,
  };
});

/// Badges earned but not saved yet.
final newBadgesProvider = Provider<Map<String, String>>((ref) {
  final saved = ref.watch(savedBadgesProvider).value;
  // Not loaded: nothing is "new" yet.
  if (saved == null) return const {};
  return {
    for (final e in ref.watch(earnedBadgesProvider).entries)
      if (!saved.containsKey(e.key)) e.key: e.value,
  };
});

/// The cosmetic unlocks earned.
final unlockedProvider = Provider<List<Unlockable>>((ref) {
  final catalog = ref.watch(rewardCatalogProvider).value;
  if (catalog == null || !ref.watch(rewardsOnProvider)) return const [];
  return RewardRules.unlocked(
    catalog,
    ref.watch(earnedBadgesProvider).keys.toSet(),
  );
});

/// Extra avatar backgrounds unlocked: (AvatarColours index, name), past
/// the six everyone has.
final unlockedBackgroundNamesProvider = Provider<List<(int, String)>>(
  (ref) => [
    for (final u in ref.watch(unlockedProvider))
      if (u.kind == UnlockKind.background && u.background != null)
        (u.background!, u.title),
  ],
);

/// Rewards stay quiet: no challenge invitation, no "days to go" (D-87).
final rewardsQuietProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  return RewardRules.quiet(
    gentleDay: ref.watch(todayCheckInProvider).value?.gentleDay ?? false,
    edSafeMode: profile?.edSafeMode ?? false,
    safetyClear: ref.watch(safetyClearProvider),
  );
});

/// This week's challenge and the person's entry for it (null entry: not
/// joined). Null when none can be offered.
final weekChallengeProvider =
    Provider<
      ({WeeklyChallenge challenge, ChallengeEntry? entry, String week})?
    >((ref) {
      final catalog = ref.watch(rewardCatalogProvider).value;
      if (catalog == null) return null;
      final week = RewardRules.weekOf(ref.watch(clockProvider)());
      final entry = (ref.watch(challengesProvider).value ?? const [])
          .where((e) => e.week == week)
          .firstOrNull;
      // A challenge already joined stays, whatever the rotation says.
      final joined = entry == null
          ? null
          : catalog.challenge(entry.challengeId);
      if (joined != null) {
        return (challenge: joined, entry: entry, week: week);
      }
      final profile = ref.watch(currentProfileProvider).value;
      final offered = RewardRules.offered(
        catalog,
        activityLimited: profile?.activityLimited,
        edSafeMode: profile?.edSafeMode ?? false,
      );
      final c = RewardRules.forWeek(offered, week);
      return c == null ? null : (challenge: c, entry: null, week: week);
    });

/// Joining this week's challenge and marking today, and saving newly
/// earned badges. No notifications: rewards never add a push (D-71 cap).
class RewardsActions {
  RewardsActions(this._ref);

  final Ref _ref;

  RewardsRepository get _repo => _ref.read(rewardsRepositoryProvider);

  String get _today => localDateKey(_ref.read(clockProvider)());

  Future<void> join(WeeklyChallenge c) => _repo.saveChallenge(
    ChallengeEntry(
      week: RewardRules.weekOf(_ref.read(clockProvider)()),
      challengeId: c.id,
    ),
  );

  Future<void> markToday(ChallengeEntry entry) =>
      _repo.saveChallenge(entry.withDay(_today));

  Future<void> chooseCelebration(CelebrationStyle style) =>
      _repo.saveCelebration(style.name);

  Future<void> saveNewBadges() async {
    final fresh = _ref.read(newBadgesProvider);
    if (fresh.isEmpty) return;
    try {
      await _repo.addBadges(fresh);
    } catch (_) {
      // Offline or not signed in: tried again next time.
    }
  }
}

final rewardsActionsProvider = Provider<RewardsActions>(RewardsActions.new);
