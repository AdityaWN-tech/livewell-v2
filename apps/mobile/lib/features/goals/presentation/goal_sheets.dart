import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../routine/presentation/routine_sheets.dart'
    show LabelAccepted, LabelOutcome, LabelStopped, LabelTryAgain;
import '../domain/goal.dart';

/// Words for each anchor.
String anchorName(AppLocalizations l, HabitAnchor a) => switch (a) {
  HabitAnchor.wakeUp => l.anchorWakeUp,
  HabitAnchor.breakfast => l.anchorBreakfast,
  HabitAnchor.lunch => l.anchorLunch,
  HabitAnchor.dinner => l.anchorDinner,
  HabitAnchor.bedtime => l.anchorBedtime,
};

/// What a goal sheet ends with.
sealed class GoalSheetResult {
  const GoalSheetResult();
}

class GoalSaved extends GoalSheetResult {
  const GoalSaved(this.goal);
  final Goal goal;
}

class GoalPaused extends GoalSheetResult {
  const GoalPaused();
}

class GoalRestarted extends GoalSheetResult {
  const GoalRestarted();
}

/// Set or change the 30-day goal (FR-GOL-02): what, how often, how long,
/// when, a plan for what might get in the way, and the link to the Why.
/// Typed words go through [checkLabel] before anything is saved. An
/// existing goal can also be paused, or restarted from day 1.
class GoalSheet extends StatefulWidget {
  const GoalSheet({
    super.key,
    required this.goal,
    required this.today,
    required this.checkLabel,
  });

  /// Null: a new goal.
  final Goal? goal;

  /// yyyy-mm-dd, the start of a new goal.
  final String today;
  final Future<LabelOutcome> Function(String words) checkLabel;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  late final _action = TextEditingController(text: widget.goal?.action);
  late final _barrier = TextEditingController(text: widget.goal?.barrierPlan);
  late int _days = widget.goal?.daysPerWeek ?? 5;
  late int _minutes = widget.goal?.minutes ?? 10;
  late HabitAnchor _anchor = widget.goal?.anchor ?? HabitAnchor.breakfast;
  late bool _linkWhy = widget.goal?.linkWhy ?? true;
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _action.dispose();
    _barrier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final action = _action.text.trim();
    final barrier = _barrier.text.trim();
    if (action.isEmpty) {
      setState(() => _error = l.routineLabelEmpty);
      return;
    }
    setState(() => _checking = true);
    for (final words in [action, if (barrier.isNotEmpty) barrier]) {
      final outcome = await widget.checkLabel(words);
      if (!mounted) return;
      switch (outcome) {
        case LabelTryAgain(:final message):
          setState(() {
            _checking = false;
            _error = message;
          });
          return;
        case LabelStopped():
          Navigator.of(context).pop();
          return;
        case LabelAccepted():
      }
    }
    final goal = Goal(
      action: action,
      daysPerWeek: _days,
      minutes: _minutes,
      anchor: _anchor,
      barrierPlan: barrier,
      linkWhy: _linkWhy,
      status: widget.goal?.status ?? GoalStatus.active,
      startDate: widget.goal?.startDate ?? widget.today,
    );
    Navigator.of(context).pop(GoalSaved(goal));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final existing = widget.goal;
    return SheetFrame(
      key: const Key('goal-sheet'),
      title: existing == null ? l.goalSheetNewTitle : l.goalSheetEditTitle,
      footer: FilledButton(
        key: const Key('goal-save'),
        onPressed: _checking ? null : _save,
        child: Text(l.goalSave),
      ),
      children: [
        TextField(
          key: const Key('goal-action'),
          controller: _action,
          maxLength: goalTextMaxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.goalActionField,
            hintText: l.goalActionHint,
          ),
        ),
        Text(l.goalDaysField, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (var n = 1; n <= 7; n++)
              ChoiceChip(
                key: Key('goal-days-$n'),
                label: Text('$n'),
                tooltip: l.goalDaysValue(n),
                selected: _days == n,
                onSelected: (_) => setState(() => _days = n),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.md),
        Text(l.goalMinutesField, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final m in Goal.minuteChoices)
              ChoiceChip(
                key: Key('goal-minutes-$m'),
                label: Text(l.planMinutes(m)),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.md),
        AnchorChoice(
          keyPrefix: 'goal-anchor',
          value: _anchor,
          onChanged: (a) => setState(() => _anchor = a),
        ),
        const SizedBox(height: LwSpacing.md),
        TextField(
          key: const Key('goal-barrier'),
          controller: _barrier,
          maxLength: barrierPlanMaxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.goalBarrierField,
            hintText: l.goalBarrierHint,
          ),
        ),
        SwitchListTile(
          key: const Key('goal-link-why'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.goalLinkWhy),
          value: _linkWhy,
          onChanged: (v) => setState(() => _linkWhy = v),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: LwSpacing.xs),
            child: Text(
              _error!,
              key: const Key('goal-error'),
              style: t.bodyMedium?.copyWith(
                color: LwPalette.of(context).caution,
              ),
            ),
          ),
        if (existing != null) ...[
          const SizedBox(height: LwSpacing.md),
          if (existing.status == GoalStatus.active)
            OutlinedButton(
              key: const Key('goal-pause'),
              onPressed: () => Navigator.of(context).pop(const GoalPaused()),
              child: Text(l.goalPause),
            ),
          OutlinedButton(
            key: const Key('goal-restart'),
            onPressed: () => Navigator.of(context).pop(const GoalRestarted()),
            child: Text(l.goalRestart),
          ),
        ],
      ],
    );
  }
}

