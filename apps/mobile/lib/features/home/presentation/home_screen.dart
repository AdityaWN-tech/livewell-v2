import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../checkin/presentation/checkin_sheet.dart';
import '../../dev/application/preview_mode.dart';
import '../../profile/presentation/profile_button.dart';
import '../../starter_plan/application/plan_scheduler.dart';
import '../../starter_plan/presentation/plan_preview_screen.dart'
    show reminderTexts;
import '../application/home_data.dart';
import '../domain/home_models.dart';

/// True when check-ins can be saved: signed in, or the dev preview.
final canCheckInProvider = Provider<bool>(
  (ref) =>
      ref.watch(previewModeProvider) ||
      ref.watch(authServiceProvider).currentUser != null,
);

/// Today's check-in (local date), live. Re-read on resume so the day
/// changes after midnight.
final todayCheckInProvider = StreamProvider<CheckIn?>((ref) {
  if (!ref.watch(canCheckInProvider)) return Stream.value(null);
  final today = localDateKey(ref.watch(clockProvider)());
  return ref.watch(checkInRepositoryProvider).watchDay(today);
});

/// Home tab (T-UI-01b, Screen 1): header with Day N, coach card, the Why,
/// today's one step, quick check-in and the milestone card.
///
/// Actions (FR-DLY-03, at most 1 primary and 2 secondary): Done is the
/// primary; "Make it N min" and Quick check-in are the secondaries. The
/// briefing is media, not an action, and is off until briefings exist.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(todayCheckInProvider);
        _maybeAsk();
        _followTimeZone();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  String get _today => localDateKey(ref.read(clockProvider)());

  /// After travel, move the plan's reminders to the new time zone.
  Future<void> _followTimeZone() async {
    if (ref.read(authServiceProvider).currentUser == null) return;
    try {
      await ref
          .read(planSchedulerProvider)
          .rescheduleIfZoneChanged(reminderTexts(AppLocalizations.of(context)));
    } catch (_) {
      // Reminders are a nice-to-have; never break Home over them.
    }
  }

  /// First open of the day: ask how they feel before anything else. Once per
  /// day only; closing the sheet counts as asked.
  Future<void> _maybeAsk() async {
    if (_asking || !mounted || !ref.read(canCheckInProvider)) return;
    _asking = true;
    try {
      final today = _today;
      final existing = await ref
          .read(checkInRepositoryProvider)
          .watchDay(today)
          .first;
      final prompts = ref.read(checkInPromptStoreProvider);
      final ask = shouldAskToday(
        today: today,
        hasCheckinToday: existing != null,
        lastAskedDay: await prompts.lastAskedDay(),
      );
      if (!ask || !mounted) return;
      await prompts.markAsked(today);
      if (!mounted) return;
      await _openCheckIn(today);
    } finally {
      _asking = false;
    }
  }

  Future<void> _openCheckIn([String? date]) async {
    // The sheet can open on the first frame, before the profile has
    // loaded; wait briefly for it so the greeting can use the first name.
    if (ref.read(firstNameProvider) == null && !ref.read(previewModeProvider)) {
      await ref
          .read(currentProfileProvider.future)
          .timeout(const Duration(seconds: 1), onTimeout: () => null);
    }
    if (!mounted) return;
    await showCheckInSheet(
      context,
      date: date ?? _today,
      firstName: ref.read(firstNameProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final why = ref.watch(currentProfileProvider).value?.whyStatement;
    final checkIn = ref.watch(todayCheckInProvider).value;
    final day = ref.watch(dayNumberProvider);
    return LwScreen(
      eyebrow: l.homeEyebrow,
      title: l.tabHome,
      actions: [if (day != null) _DayPill(day), const ProfileButton()],
      children: [
        _CoachCard(
          coach: ref.watch(coachNameProvider) ?? l.homeCoachDefaultName,
          firstName: ref.watch(firstNameProvider),
          showBriefing: ref.watch(featureFlagsProvider).briefings,
        ),
        // The Why is shown on Home (FR-ONB-05).
        if (why != null && why.isNotEmpty) ...[
          const SizedBox(height: LwSpacing.sm),
          _WhyCard(why),
        ],
        const SizedBox(height: LwSpacing.sm),
        _StepCard(step: ref.watch(todayStepProvider), checkIn: checkIn),
        const SizedBox(height: LwSpacing.sm),
        if (checkIn != null)
          _CheckInSummary(checkIn)
        else if (ref.watch(canCheckInProvider))
          _QuickCheckInRow(onTap: _openCheckIn),
        const SizedBox(height: LwSpacing.sm),
        _MilestoneCard(ref.watch(milestoneProvider)),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill(this.day);
  final int day;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.homeDayLabel(day),
      container: true,
      excludeSemantics: true,
      child: Container(
        key: const Key('home-day'),
        padding: const EdgeInsets.symmetric(
          horizontal: LwSpacing.sm,
          vertical: LwSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: LwRadius.pillAll,
          border: Border.all(color: p.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(p.accent),
            const SizedBox(width: LwSpacing.xs),
            Text(
              l.homeDay(day),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: LwSpacing.xs,
    height: LwSpacing.xs,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Avatar, coach name and greeting. Until Avatar Studio exists the avatar is
/// the coach's initial (the mockup's image was broken).
class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.coach,
    required this.firstName,
    required this.showBriefing,
  });

  final String coach;
  final String? firstName;
  final bool showBriefing;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final greeting = firstName == null
        ? l.homeGreeting
        : l.homeGreetingNamed(firstName!);
    return Card(
      key: const Key('home-coach'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Wrap(
          spacing: LwSpacing.sm,
          runSpacing: LwSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: LwSize.avatarSm * 1.2,
                    height: LwSize.avatarSm * 1.2,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      coach.characters.first.toUpperCase(),
                      style: t.titleLarge?.copyWith(color: p.onPrimaryTint),
                    ),
                  ),
                ),
                const SizedBox(width: LwSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coach, style: t.bodySmall),
                      Text(greeting, style: t.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
            if (showBriefing)
              OutlinedButton.icon(
                key: const Key('home-briefing'),
                onPressed: null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.homeBriefingSoon),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard(this.why);
  final String why;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('home-why'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).homeWhyEyebrow.toUpperCase(),
              style: t.labelSmall,
            ),
            const SizedBox(height: LwSpacing.xxs),
            Text(why, style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// The dark hero card. Shows the planned step with Done / Make it smaller,
/// or a calm placeholder while no plan exists.
class _StepCard extends StatefulWidget {
  const _StepCard({required this.step, required this.checkIn});

  final TodayStep? step;
  final CheckIn? checkIn;

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _smaller = false;
  // TODO(T-DLY-03): save Done to users/{uid}/habit_logs.
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final step = widget.step;
    final checkIn = widget.checkIn;
    final gentle = checkIn?.gentleDay ?? false;
    // A gentle day always gets the smaller step (FR-DLY-02, T-DLY-02).
    final small = _smaller || gentle || step?.smallerTitle == null;

    final String title;
    String? reason;
    if (step == null) {
      title = checkIn == null
          ? l.homeTodayStepBeforeCheckIn
          : gentle
          ? l.homeTodayStepGentle
          : checkIn.timeAvailable != null
          ? l.homeTodayStepTimed(checkIn.timeAvailable!)
          : l.homeTodayStepUntimed;
    } else {
      title = small ? (step.smallerTitle ?? step.title) : step.title;
      reason = gentle ? l.homeStepGentleReason : step.reason;
    }
    final onHero = t.titleLarge?.copyWith(color: p.onHeroSurface);
    final onHeroSoft = t.bodySmall?.copyWith(color: p.onHeroSurfaceSecondary);

    return Container(
      key: const Key('today-step'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.heroSurface,
        borderRadius: LwRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: LwSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(p.accent),
                  const SizedBox(width: LwSpacing.xs),
                  Text(
                    l.homeTodayStepEyebrow.toUpperCase(),
                    style: t.labelSmall?.copyWith(color: p.onHeroSurface),
                  ),
                ],
              ),
              if (step != null) Text(step.driver, style: onHeroSoft),
            ],
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(
            title,
            style: step == null
                ? t.bodyLarge?.copyWith(color: p.onHeroSurface)
                : onHero,
          ),
          if (reason != null) ...[
            const SizedBox(height: LwSpacing.xxs),
            Text(reason, style: onHeroSoft),
          ],
          if (step != null) ...[
            const SizedBox(height: LwSpacing.md),
            if (_done)
              Row(
                key: const Key('step-done-message'),
                children: [
                  Icon(Icons.check_circle, color: p.onHeroSurface),
                  const SizedBox(width: LwSpacing.xs),
                  Expanded(
                    child: Text(
                      l.homeStepDoneMessage,
                      style: t.titleMedium?.copyWith(color: p.onHeroSurface),
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: LwSpacing.sm,
                runSpacing: LwSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('step-done'),
                    onPressed: () => setState(() => _done = true),
                    icon: const Icon(Icons.check),
                    label: Text(l.homeStepDone),
                  ),
                  if (!small && step.smallerMinutes != null)
                    Semantics(
                      label: l.homeStepSmallerLabel(step.smallerMinutes!),
                      container: true,
                      excludeSemantics: true,
                      button: true,
                      child: TextButton(
                        key: const Key('step-smaller'),
                        style: TextButton.styleFrom(
                          foregroundColor: p.onHeroSurface,
                        ),
                        onPressed: () => setState(() => _smaller = true),
                        child: Text(
                          l.homeStepSmaller(step.smallerMinutes!),
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _QuickCheckInRow extends StatelessWidget {
  const _QuickCheckInRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      button: true,
      label: l.homeQuickCheckInLabel,
      container: true,
      excludeSemantics: true,
      child: Card(
        key: const Key('home-checkin-card'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.inputHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LwSpacing.cardPadding,
                vertical: LwSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: LwSize.avatarSm,
                    height: LwSize.avatarSm,
                    decoration: BoxDecoration(
                      color: p.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: LwSize.iconSm,
                      color: p.accentStrong,
                    ),
                  ),
                  const SizedBox(width: LwSpacing.sm),
                  // With large text "Takes 30s" moves under the title so
                  // neither breaks mid-word.
                  if (largeText)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.homeQuickCheckIn, style: t.titleMedium),
                          Text(l.homeQuickCheckInTime, style: t.bodySmall),
                        ],
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Text(l.homeQuickCheckIn, style: t.titleMedium),
                    ),
                    Text(l.homeQuickCheckInTime, style: t.bodySmall),
                  ],
                  Icon(
                    Icons.chevron_right,
                    size: LwSize.iconSm,
                    color: p.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the check-in row once today's check-in is done.
class _CheckInSummary extends StatelessWidget {
  const _CheckInSummary(this.checkIn);
  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final mood = switch (checkIn.mood) {
      1 => l.checkinMood1,
      2 => l.checkinMood2,
      3 => l.checkinMood3,
      4 => l.checkinMood4,
      _ => l.checkinMood5,
    };
    return Card(
      key: const Key('home-checkin-summary'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (toneFor(checkIn)) {
                CheckInTone.high => l.checkinResponseHigh,
                CheckInTone.steady => l.checkinResponseSteady,
                CheckInTone.gentle => l.checkinResponseGentle,
              },
              key: const Key('checkin-response'),
              style: t.titleMedium,
            ),
            const SizedBox(height: LwSpacing.xxs),
            Text(l.homeCheckedIn(mood), style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard(this.milestone);
  final Milestone? milestone;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final m = milestone;
    return Card(
      key: const Key('home-milestone'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: LwSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(l.homeMilestoneTitle, style: t.titleSmall),
                if (m != null)
                  Text(
                    l.homeMilestonePhase(m.phase, m.phaseCount),
                    style: t.labelMedium?.copyWith(color: p.accentStrong),
                  ),
              ],
            ),
            const SizedBox(height: LwSpacing.sm),
            if (m == null)
              Text(l.homeMilestoneEmpty, style: t.bodySmall)
            else ...[
              Semantics(
                label: l.homeMilestoneHabitsLabel(
                  m.habitsKept,
                  m.habitsPlanned,
                ),
                container: true,
                excludeSemantics: true,
                child: ClipRRect(
                  borderRadius: LwRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: m.progress,
                    minHeight: LwSpacing.xs,
                    color: p.success,
                    backgroundColor: p.primaryTint,
                  ),
                ),
              ),
              const SizedBox(height: LwSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: ExcludeSemantics(
                  child: Text(
                    l.homeMilestoneHabits(m.habitsKept, m.habitsPlanned),
                    style: t.labelMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
