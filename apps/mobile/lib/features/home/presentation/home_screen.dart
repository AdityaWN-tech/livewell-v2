import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../checkin/presentation/checkin_sheet.dart';
import '../../dev/application/preview_mode.dart';
import '../../profile/presentation/profile_button.dart';
import '../../starter_plan/application/plan_scheduler.dart';
import '../../starter_plan/presentation/plan_preview_screen.dart'
    show reminderTexts;
import '../../track/domain/track_models.dart';
import '../../track/presentation/track_screen.dart' show streakProvider;
import '../application/home_data.dart';

export '../application/home_data.dart'
    show canCheckInProvider, todayCheckInProvider;
import '../data/name_prompt.dart';
import '../domain/home_models.dart';

/// Home tab (T-UI-02c, illustrated design): greeting header, the coach
/// hero with a speech bubble, the Why, Today's Next Step, the 4 Quick
/// Check-in tiles, the streak and the milestone.
///
/// Actions (FR-DLY-03, at most 1 primary and 2 secondary): the step card
/// opens Done (the primary) and "Make it N min" (a secondary); the check-in
/// tiles are the other secondary (all 4 open the same check-in). The
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

  Future<void> _openStep(TodayStep step, CheckIn? checkIn) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _StepSheet(
        step: step,
        small: _isSmall(step, checkIn),
        reason: _stepReason(AppLocalizations.of(context), step, checkIn),
      ),
    );
    final progress = ref.read(stepProgressActionsProvider);
    if (result == 'done') progress.markDone();
    if (result == 'smaller') progress.makeSmaller();
  }

  /// A gentle day always gets the smaller step (FR-DLY-02, T-DLY-02).
  bool _isSmall(TodayStep step, CheckIn? checkIn) =>
      ref.read(stepProgressProvider).smaller ||
      (checkIn?.gentleDay ?? false) ||
      step.smallerTitle == null;

  String? _stepReason(AppLocalizations l, TodayStep step, CheckIn? checkIn) {
    final reason = checkIn == null ? null : gentleReasonFor(checkIn);
    return switch (reason) {
      null => step.reason,
      GentleReason.lowMood => l.homeStepGentleLowMood,
      GentleReason.highStress => l.homeStepGentleStress,
      GentleReason.both => l.homeStepGentleBoth,
      GentleReason.other => l.homeStepGentleReason,
    };
  }

  Future<void> _saveName(String name) async {
    await ref.read(namePromptStoreProvider).markAsked();
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      await ref.read(profileRepositoryProvider).updateSettings(uid, {
        ProfileSettings.displayName: name,
      });
      ref.invalidate(currentProfileProvider);
    }
    ref.invalidate(namePromptAskedProvider);
  }

  Future<void> _skipName() async {
    await ref.read(namePromptStoreProvider).markAsked();
    ref.invalidate(namePromptAskedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final why = ref.watch(currentProfileProvider).value?.whyStatement;
    final checkIn = ref.watch(todayCheckInProvider).value;
    final day = ref.watch(dayNumberProvider);
    final name = ref.watch(firstNameProvider);
    final hour = ref.watch(clockProvider)().hour;
    final step = ref.watch(todayStepProvider);
    final gentle = checkIn?.gentleDay ?? false;
    final progress = ref.watch(stepProgressProvider);
    // Ask once, only for a signed-in account whose profile has loaded
    // without a name (Google or Apple names are used without asking).
    final askName =
        name == null &&
        ref.watch(authServiceProvider).currentUser != null &&
        ref.watch(currentProfileProvider).hasValue &&
        ref.watch(namePromptAskedProvider).value == false;
    final evening = hour >= 18 || hour < 5;
    return LwScreen(
      eyebrow: l.tabHome,
      title: switch (hour) {
        >= 5 && < 12 =>
          name == null
              ? l.homeGreetingMorning
              : l.homeGreetingMorningNamed(name),
        >= 12 && < 18 =>
          name == null
              ? l.homeGreetingAfternoon
              : l.homeGreetingAfternoonNamed(name),
        _ =>
          name == null
              ? l.homeGreetingEvening
              : l.homeGreetingEveningNamed(name),
      },
      titleIcon: ExcludeSemantics(
        child: Icon(
          evening ? Icons.nightlight_round : Icons.wb_sunny_rounded,
          key: const Key('home-greeting-icon'),
          color: evening ? p.primaryDark : p.caution,
          size: LwSize.iconSm,
        ),
      ),
      subtitle: l.homeSubtitle,
      profile: const ProfileButton(),
      actions: [if (day != null) _DayPill(day)],
      children: [
        if (askName) ...[
          _NamePrompt(onSave: _saveName, onSkip: _skipName),
          const SizedBox(height: LwSpacing.sm),
        ],
        _HeroCard(
          coach: ref.watch(coachNameProvider) ?? l.homeCoachDefaultName,
          bubble: gentle
              ? (name == null
                    ? l.homeBubbleGentle
                    : l.homeBubbleGentleNamed(name))
              : (name == null ? l.homeBubble : l.homeBubbleNamed(name)),
          showBriefing: ref.watch(featureFlagsProvider).briefings,
        ),
        // The Why is shown on Home (FR-ONB-05).
        if (why != null && why.isNotEmpty) ...[
          const SizedBox(height: LwSpacing.sm),
          _WhyCard(why),
        ],
        LwSectionHeader(l.homeNextStepTitle),
        _StepCard(
          step: step,
          checkIn: checkIn,
          done: progress.done,
          small: step != null && _isSmall(step, checkIn),
          reason: step == null ? null : _stepReason(l, step, checkIn),
          onOpen: step == null ? null : () => _openStep(step, checkIn),
        ),
        if (ref.watch(canCheckInProvider)) ...[
          LwSectionHeader(l.homeCheckInTitle),
          _CheckInTiles(checkIn: checkIn, onTap: _openCheckIn),
          if (checkIn != null) ...[
            const SizedBox(height: LwSpacing.sm),
            _CheckInResponse(checkIn),
          ],
        ],
        const SizedBox(height: LwSpacing.sectionGap),
        _StreakCard(ref.watch(streakProvider)),
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

/// "What should your coach call you?", asked once (T-UI-02c).
class _NamePrompt extends StatefulWidget {
  const _NamePrompt({required this.onSave, required this.onSkip});

  final Future<void> Function(String name) onSave;
  final Future<void> Function() onSkip;

  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _text.text.trim();
    if (!isValidFirstName(name)) {
      setState(() => _error = AppLocalizations.of(context).homeNameError);
      return;
    }
    await widget.onSave(name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('home-name-prompt'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(color: p.mint, borderRadius: LwRadius.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeNameTitle,
            style: t.titleMedium?.copyWith(color: p.onTint),
          ),
          const SizedBox(height: LwSpacing.sm),
          TextField(
            key: const Key('home-name-field'),
            controller: _text,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            maxLength: 30,
            decoration: InputDecoration(
              hintText: l.profileNameHint,
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: LwSpacing.sm),
          Wrap(
            spacing: LwSpacing.sm,
            runSpacing: LwSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                key: const Key('home-name-save'),
                onPressed: _save,
                child: Text(l.homeNameSave),
              ),
              TextButton(
                key: const Key('home-name-skip'),
                style: TextButton.styleFrom(foregroundColor: p.primaryDark),
                onPressed: widget.onSkip,
                child: Text(l.homeNameNotNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The coach waving on a leafy scene, with a greeting bubble and, when
/// briefings exist, the Morning Briefing row (T-UI-02c).
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.coach,
    required this.bubble,
    required this.showBriefing,
  });

  final String coach;
  final String bubble;
  final bool showBriefing;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return ClipRRect(
      key: const Key('home-coach'),
      borderRadius: LwRadius.lgAll,
      child: Stack(
        children: [
          const Positioned.fill(
            child: Illustration(
              'scene_home_hero',
              fit: BoxFit.cover,
              placeholderIcon: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coach,
                  style: t.labelMedium?.copyWith(color: p.onTintSecondary),
                ),
                const SizedBox(height: LwSpacing.xs),
                CoachAvatar(
                  expression: AvatarExpression.waving,
                  bubble: bubble,
                  size: 104,
                ),
                const SizedBox(height: LwSpacing.sm),
                if (showBriefing)
                  _BriefingRow()
                else
                  Text(
                    l.homeTagline,
                    key: const Key('home-tagline'),
                    style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Your Morning Briefing" (flag on). No briefings are made yet, so the
/// player waits, saying so; it never plays made-up audio.
class _BriefingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('home-briefing'),
      padding: const EdgeInsets.all(LwSpacing.sm),
      decoration: BoxDecoration(color: p.surface, borderRadius: LwRadius.mdAll),
      child: Row(
        children: [
          Container(
            width: LwSize.minTapTarget,
            height: LwSize.minTapTarget,
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow_rounded, color: p.textSecondary),
          ),
          const SizedBox(width: LwSpacing.sm),
          Expanded(child: Text(l.homeBriefingSoon, style: t.titleSmall)),
        ],
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

/// Today's Next Step: a lime card with art, the step and a short line.
/// Tapping it opens the step with Done and the smaller option.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.checkIn,
    required this.done,
    required this.small,
    required this.reason,
    required this.onOpen,
  });

  final TodayStep? step;
  final CheckIn? checkIn;
  final bool done;
  final bool small;
  final String? reason;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final step = this.step;
    final checkIn = this.checkIn;
    final gentle = checkIn?.gentleDay ?? false;

    final String title;
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
    }
    final content = Padding(
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      child: Row(
        children: [
          const Illustration('icon_steps', width: 56, height: 56),
          const SizedBox(width: LwSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step != null)
                  Text(
                    step.driver,
                    style: t.labelSmall?.copyWith(
                      color: p.onHeroSurfaceSecondary,
                    ),
                  ),
                Text(
                  title,
                  style: (step == null ? t.bodyLarge : t.titleMedium)?.copyWith(
                    color: p.onHeroSurface,
                  ),
                ),
                if (step != null && done)
                  Row(
                    key: const Key('step-done-message'),
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: p.primaryDark,
                        size: LwSize.iconSm,
                      ),
                      const SizedBox(width: LwSpacing.xxs),
                      Flexible(
                        child: Text(
                          l.homeStepDoneShort,
                          style: t.bodySmall?.copyWith(color: p.primaryDark),
                        ),
                      ),
                    ],
                  )
                else if (reason != null)
                  Text(
                    reason!,
                    key: const Key('step-reason'),
                    style: t.bodySmall?.copyWith(
                      color: p.onHeroSurfaceSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onOpen != null && !done)
            Icon(Icons.chevron_right, color: p.onHeroSurface),
        ],
      ),
    );
    return Material(
      key: const Key('today-step'),
      color: p.heroSurface,
      borderRadius: LwRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: onOpen == null || done
          ? content
          : Semantics(
              button: true,
              label: l.homeNextStepOpenLabel(title),
              container: true,
              excludeSemantics: true,
              child: InkWell(
                key: const Key('step-open'),
                onTap: onOpen,
                child: content,
              ),
            ),
    );
  }
}

/// The step, opened from Today's Next Step: Done (the one primary action,
/// FR-DLY-03) and the smaller option.
class _StepSheet extends StatelessWidget {
  const _StepSheet({
    required this.step,
    required this.small,
    required this.reason,
  });

  final TodayStep step;
  final bool small;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LwSpacing.screenGutter,
          0,
          LwSpacing.screenGutter,
          LwSpacing.lg,
        ),
        child: Column(
          key: const Key('step-sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.driver, style: t.labelSmall),
            Text(
              small ? (step.smallerTitle ?? step.title) : step.title,
              style: t.titleLarge,
            ),
            if (reason != null) ...[
              const SizedBox(height: LwSpacing.xs),
              Text(reason!, style: t.bodyMedium),
            ],
            const SizedBox(height: LwSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('step-done'),
                onPressed: () => Navigator.pop(context, 'done'),
                icon: const Icon(Icons.check),
                label: Text(l.homeStepDone),
              ),
            ),
            if (!small && step.smallerMinutes != null) ...[
              const SizedBox(height: LwSpacing.xs),
              Center(
                child: Semantics(
                  label: l.homeStepSmallerLabel(step.smallerMinutes!),
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  child: TextButton(
                    key: const Key('step-smaller'),
                    style: TextButton.styleFrom(foregroundColor: p.primaryDark),
                    onPressed: () => Navigator.pop(context, 'smaller'),
                    child: Text(l.homeStepSmaller(step.smallerMinutes!)),
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

/// Mood, Energy, Sleep and Stress tiles (T-UI-02c). Any tile opens the
/// mood-first check-in; after it, each shows today's answer in full words.
class _CheckInTiles extends StatelessWidget {
  const _CheckInTiles({required this.checkIn, required this.onTap});

  final CheckIn? checkIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    final c = checkIn;
    String value(int? v, List<String> words) => c == null
        ? l.homeTileEmpty
        : v == null
        ? l.homeTileSkipped
        : words[v - 1];
    final tiles = [
      (
        'mood',
        l.homeTileMood,
        'icon_mood',
        p.butter,
        value(c?.mood, [
          l.checkinMood1,
          l.checkinMood2,
          l.checkinMood3,
          l.checkinMood4,
          l.checkinMood5,
        ]),
      ),
      (
        'energy',
        l.homeTileEnergy,
        'icon_energy',
        p.peach,
        value(c?.energy, [
          l.checkinEnergy1,
          l.checkinEnergy2,
          l.checkinEnergy3,
          l.checkinEnergy4,
          l.checkinEnergy5,
        ]),
      ),
      (
        'sleep',
        l.homeTileSleep,
        'icon_sleep',
        p.lavender,
        value(c?.sleep, [
          l.checkinSleep1,
          l.checkinSleep2,
          l.checkinSleep3,
          l.checkinSleep4,
          l.checkinSleep5,
        ]),
      ),
      (
        'stress',
        l.homeTileStress,
        'icon_stress',
        p.sky,
        value(c?.stress, [
          l.checkinStress1,
          l.checkinStress2,
          l.checkinStress3,
          l.checkinStress4,
          l.checkinStress5,
        ]),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        // 4 across normally; 2 across on small phones or with large text,
        // so values like "Very high" never break mid-word.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = box.maxWidth / scale >= 300 ? 4 : 2;
        final gap = LwSpacing.xs;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          key: const Key('home-checkin-card'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (id, label, art, tint, v) in tiles)
              SizedBox(
                width: width,
                child: _Tile(
                  id: id,
                  label: label,
                  art: art,
                  tint: tint,
                  value: v,
                  onTap: onTap,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.id,
    required this.label,
    required this.art,
    required this.tint,
    required this.value,
    required this.onTap,
  });

  final String id;
  final String label;
  final String art;
  final Color tint;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.homeTileLabel(label, value),
      container: true,
      excludeSemantics: true,
      child: Material(
        color: tint,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('home-tile-$id'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LwSpacing.xs,
                vertical: LwSpacing.sm,
              ),
              child: Column(
                children: [
                  Illustration(art, width: 40, height: 40),
                  const SizedBox(height: LwSpacing.xxs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: t.labelMedium?.copyWith(color: p.onTint),
                  ),
                  Text(
                    value,
                    key: Key('home-tile-$id-value'),
                    textAlign: TextAlign.center,
                    style: t.labelSmall?.copyWith(color: p.onTintSecondary),
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

/// The supportive line after today's check-in. On a gentle day it matches
/// the reason: low mood, high stress, both, or a neutral line (T-UI-02c).
class _CheckInResponse extends StatelessWidget {
  const _CheckInResponse(this.checkIn);
  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final text = switch (gentleReasonFor(checkIn)) {
      GentleReason.lowMood => l.checkinResponseGentleLowMood,
      GentleReason.highStress => l.checkinResponseGentleStress,
      GentleReason.both => l.checkinResponseGentleBoth,
      GentleReason.other => l.checkinResponseGentle,
      null =>
        toneFor(checkIn) == CheckInTone.high
            ? l.checkinResponseHigh
            : l.checkinResponseSteady,
    };
    return Text(text, key: const Key('checkin-response'), style: t.bodyMedium);
  }
}

/// N Day Streak (T-UI-02c). Grace and restart wording only: no red, no
/// alarm for missed days (FR-DLY-07).
class _StreakCard extends StatelessWidget {
  const _StreakCard(this.streak);
  final StreakSummary? streak;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final s = streak;
    return Container(
      key: const Key('home-streak'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(color: p.butter, borderRadius: LwRadius.lgAll),
      child: Row(
        children: [
          const Illustration('icon_streak', width: 48, height: 48),
          const SizedBox(width: LwSpacing.sm),
          Expanded(
            child: s == null || s.length == 0
                ? Text(
                    l.homeStreakEmpty,
                    style: t.bodyMedium?.copyWith(color: p.onTint),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.homeStreakTitle(s.length),
                        style: t.titleMedium?.copyWith(color: p.onTint),
                      ),
                      Text(
                        l.homeStreakKeepGoing,
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                    ],
                  ),
          ),
          const Illustration('lesson_driver_1', width: 40, height: 40),
        ],
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
                    color: p.accent,
                    backgroundColor: p.surfaceMuted,
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
