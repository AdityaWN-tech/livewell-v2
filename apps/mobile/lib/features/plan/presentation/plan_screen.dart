import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../checkin/domain/checkin.dart';
import '../../dev/application/preview_mode.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_sheets.dart';
import '../../home/application/home_data.dart';
import '../../routine/application/routine_data.dart';
import '../../routine/domain/label_check.dart';
import '../../routine/presentation/label_check_flow.dart';
import '../../routine/presentation/routine_sheets.dart' show LabelOutcome;
import '../../routine/presentation/routine_screen.dart';
import '../../profile/presentation/profile_button.dart';
import '../application/plan_data.dart';
import '../domain/plan_models.dart';
import 'live_well_map.dart';

/// Plan tab (T-UI-02d, illustrated design): calendar button, the Live Well
/// Map, the 30-day goal, today's Daily Microhabits (today's step first, the
/// same one Home shows) with the FR-GOL-01 limits, the MY GOAL DO IT entry
/// (FR-GOL-06) and a daily thought.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  static const frameworkPath = '/plan/framework';

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  GoalRepository get _repo => ref.read(goalRepositoryProvider);
  String get _today => localDateKey(ref.read(clockProvider)());

  void _markDone(PlanHabit h) {
    if (h.id == todayStepHabitId) {
      // Shared with Home: both show it done.
      ref.read(stepProgressActionsProvider).markDone();
    } else {
      final now = ref.read(clockProvider)();
      _repo.saveLog(
        HabitLog(date: localDateKey(now), habitId: h.id, doneAt: now),
      );
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Typed goal and habit words: the same checks as routine labels (D-46).
  Future<LabelOutcome> _checkWords(String words) {
    final l = AppLocalizations.of(context);
    return runLabelCheck(
      context,
      ref,
      words,
      blocked: (kind) => switch (kind) {
        LabelKind.medication => l.goalLabelMedication,
        LabelKind.notAllowed => l.goalLabelNotAllowed,
        LabelKind.unkind => l.routineLabelUnkind,
        LabelKind.disorderedEating => l.routineLabelNotSaved,
      },
      notSaved: () => _snack(l.routineLabelNotSaved),
    );
  }

  Future<T?> _form<T>(Widget child) {
    // A snackbar from the last save would cover the sheet's button.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => child,
    );
  }

  Future<void> _editGoal() async {
    final l = AppLocalizations.of(context);
    final goal = ref.read(goalProvider).value;
    final result = await _form<GoalSheetResult>(
      GoalSheet(goal: goal, today: _today, checkLabel: _checkWords),
    );
    switch (result) {
      case GoalSaved(goal: final g):
        await _repo.saveGoal(g);
        if (mounted) _snack(l.goalSaved);
      case GoalPaused() when goal != null:
        await _repo.saveGoal(goal.copyWith(status: GoalStatus.paused));
        if (mounted) _snack(l.goalPausedSnack);
      case GoalRestarted() when goal != null:
        await _repo.saveGoal(
          goal.copyWith(status: GoalStatus.active, startDate: _today),
        );
        if (mounted) _snack(l.goalRestartedSnack);
      case _:
    }
  }

  /// Opens a habit sheet for [habit] and saves what comes back.
  Future<void> _habitSheet(UserHabit habit) async {
    final l = AppLocalizations.of(context);
    final result = await _form<HabitSheetResult>(
      HabitSheet(habit: habit, checkLabel: _checkWords),
    );
    switch (result) {
      case HabitSaved(habit: final h):
        await _repo.saveHabit(h);
        if (mounted && habit.title.isEmpty) _snack(l.habitAdded(h.title));
      case HabitStopped():
        await _repo.saveHabit(habit.copyWith(active: false));
        if (mounted) _snack(l.habitStoppedSnack(habit.title));
      case null:
    }
  }

  void _changeHabit(PlanHabit h) {
    final own = ref.read(userHabitsProvider).value ?? const [];
    final habit = own.where((x) => x.id == h.id).firstOrNull;
    if (habit != null) _habitSheet(habit);
  }

  Future<void> _sheet(Widget child, {Key? key}) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => KeyedSubtree(key: key, child: child),
  );

  /// FR-GOL-01: room for a supporting habit opens the habit sheet;
  /// otherwise the plan is full.
  Future<void> _newHabit(List<PlanHabit> habits) {
    final l = AppLocalizations.of(context);
    final slot = ref.read(previewModeProvider)
        ? null
        : freeHabitSlot(
            ref.read(userHabitsProvider).value ?? const [],
            HabitLimits.count(habits, HabitRole.supporting),
          );
    if (slot == null) {
      return _sheet(
        _InfoSheet(
          key: const Key('plan-full'),
          title: l.planFullTitle,
          body: l.planFullBody,
        ),
      );
    }
    return _habitSheet(
      UserHabit(
        id: slot,
        title: '',
        anchor: HabitAnchor.breakfast,
        minutes: UserHabit.minuteChoices[1],
      ),
    );
  }

  Future<void> _openDriver(Driver d) {
    final l = AppLocalizations.of(context);
    final c = ref.read(driverCompletionProvider);
    return _sheet(
      _InfoSheet(
        key: Key('plan-driver-sheet-${d.index}'),
        title: d.label,
        body: c == null
            ? l.planDriverBodyEmpty
            : l.planDriverBody((c[d.index] * 100).round()),
      ),
    );
  }

  Future<void> _about(PlanHabit h) {
    final l = AppLocalizations.of(context);
    final step = ref.read(todayStepProvider);
    final body = [
      h.driver,
      if (h.id == todayStepHabitId && step != null) step.reason,
      if (h.microstep != null) l.planMicrostep(h.microstep!),
    ].where((s) => s.isNotEmpty).join('\n\n');
    return _sheet(
      _InfoSheet(
        key: const Key('plan-habit-about'),
        title: h.title,
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final habits = ref.watch(planHabitsProvider);
    final now = ref.watch(clockProvider)();
    final step = ref.watch(todayStepProvider);
    final progress = ref.watch(stepProgressProvider);
    final checkIn = ref.watch(todayCheckInProvider).value;
    // A gentle day already uses the smaller step (as on Home).
    final canShrink =
        step?.smallerTitle != null &&
        !progress.smaller &&
        !progress.done &&
        !(checkIn?.gentleDay ?? false);
    return LwScreen(
      eyebrow: l.planEyebrow,
      title: l.tabPlan,
      icons: [
        IconButton(
          key: const Key('plan-week'),
          tooltip: l.planWeekOpen,
          onPressed: () => _sheet(const _WeekSheet()),
          icon: Icon(Icons.calendar_month_outlined, color: p.textPrimary),
        ),
      ],
      profile: const ProfileButton(),
      actions: [
        FilledButton.icon(
          key: const Key('plan-new-habit'),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            minimumSize: const Size(LwSize.minTapTarget, LwSize.minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: LwSpacing.md),
          ),
          onPressed: () => _newHabit(habits),
          icon: const Icon(Icons.add),
          label: Text(l.planNewHabit),
        ),
      ],
      children: [
        Card(
          key: const Key('plan-map'),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.planMapTitle, style: t.titleMedium),
                ),
                Text(l.planMapSubtitle, style: t.bodySmall),
                const SizedBox(height: LwSpacing.md),
                LiveWellMap(
                  drivers: ref.watch(driversProvider),
                  completion: ref.watch(driverCompletionProvider),
                  onOpen: _openDriver,
                ),
              ],
            ),
          ),
        ),
        LwSectionHeader(l.planGoalTitle),
        _GoalCard(
          goal: ref.watch(planGoalProvider),
          // Dev preview shows a sample goal: nothing to change.
          onEdit: ref.watch(previewModeProvider) ? null : _editGoal,
        ),
        LwSectionHeader(l.planHabitsTitle),
        if (habits.isEmpty)
          LwEmptyState(
            icon: Icons.flag_outlined,
            title: l.planEmptyTitle,
            body: l.planEmptyBody,
          )
        else
          Card(
            key: const Key('plan-habits'),
            child: Column(
              children: [
                for (final (i, h) in habits.indexed) ...[
                  if (i > 0) const Divider(indent: LwSpacing.md),
                  _HabitRow(
                    habit: h,
                    onDone: () => _markDone(h),
                    onAbout: () => _about(h),
                    onChange: h.own ? () => _changeHabit(h) : null,
                    onSmaller: h.id == todayStepHabitId && canShrink
                        ? () => ref
                              .read(stepProgressActionsProvider)
                              .makeSmaller()
                        : null,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: LwSpacing.sectionGap),
        const _RoutineRow(),
        const SizedBox(height: LwSpacing.sm),
        const _FrameworkRow(),
        const SizedBox(height: LwSpacing.sm),
        _AffirmationCard(now),
      ],
    );
  }
}