/// What a habit sheet ends with.
sealed class HabitSheetResult {
  const HabitSheetResult();
}

class HabitSaved extends HabitSheetResult {
  const HabitSaved(this.habit);
  final UserHabit habit;
}

class HabitStopped extends HabitSheetResult {
  const HabitStopped();
}

/// Add or change one of the person's own supporting habits (FR-GOL-01):
/// a few words, when in the day and how long. An existing one can be
/// stopped (kept, not deleted).
class HabitSheet extends StatefulWidget {
  const HabitSheet({super.key, required this.habit, required this.checkLabel});

  /// Its slot id is fixed; a new one has an empty title.
  final UserHabit habit;
  final Future<LabelOutcome> Function(String words) checkLabel;

  @override
  State<HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState extends State<HabitSheet> {
  late final _title = TextEditingController(text: widget.habit.title);
  late HabitAnchor _anchor = widget.habit.anchor;
  late int _minutes = widget.habit.minutes;
  String? _error;
  bool _checking = false;

  bool get _isNew => widget.habit.title.isEmpty;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l.routineLabelEmpty);
      return;
    }
    setState(() => _checking = true);
    final outcome = await widget.checkLabel(title);
    if (!mounted) return;
    switch (outcome) {
      case LabelTryAgain(:final message):
        setState(() {
          _checking = false;
          _error = message;
        });
      case LabelStopped():
        Navigator.of(context).pop();
      case LabelAccepted():
        Navigator.of(context).pop(
          HabitSaved(
            widget.habit.copyWith(
              title: title,
              anchor: _anchor,
              minutes: _minutes,
              active: true,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SheetFrame(
      key: const Key('habit-sheet'),
      title: _isNew ? l.habitSheetNewTitle : l.habitSheetEditTitle,
      footer: FilledButton(
        key: const Key('habit-save'),
        onPressed: _checking ? null : _save,
        child: Text(_isNew ? l.habitAdd : l.goalSave),
      ),
      children: [
        Text(l.habitSheetBody, style: t.bodyMedium),
        const SizedBox(height: LwSpacing.sm),
        TextField(
          key: const Key('habit-title'),
          controller: _title,
          maxLength: habitTitleMaxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.habitTitleField,
            hintText: l.habitTitleHint,
          ),
        ),
        AnchorChoice(
          keyPrefix: 'habit-anchor',
          value: _anchor,
          onChanged: (a) => setState(() => _anchor = a),
        ),
        const SizedBox(height: LwSpacing.md),
        Text(l.goalMinutesField, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final m in UserHabit.minuteChoices)
              ChoiceChip(
                key: Key('habit-minutes-$m'),
                label: Text(l.planMinutes(m)),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = m),
              ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: LwSpacing.sm),
            child: Text(
              _error!,
              key: const Key('habit-error'),
              style: t.bodyMedium?.copyWith(
                color: LwPalette.of(context).caution,
              ),
            ),
          ),
        if (!_isNew) ...[
          const SizedBox(height: LwSpacing.md),
          OutlinedButton(
            key: const Key('habit-stop'),
            onPressed: () => Navigator.of(context).pop(const HabitStopped()),
            child: Text(l.habitStop),
          ),
        ],
      ],
    );
  }
}

/// "When in your day?": one chip per anchor.
class AnchorChoice extends StatelessWidget {
  const AnchorChoice({
    super.key,
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final HabitAnchor value;
  final ValueChanged<HabitAnchor> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.goalAnchorField, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final a in HabitAnchor.values)
              ChoiceChip(
                key: Key('$keyPrefix-${a.name}'),
                label: Text(anchorName(l, a)),
                selected: value == a,
                onSelected: (_) => onChanged(a),
              ),
          ],
        ),
      ],
    );
  }
}

/// A bottom sheet's layout: title, scrolling content, a button at the
/// bottom that stays above the keyboard.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.children,
    required this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LwSpacing.screenGutter,
              ),
              child: Semantics(
                header: true,
                child: Text(title, style: t.titleLarge),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                children: children,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LwSpacing.screenGutter,
                0,
                LwSpacing.screenGutter,
                LwSpacing.md,
              ),
              child: SafeArea(top: false, child: footer),
            ),
          ],
        ),
      ),
    );
  }
}
