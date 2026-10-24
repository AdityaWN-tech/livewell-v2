import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../../home/application/home_data.dart';
import '../../home/domain/home_models.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/presentation/safety_screens.dart';
import '../application/routine_data.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';
import '../domain/routine_catalog.dart';
import '../domain/routine_editing.dart';
import 'routine_sheets.dart';

/// My Daily Routine (T-GOL-03b), from the Plan tab: the person's own steps
/// for each day of the week, with today's coach step pinned on top.
/// One primary action: "Add to my routine".
class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  static const path = '/plan/routine';

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  late Weekday _day = Weekday.of(ref.read(clockProvider)());

  RoutineActions get _actions => ref.read(routineActionsProvider);

  Future<T?> _sheet<T>(Widget child) => showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => child,
  );

  void _snack(String text, {VoidCallback? undo}) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: undo == null
              ? null
              : SnackBarAction(label: l.routineUndo, onPressed: undo),
        ),
      );
  }

  bool? get _activityLimited =>
      ref.read(currentProfileProvider).value?.activityLimited;

  Future<void> _add(RoutineCatalog catalog) async {
    final choice = await _sheet<AddChoice>(
      AddSheet(catalog: catalog, activityLimited: _activityLimited),
    );
    if (choice == null || !mounted) return;
    final order = ref.read(routineDayProvider(_day)).length;
    final a = choice.activity;
    final item = a == null
        ? RoutineItem(
            itemId: _actions.newId(),
            routineId: myRoutineId,
            label: '',
            icon: 'star',
            time: '09:00',
            durationMin: 5,
            order: order,
          )
        : catalog.newItem(
            a,
            itemId: _actions.newId(),
            routineId: myRoutineId,
            activityLimited: _activityLimited,
            order: order,
          );
    await _edit(
      item,
      isNew: true,
      days: {_day},
      clinicianNote:
          a != null &&
          catalog.needsClinicianCheck(a, activityLimited: _activityLimited),
    );
  }

  Future<void> _edit(
    RoutineItem item, {
    bool isNew = false,
    Set<Weekday>? days,
    bool clinicianNote = false,
  }) async {
    final routines = ref.read(routinesProvider).value ?? const [];
    final edited = await _sheet<RoutineItem>(
      ItemSheet(
        item: item,
        days: days ?? daysOf(item, routines),
        isNew: isNew,
        clinicianNote: clinicianNote,
      ),
    );
    if (edited == null || !mounted) return;
    if (edited.custom && !await _labelIsSafe(edited.label)) return;
    try {
      await _actions.save(edited);
    } catch (_) {
      if (mounted) _snack(AppLocalizations.of(context).routineSaveError);
    }
  }

  /// Custom labels go through the red-flag rules before they are saved
  /// (FR-SAF-01/02/04). Anything flagged shows its safety card and is not
  /// kept. More checks for routine labels come in GOL-03c.
  Future<bool> _labelIsSafe(String label) async {
    final rules = await ref.read(safetyRulesProvider.future);
    final result = rules.check(label);
    if (result.isClear) return true;
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    final region = uid == null
        ? null
        : (await ref.read(profileRepositoryProvider).get(uid))?.region;
    if (!mounted) return false;
    await showSafetyResponse(context, result, rules.contactsFor(region));
    if (mounted) _snack(AppLocalizations.of(context).routineLabelNotSaved);
    return false;
  }

  Future<void> _delete(RoutineItem item) async {
    final l = AppLocalizations.of(context);
    await _actions.delete(item);
    if (!mounted) return;
    _snack(l.routineDeleted(item.label), undo: () => _actions.save(item));
  }

  Future<void> _removeFromDay(RoutineItem item) async {
    final l = AppLocalizations.of(context);
    final day = dayName(context, _day);
    await _actions.removeFromDay(item, _day);
    if (!mounted) return;
    _snack(
      l.routineRemovedFromDay(item.label, day),
      undo: () => _actions.save(item),
    );
  }

  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    final to = await _sheet<Set<Weekday>>(CopySheet(from: _day));
    if (to == null || !mounted) return;
    final full = await _actions.copyDay(_day, to);
    if (!mounted) return;
    _snack(
      full.isEmpty
          ? l.routineCopied
          : l.routineCopyFull(
              [for (final d in full) dayName(context, d)].join(', '),
            ),
    );
  }

  Future<void> _templates(RoutineCatalog catalog) async {
    final l = AppLocalizations.of(context);
    final tpl = await _sheet<RoutineTemplate>(TemplatesSheet(catalog: catalog));
    if (tpl == null || !mounted) return;
    final skipped = await _actions.applyTemplate(tpl, catalog, _day);
    if (!mounted) return;
    _snack(
      [
        l.routineTemplateApplied(tpl.label),
        if (skipped > 0) l.routineTemplateSkipped(skipped),
      ].join(' '),
    );
  }

  Future<void> _modes() async {
    final choice = await _sheet<ModeChoice>(ModesSheet(current: _activeMode()));
    if (choice == null || !mounted) return;
    await _actions.setMode(choice.kind);
  }

  RoutineMode? _activeMode() {
    final mode = ref.read(routineModeProvider);
    final today = localDateKey(ref.read(clockProvider)());
    return mode != null && mode.activeOn(today) ? mode : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final today = Weekday.of(now);
    final todayKey = localDateKey(now);
    final isToday = _day == today;
    final catalog = ref.watch(routineCatalogProvider).value;
    final day = ref.watch(routineDayProvider(_day));
    final mode = ref.watch(routineModeProvider);
    final modeOn = mode != null && mode.activeOn(todayKey);
    // Today's mode shapes today; other days show the full routine.
    final running = isToday
        ? activeItems(day, mode, todayKey).toSet()
        : day.toSet();
    final logs = isToday
        ? ref.watch(routineLogsProvider(todayKey)).value ?? const {}
        : const <String, RoutineLog>{};
    final step = isToday ? ref.watch(todayStepProvider) : null;
    final full = day.length >= maxItemsPerDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.routineTitle),
        actions: [
          PopupMenuButton<String>(
            key: const Key('routine-more'),
            tooltip: l.routineMoreMenu,
            onSelected: (v) => switch (v) {
              'copy' => _copy(),
              'templates' => catalog == null ? null : _templates(catalog),
              _ => _modes(),
            },
            itemBuilder: (context) => [
              if (day.isNotEmpty)
                PopupMenuItem(
                  key: const Key('routine-menu-copy'),
                  value: 'copy',
                  child: Text(l.routineCopyDay),
                ),
              PopupMenuItem(
                key: const Key('routine-menu-templates'),
                value: 'templates',
                child: Text(l.routineTemplates),
              ),
              PopupMenuItem(
                key: const Key('routine-menu-modes'),
                value: 'modes',
                child: Text(l.routineModesMenu),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.screenGutter,
            LwSpacing.xs,
            LwSpacing.screenGutter,
            LwSpacing.sm,
          ),
          child: FilledButton.icon(
            key: const Key('routine-add'),
            onPressed: catalog == null || full ? null : () => _add(catalog),
            icon: const Icon(Icons.add),
            label: Text(l.routineAdd),
          ),
        ),
      ),
      body: ListView(
        key: const Key('routine-list'),
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(l.routineIntro, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.sm),
          if (modeOn) ...[
            _ModeBanner(mode: mode, onEnd: () => _actions.setMode(null)),
            const SizedBox(height: LwSpacing.sm),
          ],
          _DayTabs(
            selected: _day,
            today: today,
            onSelect: (d) => setState(() => _day = d),
          ),
          const SizedBox(height: LwSpacing.md),
          if (step != null) ...[
            _CoachStepRow(step: step),
            const SizedBox(height: LwSpacing.xs),
          ],
          for (final time in clashes(day))
            Padding(
              padding: const EdgeInsets.only(bottom: LwSpacing.xs),
              child: _Hint(l.routineClash(timeLabel(context, time))),
            ),
          if (full)
            Padding(
              padding: const EdgeInsets.only(bottom: LwSpacing.xs),
              child: _Hint(l.routineDayFull, key: const Key('routine-full')),
            ),
          if (day.isEmpty)
            _Empty(
              catalog: catalog,
              onTemplate: (tpl) async {
                final skipped = await _actions.applyTemplate(
                  tpl,
                  catalog!,
                  _day,
                );
                if (!context.mounted) return;
                _snack(
                  [
                    l.routineTemplateApplied(tpl.label),
                    if (skipped > 0) l.routineTemplateSkipped(skipped),
                  ].join(' '),
                );
              },
            )
          else
            Card(
              key: const Key('routine-timeline'),
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                // newIndex is already where it lands without the moved item.
                onReorderItem: (oldIndex, newIndex) =>
                    _actions.reorder(day, oldIndex, newIndex),
                children: [
                  for (final (n, i) in day.indexed)
                    _ItemRow(
                      key: Key('routine-item-${i.itemId}'),
                      index: n,
                      item: i,
                      isToday: isToday,
                      resting: !running.contains(i),
                      status: logs[i.itemId]?.status,
                      multiDay:
                          daysOf(
                            i,
                            ref.watch(routinesProvider).value ?? const [],
                          ).length >
                          1,
                      dayLabel: dayName(context, _day),
                      onDone: () => _actions.mark(i, RoutineStatus.done),
                      onSkip: () => _actions.mark(i, RoutineStatus.skipped),
                      onEdit: () => _edit(i),
                      onRemoveFromDay: () => _removeFromDay(i),
                      onDelete: () => _delete(i),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayTabs extends StatelessWidget {
  const _DayTabs({
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final Weekday selected;
  final Weekday today;
  final ValueChanged<Weekday> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    return Wrap(
      key: const Key('routine-days'),
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xs,
      children: [
        for (final d in Weekday.values)
          Semantics(
            label: l.routineDayLabel(dayName(context, d)),
            selected: d == selected,
            button: true,
            excludeSemantics: true,
            child: ChoiceChip(
              key: Key('routine-tab-${d.name}'),
              label: Text(
                d == today ? l.planWeekToday : dayName(context, d, short: true),
              ),
              selected: d == selected,
              selectedColor: p.primaryTint,
              onSelected: (_) => onSelect(d),
            ),
          ),
      ],
    );
  }
}

/// Today's step from the coach's plan, pinned on top. Done is shared with
/// Home; the step is changed through the plan, not here.
class _CoachStepRow extends ConsumerWidget {
  const _CoachStepRow({required this.step});

  final TodayStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final done = ref.watch(stepProgressProvider).done;
    final title = step.title;
    final minutes = step.minutes;
    return Container(
      key: const Key('routine-coach-step'),
      padding: const EdgeInsets.all(LwSpacing.xs),
      decoration: BoxDecoration(
        color: p.lavender,
        borderRadius: LwRadius.lgAll,
      ),
      child: Row(
        children: [
          _Check(
            key: const Key('routine-coach-step-done'),
            label: title,
            done: done,
            onDone: () => ref.read(stepProgressActionsProvider).markDone(),
          ),
          const SizedBox(width: LwSpacing.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.routineFromCoach.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: p.onTintSecondary),
                ),
                Text(title, style: t.titleSmall?.copyWith(color: p.onTint)),
                Text(
                  l.planMinutes(minutes),
                  style: t.labelSmall?.copyWith(color: p.onTintSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    super.key,
    required this.label,
    required this.done,
    required this.onDone,
  });

  final String label;
  final bool done;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    if (done) {
      return Semantics(
        label: l.routineDone,
        child: SizedBox(
          width: LwSize.minTapTarget,
          height: LwSize.minTapTarget,
          child: Icon(
            Icons.check_circle,
            color: p.primary,
            size: LwSize.iconMd,
          ),
        ),
      );
    }
    return IconButton(
      tooltip: l.routineMarkDone(label),
      onPressed: onDone,
      icon: Icon(
        Icons.radio_button_unchecked,
        color: p.outlineStrong,
        size: LwSize.iconMd,
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.isToday,
    required this.resting,
    required this.status,
    required this.multiDay,
    required this.dayLabel,
    required this.onDone,
    required this.onSkip,
    required this.onEdit,
    required this.onRemoveFromDay,
    required this.onDelete,
  });

  final int index;
  final RoutineItem item;
  final bool isToday;

  /// Quiet today because of a life-event mode.
  final bool resting;
  final RoutineStatus? status;
  final bool multiDay;
  final String dayLabel;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onEdit;
  final VoidCallback onRemoveFromDay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final done = status == RoutineStatus.done;
    final skipped = status == RoutineStatus.skipped;
    final quiet = resting || skipped;
    final note = resting
        ? l.routineResting
        : skipped
        ? l.routineSkipped
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LwSpacing.xxs,
        vertical: LwSpacing.xxs,
      ),
      child: Row(
        children: [
          if (isToday && !quiet)
            _Check(
              key: Key('routine-item-${item.itemId}-done'),
              label: item.label,
              done: done,
              onDone: onDone,
            )
          else
            SizedBox(
              width: LwSize.minTapTarget,
              child: Text(
                timeLabel(context, item.time),
                style: t.labelSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ExcludeSemantics(
            child: Icon(
              iconFor(item.icon),
              color: quiet ? p.textDisabled : p.primaryDark,
              size: LwSize.iconMd,
            ),
          ),
          const SizedBox(width: LwSpacing.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: LwSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: t.titleSmall?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done || quiet ? p.textSecondary : p.textPrimary,
                    ),
                  ),
                  Text(
                    [
                      if (isToday && !quiet) timeLabel(context, item.time),
                      l.planMinutes(item.durationMin),
                      ?note,
                    ].join(' · '),
                    style: t.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: Key('routine-item-${item.itemId}-menu'),
            tooltip: l.routineItemMenu(item.label),
            icon: Icon(Icons.more_horiz, color: p.textSecondary),
            onSelected: (v) => switch (v) {
              'edit' => onEdit(),
              'skip' => onSkip(),
              'remove_day' => onRemoveFromDay(),
              _ => onDelete(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(l.routineEdit)),
              if (isToday && status == null && !resting)
                PopupMenuItem(
                  key: const Key('routine-menu-skip'),
                  value: 'skip',
                  child: Text(l.routineSkipToday),
                ),
              if (multiDay)
                PopupMenuItem(
                  key: const Key('routine-menu-remove-day'),
                  value: 'remove_day',
                  child: Text(l.routineRemoveFromDay(dayLabel)),
                ),
              PopupMenuItem(
                key: const Key('routine-menu-delete'),
                value: 'delete',
                child: Text(l.routineDelete),
              ),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.xs),
              child: Icon(Icons.drag_indicator, color: p.textDisabled),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.mode, required this.onEnd});

  final RoutineMode mode;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final until = DateFormat.MMMEd(Localizations.localeOf(context).toString())
        .format(DateTime.parse(mode.until));
    final text = switch (mode.kind) {
      ModeKind.travel => l.routineModeBannerTravel(until),
      ModeKind.sick => l.routineModeBannerSick,
      ModeKind.busy => l.routineModeBannerBusy(until),
    };
    return Container(
      key: const Key('routine-mode-banner'),
      padding: const EdgeInsets.fromLTRB(
        LwSpacing.md,
        LwSpacing.xs,
        LwSpacing.xs,
        LwSpacing.xs,
      ),
      decoration: BoxDecoration(color: p.sky, borderRadius: LwRadius.lgAll),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: t.bodyMedium?.copyWith(color: p.onTint)),
          ),
          TextButton(
            key: const Key('routine-mode-end'),
            onPressed: onEnd,
            child: Text(l.routineModeEnd),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(LwSpacing.sm),
      decoration: BoxDecoration(color: p.butter, borderRadius: LwRadius.mdAll),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.lightbulb_outline, color: p.onTint),
          ),
          const SizedBox(width: LwSpacing.xs),
          Expanded(
            child: Text(text, style: t.bodyMedium?.copyWith(color: p.onTint)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.catalog, required this.onTemplate});

  final RoutineCatalog? catalog;
  final ValueChanged<RoutineTemplate> onTemplate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const Key('routine-empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LwEmptyState(
          icon: Icons.wb_sunny_outlined,
          title: l.routineEmptyTitle,
          body: l.routineEmptyBody,
        ),
        LwSectionHeader(l.routineTemplatesTitle),
        for (final tpl in catalog?.templates ?? const <RoutineTemplate>[])
          Card(
            child: ListTile(
              key: Key('routine-empty-template-${tpl.id}'),
              title: Text(tpl.label),
              subtitle: Text(
                tpl.items
                    .map((i) => catalog!.byId(i.$1)?.label ?? i.$1)
                    .join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTemplate(tpl),
            ),
          ),
      ],
    );
  }
}
