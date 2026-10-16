import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_button.dart';
import '../application/plan_data.dart';
import '../domain/plan_models.dart';

/// Plan tab (T-UI-01c, Screen 2): today's habits, the "+ New habit" button
/// with the FR-GOL-01 limits, the MY GOAL DO IT entry (FR-GOL-06) and a
/// daily affirmation.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  static const frameworkPath = '/plan/framework';

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  /// Habits ticked off on this screen.
  // TODO(T-GOL-01): save to users/{uid}/habit_logs instead.
  final _doneNow = <String, TimeOfDay>{};

  List<PlanHabit> _habits() => [
    for (final h in ref.watch(planHabitsProvider))
      _doneNow.containsKey(h.id)
          ? h.copyWith(status: HabitStatus.done, completedAt: _doneNow[h.id])
          : h,
  ];

  Future<void> _newHabit(List<PlanHabit> habits) {
    final l = AppLocalizations.of(context);
    final full = HabitLimits.isFull(habits);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _InfoSheet(
        key: Key(full ? 'plan-full' : 'plan-add-soon'),
        title: full ? l.planFullTitle : l.planAddSoonTitle,
        body: full ? l.planFullBody : l.planAddSoonBody,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final habits = _habits();
    final now = ref.watch(clockProvider)();
    return LwScreen(
      eyebrow: l.planEyebrow,
      title: l.tabPlan,
      profile: const ProfileButton(),
      actions: [
        FilledButton.icon(
          key: const Key('plan-new-habit'),
          style: FilledButton.styleFrom(
            backgroundColor: LwPalette.of(context).primary,
            foregroundColor: LwPalette.of(context).onPrimary,
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
        const Align(alignment: Alignment.centerLeft, child: _FrameworkChip()),
        const SizedBox(height: LwSpacing.md),
        if (habits.isEmpty)
          LwEmptyState(
            icon: Icons.flag_outlined,
            title: l.planEmptyTitle,
            body: l.planEmptyBody,
          )
        else
          for (final h in habits) ...[
            _HabitCard(
              habit: h,
              onDone: () => setState(
                () => _doneNow[h.id] = TimeOfDay.fromDateTime(
                  ref.read(clockProvider)(),
                ),
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
          ],
        const SizedBox(height: LwSpacing.xs),
        _AffirmationCard(now),
      ],
    );
  }
}

class _FrameworkChip extends StatelessWidget {
  const _FrameworkChip();

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      container: true,
      label: l.planFrameworkChipLabel,
      excludeSemantics: true,
      child: Material(
        key: const Key('plan-framework'),
        color: p.primaryTint,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(PlanScreen.frameworkPath),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: LwSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(p.accent),
                  const SizedBox(width: LwSpacing.xs),
                  Flexible(
                    child: Text(
                      l.planFrameworkChip,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: p.onPrimaryTint),
                    ),
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

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.onDone});

  final PlanHabit habit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final h = habit;
    final done = h.status == HabitStatus.done;
    final active = h.status == HabitStatus.inProgress;
    String time(TimeOfDay d) => ml.formatTimeOfDay(d);

    final (statusText, statusColor) = switch (h.status) {
      HabitStatus.done => (l.planStatusDone, p.success),
      HabitStatus.inProgress => (l.planStatusInProgress, p.accentStrong),
      HabitStatus.scheduled => (l.planStatusScheduled, p.textSecondary),
    };
    final role = h.role == HabitRole.microhabit
        ? l.planRoleMicrohabit
        : l.planRoleSupporting;

    return Container(
      key: Key('habit-${h.id}'),
      decoration: BoxDecoration(
        color: done ? p.background : p.surface,
        borderRadius: LwRadius.lgAll,
        border: Border.all(
          color: active ? p.primary : p.outlineSoft,
          width: active ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: LwSpacing.xs,
                      runSpacing: LwSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LwTag(h.driver),
                        Text(
                          '$role · $statusText',
                          key: Key('habit-${h.id}-status'),
                          style: t.labelMedium?.copyWith(color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: LwSpacing.xs),
                    Text(
                      h.title,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? p.textSecondary : p.textPrimary,
                      ),
                    ),
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
              const SizedBox(width: LwSpacing.xs),
              if (done)
                Semantics(
                  label: l.planStatusDone,
                  child: Icon(
                    Icons.check_circle,
                    color: p.success,
                    size: LwSize.iconMd + LwSpacing.xs,
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
                    size: LwSize.iconMd + LwSpacing.xs,
                  ),
                ),
            ],
          ),
          if (!done && h.microstep != null) ...[
            const SizedBox(height: LwSpacing.sm),
            Divider(color: p.outlineSoft),
            const SizedBox(height: LwSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.planMicrostep(h.microstep!),
                    style: t.bodySmall,
                  ),
                ),
                if (h.minutes != null) ...[
                  const SizedBox(width: LwSpacing.sm),
                  Text(l.planMinutes(h.minutes!), style: t.labelMedium),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One kind thought a day, picked by date so it stays the same all day.
/// Wording in content/copy/affirmations.md (needs human review).
class _AffirmationCard extends StatelessWidget {
  const _AffirmationCard(this.now);
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
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
    return Container(
      key: const Key('plan-affirmation'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.primaryTint,
        borderRadius: LwRadius.lgAll,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.eco_outlined, color: p.onPrimaryTint),
          ),
          const SizedBox(width: LwSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.planAffirmationLabel.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: p.onPrimaryTint),
                ),
                const SizedBox(height: LwSpacing.xxs),
                Text(
                  '“${lines[day % lines.length]}”',
                  style: t.titleMedium?.copyWith(color: p.onPrimaryTint),
                ),
              ],
            ),
          ),
        ],
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
      child: Padding(
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
