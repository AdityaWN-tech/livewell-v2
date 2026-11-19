import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../checkin/domain/checkin.dart' show localDateKey;
import '../application/rewards_data.dart';
import '../domain/reward_catalog.dart';

/// Badges and challenges (T-GAM-01, FR-GAM-01/03), from Track. One primary
/// action: this week's challenge (join, or "I did it today"). Then the
/// badges (consistency, learning, recovery and function only) and the
/// cosmetic looks they unlock. Kind by design: no counters, invitations or
/// "new" fanfare while rewards are quiet (gentle day, eating-disorder safe
/// mode, or a safety event not ruled out; D-87). Never sends a
/// notification.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  static const path = '/track/rewards';

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    // Earned badges are kept, so a badge never disappears later.
    ref.listenManual(newBadgesProvider, (_, fresh) {
      if (fresh.isNotEmpty) ref.read(rewardsActionsProvider).saveNewBadges();
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final catalog = ref.watch(rewardCatalogProvider).value;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        key: const Key('rewards-list'),
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          LwPageTitle(l.rewardsTitle),
          Text(l.rewardsSubtitle, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.md),
          const _ChallengeCard(),
          if (catalog != null) ...[
            LwSectionHeader(l.rewardsBadgesTitle),
            _Badges(catalog),
            LwSectionHeader(l.rewardsUnlocksTitle),
            Text(l.rewardsUnlocksBody, style: t.bodySmall),
            const SizedBox(height: LwSpacing.xs),
            _Unlocks(catalog),
          ],
        ],
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final quiet = ref.watch(rewardsQuietProvider);
    final week = ref.watch(weekChallengeProvider);
    final today = localDateKey(ref.watch(clockProvider)());
    final actions = ref.read(rewardsActionsProvider);

    final Widget body;
    if (quiet) {
      body = Text(
        l.rewardsChallengeQuiet,
        key: const Key('rewards-challenge-quiet'),
        style: t.bodyMedium,
      );
    } else if (week == null) {
      body = Text(
        l.rewardsChallengeNone,
        key: const Key('rewards-challenge-none'),
        style: t.bodyMedium,
      );
    } else {
      final c = week.challenge;
      final entry = week.entry;
      final complete = entry != null && entry.completeFor(c);
      final doneToday = entry?.doneOn(today) ?? false;
      body = Column(
        key: Key('rewards-challenge-${c.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.title, style: t.titleLarge),
          const SizedBox(height: LwSpacing.xxs),
          Text(c.how, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.xxs),
          Text(l.rewardsChallengeTarget(c.targetDays), style: t.bodySmall),
          if (entry != null) ...[
            const SizedBox(height: LwSpacing.sm),
            Text(
              complete
                  ? l.rewardsChallengeComplete
                  : l.rewardsChallengeProgress(entry.days.length, c.targetDays),
              key: const Key('rewards-challenge-progress'),
              style: t.titleSmall?.copyWith(color: p.primaryDark),
            ),
          ],
          const SizedBox(height: LwSpacing.sm),
          if (entry == null)
            FilledButton(
              key: const Key('rewards-challenge-join'),
              onPressed: () => actions.join(c),
              child: Text(l.rewardsChallengeJoin),
            )
          else if (doneToday)
            Text(
              l.rewardsChallengeDoneToday,
              key: const Key('rewards-challenge-done-today'),
              style: t.bodyMedium,
            )
          else
            FilledButton(
              key: const Key('rewards-challenge-mark'),
              onPressed: () => actions.markToday(entry),
              child: Text(l.rewardsChallengeMark),
            ),
        ],
      );
    }
    return Card(
      key: const Key('rewards-challenge'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.rewardsChallengeTitle.toUpperCase(),
                style: t.labelSmall,
              ),
            ),
            const SizedBox(height: LwSpacing.xs),
            body,
          ],
        ),
      ),
    );
  }
}

/// How a badge is earned, in kind words.
String howToEarn(AppLocalizations l, RewardBadge b) => switch (b.rule) {
  BadgeRuleType.daysDone => l.rewardsHowDaysDone(b.count),
  BadgeRuleType.streakDays => l.rewardsHowStreak(b.count),
  BadgeRuleType.restarts => l.rewardsHowRestarts(b.count),
  BadgeRuleType.lessonsCompleted => l.rewardsHowLessons(b.count),
  BadgeRuleType.challengesCompleted => l.rewardsHowChallenges(b.count),
};