/// The habit id of today's step on the Plan tab.
const todayStepHabitId = 'today-step';

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onEdit});

  final PlanGoal? goal;

  /// Null in dev preview (a sample goal).
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final g = goal;
    return Card(
      key: const Key('plan-goal'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Illustration('icon_goal', width: 48, height: 48),
            const SizedBox(width: LwSpacing.sm),
            Expanded(
              child: g == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.planGoalEmpty, style: t.bodyMedium),
                        if (onEdit != null) ...[
                          const SizedBox(height: LwSpacing.xs),
                          FilledButton(
                            key: const Key('plan-goal-set'),
                            onPressed: onEdit,
                            child: Text(l.goalSetCta),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(g.title, style: t.titleMedium),
                            ),
                            if (onEdit != null)
                              Semantics(
                                label: l.planGoalEditLabel,
                                button: true,
                                container: true,
                                excludeSemantics: true,
                                child: TextButton(
                                  key: const Key('plan-goal-edit'),
                                  onPressed: onEdit,
                                  child: Text(l.planGoalEdit),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: LwSpacing.xs),
                        if (g.paused)
                          Text(
                            l.goalPausedNote,
                            key: const Key('plan-goal-paused'),
                            style: t.bodyMedium,
                          )
                        else
                          Semantics(
                            container: true,
                            excludeSemantics: true,
                            label: l.planGoalProgressLabel(
                              g.day,
                              PlanGoal.days,
                              (g.progress * 100).round(),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: LwRadius.pillAll,
                                  child: LinearProgressIndicator(
                                    value: g.progress,
                                    minHeight: LwSpacing.xs,
                                    color: p.accent,
                                    backgroundColor: p.surfaceMuted,
                                  ),
                                ),
                                const SizedBox(height: LwSpacing.xxs),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: LwSpacing.sm,
                                  children: [
                                    Text(
                                      l.planGoalDay(g.day, PlanGoal.days),
                                      style: t.labelSmall,
                                    ),
                                    Text(
                                      l.planGoalPercent(
                                        (g.progress * 100).round(),
                                      ),
                                      style: t.labelSmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One checklist row: round tick, the habit, and a "..." menu.
class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.onDone,
    required this.onAbout,
    required this.onSmaller,
    this.onChange,
  });

  final PlanHabit habit;
  final VoidCallback onDone;
  final VoidCallback onAbout;
  final VoidCallback? onSmaller;

  /// The person's own habit: change or stop it.
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final h = habit;
    final done = h.status == HabitStatus.done;
    String time(TimeOfDay d) => ml.formatTimeOfDay(d);
    final (statusText, statusColor) = switch (h.status) {
      HabitStatus.done => (l.planStatusDone, p.success),
      HabitStatus.inProgress => (l.planStatusInProgress, p.primaryDark),
      HabitStatus.scheduled => (l.planStatusScheduled, p.textSecondary),
    };
    final role = h.role == HabitRole.microhabit
        ? l.planRoleMicrohabit
        : l.planRoleSupporting;
    return Padding(
      key: Key('habit-${h.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: LwSpacing.xs,
        vertical: LwSpacing.xxs,
      ),
      child: Row(
        children: [
          if (done)
            Semantics(
              label: l.planStatusDone,
              child: SizedBox(
                width: LwSize.minTapTarget,
                height: LwSize.minTapTarget,
                child: Icon(
                  Icons.check_circle,
                  color: p.primary,
                  size: LwSize.iconMd,
                ),
              ),
            )
          else
            IconButton(
              key: Key('habit-${h.id}-done'),
              tooltip: l.planMarkDone(h.title),
              onPressed: onDone,
              icon: Icon(
                Icons.radio_button_unchecked,
                color: p.outlineStrong,
                size: LwSize.iconMd,
              ),
            ),
          const SizedBox(width: LwSpacing.xxs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: LwSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.title,
                    style: t.titleSmall?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? p.textSecondary : p.textPrimary,
                    ),
                  ),
                  Text(
                    '$role · $statusText',
                    key: Key('habit-${h.id}-status'),
                    style: t.labelSmall?.copyWith(color: statusColor),
                  ),
                  if (h.minutes != null)
                    Text(l.planMinutes(h.minutes!), style: t.labelSmall),
                  if (done && h.completedAt != null)
                    Text(
                      l.planCompletedAt(time(h.completedAt!)),
                      style: t.bodySmall,
                    )
                  else if (h.target != null)
                    Text(l.planTarget(time(h.target!)), style: t.bodySmall),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: Key('habit-${h.id}-menu'),
            tooltip: l.planHabitMenu(h.title),
            icon: Icon(Icons.more_horiz, color: p.textSecondary),
            onSelected: (v) => switch (v) {
              'smaller' => onSmaller?.call(),
              'change' => onChange?.call(),
              _ => onAbout(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'about', child: Text(l.planHabitAbout)),
              if (onChange != null)
                PopupMenuItem(
                  key: const Key('habit-menu-change'),
                  value: 'change',
                  child: Text(l.habitChange),
                ),
              if (onSmaller != null)
                PopupMenuItem(
                  key: const Key('habit-menu-smaller'),
                  value: 'smaller',
                  child: Text(l.planHabitSmaller),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// My Daily Routine (T-GOL-03b): today's progress, opens the routine.
class _RoutineRow extends ConsumerWidget {
  const _RoutineRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final today = ref.watch(todayRoutineProvider);
    return Semantics(
      button: true,
      container: true,
      label: l.routinePlanOpenLabel,
      child: Material(
        key: const Key('plan-routine'),
        color: p.mint,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(RoutineScreen.path),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.wb_sunny_outlined,
                    color: p.primaryDark,
                    size: LwSize.iconMd,
                  ),
                ),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.routinePlanTitle,
                        style: t.titleSmall?.copyWith(color: p.onTint),
                      ),
                      Text(
                        today.total == 0
                            ? l.routinePlanBody
                            : l.routinePlanProgress(today.done, today.total),
                        key: const Key('plan-routine-progress'),
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.onTint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// MY GOAL DO IT stays reachable from Plan (FR-GOL-06).
class _FrameworkRow extends StatelessWidget {
  const _FrameworkRow();

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      container: true,
      label: l.planFrameworkChipLabel,
      excludeSemantics: true,
      child: Material(
        key: const Key('plan-framework'),
        color: p.lavender,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(PlanScreen.frameworkPath),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Row(
              children: [
                const Illustration('icon_reflection', width: 44, height: 44),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.planFrameworkRow,
                        style: t.titleSmall?.copyWith(color: p.onTint),
                      ),
                      Text(
                        l.planFrameworkRowBody,
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.onTint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One kind thought a day, picked by date so it stays the same all day.
/// Wording in content/copy/affirmations.md (needs human review).
/// The day's thought: the same one all day, by the day of the year.
String affirmationFor(AppLocalizations l, DateTime now) {
  final lines = [
    l.planAffirmation1,
    l.planAffirmation2,
    l.planAffirmation3,
    l.planAffirmation4,
    l.planAffirmation5,
  ];
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(now.year)).inDays;
  return lines[day % lines.length];
}

class _AffirmationCard extends StatelessWidget {
  const _AffirmationCard(this.now);
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('plan-affirmation'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(color: p.mint, borderRadius: LwRadius.lgAll),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.eco_outlined, color: p.primaryDark),
          ),
          const SizedBox(width: LwSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.planAffirmationLabel.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: p.primaryDark),
                ),
                const SizedBox(height: LwSpacing.xxs),
                Text(
                  '“${affirmationFor(l, now)}”',
                  style: t.titleMedium?.copyWith(color: p.onTint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The week ahead from the plan (calendar button).
class _WeekSheet extends ConsumerWidget {
  const _WeekSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final days = ref.watch(weekPlanProvider).value;
    final today = localDateKey(ref.watch(clockProvider)());
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('plan-week-sheet'),
        padding: const EdgeInsets.fromLTRB(
          LwSpacing.lg,
          0,
          LwSpacing.lg,
          LwSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.planWeekTitle, style: t.titleLarge),
            const SizedBox(height: LwSpacing.sm),
            if (days == null)
              const Center(child: CircularProgressIndicator())
            else if (days.isEmpty)
              Text(l.planWeekEmpty, style: t.bodyMedium)
            else
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(bottom: LwSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.all(LwSpacing.sm),
                    decoration: BoxDecoration(
                      color: d.date == today ? p.mint : p.surfaceMuted,
                      borderRadius: LwRadius.mdAll,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: LwSize.minTapTarget * 1.5,
                          child: Text(
                            d.date == today
                                ? l.planWeekToday
                                : l.planDay(d.dayNumber),
                            style: t.labelMedium?.copyWith(
                              color: p.primaryDark,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d.title,
                            style: t.bodyMedium?.copyWith(color: p.onTint),
                          ),
                        ),
                        Text(l.planMinutes(d.minutes), style: t.labelSmall),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LwSpacing.lg,
          0,
          LwSpacing.lg,
          LwSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: t.titleLarge),
            const SizedBox(height: LwSpacing.xs),
            Text(body, style: t.bodyMedium),
            const SizedBox(height: LwSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).planGotIt),
            ),
          ],
        ),
      ),
    );
  }
}