IconData _badgeIcon(RewardBasis basis) => switch (basis) {
  RewardBasis.consistency => Icons.wb_sunny_outlined,
  RewardBasis.learning => Icons.menu_book_outlined,
  RewardBasis.recovery => Icons.autorenew,
  RewardBasis.function => Icons.directions_walk,
};

class _Badges extends ConsumerWidget {
  const _Badges(this.catalog);

  final RewardCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final earned = ref.watch(earnedBadgesProvider);
    final quiet = ref.watch(rewardsQuietProvider);
    final today = localDateKey(ref.watch(clockProvider)());
    return Card(
      child: Column(
        children: [
          for (final b in catalog.badges)
            () {
              final has = earned.containsKey(b.id);
              final how = howToEarn(l, b);
              return Semantics(
                container: true,
                excludeSemantics: true,
                label: has
                    ? l.rewardsBadgeEarnedLabel(b.title, b.line)
                    : l.rewardsBadgeNotYetLabel(b.title, quiet ? '' : how),
                child: ListTile(
                  key: Key(
                    'rewards-badge-${b.id}-${has ? 'earned' : 'not-yet'}',
                  ),
                  leading: CircleAvatar(
                    backgroundColor: has ? p.mint : p.surfaceMuted,
                    child: Icon(
                      _badgeIcon(b.basis),
                      color: has ? p.primaryDark : p.textDisabled,
                    ),
                  ),
                  title: Text(
                    b.title,
                    style: t.titleSmall?.copyWith(
                      color: has ? p.textPrimary : p.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    has ? b.line : (quiet ? l.rewardsNotYet : how),
                    style: t.bodySmall,
                  ),
                  trailing: has && !quiet && earned[b.id] == today
                      ? LwTag(l.rewardsBadgeNew)
                      : null,
                ),
              );
            }(),
        ],
      ),
    );
  }
}

class _Unlocks extends ConsumerWidget {
  const _Unlocks(this.catalog);

  final RewardCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final unlocked = {for (final u in ref.watch(unlockedProvider)) u.id};
    final style = ref.watch(celebrationStyleProvider);
    final actions = ref.read(rewardsActionsProvider);
    final celebrations = [
      for (final u in catalog.unlockables)
        if (u.kind == UnlockKind.celebration && unlocked.contains(u.id)) u,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              for (final u in catalog.unlockables)
                ListTile(
                  key: Key(
                    'rewards-unlock-${u.id}-'
                    '${unlocked.contains(u.id) ? 'open' : 'locked'}',
                  ),
                  leading: u.kind == UnlockKind.background
                      ? CircleAvatar(
                          backgroundColor:
                              AvatarColours.background[u.background!],
                        )
                      : CircleAvatar(
                          backgroundColor: p.surfaceMuted,
                          child: Icon(
                            Icons.celebration_outlined,
                            color: p.primaryDark,
                          ),
                        ),
                  title: Text(u.title, style: t.titleSmall),
                  subtitle: Text(
                    unlocked.contains(u.id)
                        ? (u.kind == UnlockKind.background
                              ? l.rewardsBackgroundUnlocked
                              : l.rewardsCelebrationTitle)
                        : l.rewardsUnlockedBy(
                            catalog.badge(u.unlockedBy)?.title ?? '',
                          ),
                    style: t.bodySmall,
                  ),
                  trailing: unlocked.contains(u.id)
                      ? null
                      : Icon(Icons.lock_outline, color: p.textSecondary),
                ),
            ],
          ),
        ),
        if (celebrations.isNotEmpty) ...[
          LwSectionHeader(l.rewardsCelebrationTitle),
          Wrap(
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xs,
            children: [
              ChoiceChip(
                key: const Key('rewards-celebration-leaves'),
                label: Text(l.rewardsCelebrationLeaves),
                selected: style == CelebrationStyle.leaves,
                onSelected: (_) =>
                    actions.chooseCelebration(CelebrationStyle.leaves),
              ),
              for (final u in celebrations)
                ChoiceChip(
                  key: Key('rewards-celebration-${u.celebration!.name}'),
                  label: Text(u.title),
                  selected: style == u.celebration,
                  onSelected: (_) => actions.chooseCelebration(u.celebration!),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Track's "Your badges" card (only while rewards are on).
class RewardsCard extends ConsumerWidget {
  const RewardsCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final count = ref.watch(earnedBadgesProvider).length;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: l.rewardsCardLabel(count),
      child: Card(
        key: const Key('track-rewards'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: p.mint,
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: p.primaryDark,
                  ),
                ),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.rewardsCardTitle, style: t.titleSmall),
                      Text(l.rewardsCardBody(count), style: t.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
