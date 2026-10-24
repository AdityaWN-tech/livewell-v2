import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/routine.dart';
import '../domain/routine_catalog.dart';
import '../domain/routine_editing.dart';

/// Sheets of the My Daily Routine screen (T-GOL-03b).

/// The drawing for each routine icon id ([routineIcons]).
const routineIconData = <String, IconData>{
  'sunrise': Icons.wb_twilight,
  'water': Icons.water_drop_outlined,
  'stretch': Icons.self_improvement,
  'walk': Icons.directions_walk,
  'breathe': Icons.air,
  'breakfast': Icons.free_breakfast_outlined,
  'pause': Icons.coffee_outlined,
  'family': Icons.family_restroom,
  'book': Icons.menu_book_outlined,
  'quiet': Icons.spa_outlined,
  'screen_off': Icons.phonelink_off,
  'moon': Icons.nightlight_outlined,
  'bed': Icons.bed_outlined,
  'star': Icons.star_outline,
  'heart': Icons.favorite_outline,
  'music': Icons.music_note_outlined,
};

IconData iconFor(String id) => routineIconData[id] ?? Icons.star_outline;

/// "Mon" / "Monday" in the app's language. 2026-10-19 is a Monday.
String dayName(BuildContext context, Weekday d, {bool short = false}) {
  final locale = Localizations.localeOf(context).toString();
  final date = DateTime(2026, 10, 19 + d.index);
  return (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(date);
}

/// "7:15 AM" in the device's format.
String timeLabel(BuildContext context, String hhmm) {
  final m = minutesOf(hhmm);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: m ~/ 60, minute: m % 60),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  LwSpacing.lg,
                  0,
                  LwSpacing.lg,
                  LwSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: t.titleLarge),
                    ),
                    const SizedBox(height: LwSpacing.sm),
                    ...children,
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LwSpacing.lg,
                  0,
                  LwSpacing.lg,
                  LwSpacing.md,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// What "Add to my routine" picked: a catalog activity, or null for Custom.
class AddChoice {
  const AddChoice(this.activity);
  final CatalogActivity? activity;
}

/// The catalog as a grid, plus Custom.
class AddSheet extends StatelessWidget {
  const AddSheet({
    super.key,
    required this.catalog,
    required this.activityLimited,
  });

  final RoutineCatalog catalog;
  final bool? activityLimited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _SheetFrame(
      key: const Key('routine-add-sheet'),
      title: l.routineAddTitle,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            // Two columns on small phones and large text, three otherwise.
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = c.maxWidth < 360 || scale > 1.3 ? 2 : 3;
            final width = (c.maxWidth - LwSpacing.xs * (columns - 1)) / columns;
            return Wrap(
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xs,
              children: [
                for (final a in catalog.activities)
                  _Tile(
                    key: Key('routine-add-${a.id}'),
                    width: width,
                    icon: iconFor(a.icon),
                    label: a.label,
                    note:
                        catalog.needsClinicianCheck(
                          a,
                          activityLimited: activityLimited,
                        )
                        ? l.routineClinicianFirst
                        : null,
                    onTap: () => Navigator.of(context).pop(AddChoice(a)),
                  ),
                _Tile(
                  key: const Key('routine-add-custom'),
                  width: width,
                  icon: Icons.edit_outlined,
                  label: l.routineCustom,
                  note: l.routineCustomBody,
                  onTap: () => Navigator.of(context).pop(const AddChoice(null)),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
    this.note,
  });

  final double width;
  final IconData icon;
  final String label;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Material(
        color: p.mint,
        borderRadius: LwRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: p.primaryDark, size: LwSize.iconMd),
                  const SizedBox(height: LwSpacing.xs),
                  Text(label, style: t.titleSmall?.copyWith(color: p.onTint)),
                  if (note != null)
                    Text(
                      note!,
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

/// What the label check says before a custom item is saved (T-GOL-03c).
sealed class LabelOutcome {
  const LabelOutcome();
}

class LabelAccepted extends LabelOutcome {
  const LabelAccepted();
}

/// Not saved; [message] shows in the sheet and the words can be changed.
class LabelTryAgain extends LabelOutcome {
  const LabelTryAgain(this.message);
  final String message;
}

/// A safety response was shown: the sheet closes without saving.
class LabelStopped extends LabelOutcome {
  const LabelStopped();
}

/// Add or edit one step: label and icon (custom only), time, length, days,
/// reminder and the coach's announcement. Pops the edited item. A custom
/// label goes through [checkLabel] first.
class ItemSheet extends StatefulWidget {
  const ItemSheet({
    super.key,
    required this.item,
    required this.days,
    required this.isNew,
    required this.checkLabel,
    this.clinicianNote = false,
  });

  final Future<LabelOutcome> Function(String label) checkLabel;

  final RoutineItem item;

  /// The days it falls on now.
  final Set<Weekday> days;
  final bool isNew;

  /// Movement for someone whose activity is limited (FR-GOL-03).
  final bool clinicianNote;

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  late final _label = TextEditingController(text: widget.item.label);
  late String _icon = widget.item.icon;
  late String _time = widget.item.time;
  late int _minutes = widget.item.durationMin;
  late Set<Weekday> _days = {...widget.days};
  late bool _reminder = widget.item.reminder;
  late bool _announce = widget.item.avatarAnnounce;
  String? _error;
  bool _checking = false;

  static const _lengths = [2, 5, 10, 15, 20, 30, 45, 60];

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final m = minutesOf(_time);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    setState(() => _time = '${two(picked.hour)}:${two(picked.minute)}');
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final label = widget.item.custom ? _label.text.trim() : widget.item.label;
    if (label.isEmpty) {
      setState(() => _error = l.routineLabelEmpty);
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = l.routineDaysNone);
      return;
    }
    if (widget.item.custom) {
      setState(() => _checking = true);
      final outcome = await widget.checkLabel(label);
      if (!mounted) return;
      setState(() => _checking = false);
      switch (outcome) {
        case LabelTryAgain(:final message):
          setState(() => _error = message);
          return;
        case LabelStopped():
          Navigator.of(context).pop();
          return;
        case LabelAccepted():
      }
    }
    final item = widget.item.copyWith(
      label: label,
      icon: _icon,
      time: _time,
      durationMin: _minutes,
      reminder: _reminder,
      avatarAnnounce: _announce,
      days: _days,
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final custom = widget.item.custom;
    final lengths = {..._lengths, _minutes}.toList()..sort();
    final icons = routineIcons.toList();
    return _SheetFrame(
      key: const Key('routine-item-sheet'),
      title: widget.isNew
          ? (custom ? l.routineNewTitle : widget.item.label)
          : l.routineEditTitle,
      footer: FilledButton(
        key: const Key('routine-item-save'),
        onPressed: _checking ? null : _save,
        child: Text(l.routineSave),
      ),
      children: [
        if (!widget.isNew && !custom)
          Text(widget.item.label, style: t.titleMedium),
        if (widget.clinicianNote)
          Container(
            key: const Key('routine-clinician-note'),
            margin: const EdgeInsets.only(bottom: LwSpacing.sm),
            padding: const EdgeInsets.all(LwSpacing.sm),
            decoration: BoxDecoration(
              color: p.butter,
              borderRadius: LwRadius.mdAll,
            ),
            child: Text(
              l.routineClinicianNote,
              style: t.bodyMedium?.copyWith(color: p.onTint),
            ),
          ),
        if (custom) ...[
          TextField(
            key: const Key('routine-item-label'),
            controller: _label,
            maxLength: customLabelMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.routineLabelField,
              hintText: l.routineLabelHint,
            ),
          ),
          Text(l.routineIconField, style: t.titleSmall),
          const SizedBox(height: LwSpacing.xs),
          Wrap(
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xs,
            children: [
              for (final (n, id) in icons.indexed)
                Semantics(
                  label: l.routineIconOption(n + 1, icons.length),
                  selected: _icon == id,
                  button: true,
                  excludeSemantics: true,
                  child: IconButton.outlined(
                    key: Key('routine-icon-$id'),
                    isSelected: _icon == id,
                    onPressed: () => setState(() => _icon = id),
                    icon: Icon(iconFor(id)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: LwSpacing.md),
        ],
        ListTile(
          key: const Key('routine-item-time'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(l.routineTimeField),
          trailing: Text(timeLabel(context, _time), style: t.titleMedium),
          onTap: _pickTime,
        ),
        Text(l.routineDurationField, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final m in lengths)
              ChoiceChip(
                key: Key('routine-length-$m'),
                label: Text(l.planMinutes(m)),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.md),
        Text(l.routineDaysField, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final d in Weekday.values)
              FilterChip(
                key: Key('routine-day-${d.name}'),
                label: Text(dayName(context, d, short: true)),
                tooltip: dayName(context, d),
                selected: _days.contains(d),
                onSelected: (on) => setState(
                  () => _days = on ? {..._days, d} : (_days..remove(d)),
                ),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.sm),
        SwitchListTile(
          key: const Key('routine-item-reminder'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.routineReminder),
          value: _reminder,
          onChanged: (v) => setState(() => _reminder = v),
        ),
        SwitchListTile(
          key: const Key('routine-item-announce'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.routineAnnounce),
          subtitle: custom ? Text(l.routineAnnounceCustom) : null,
          value: _announce,
          onChanged: (v) => setState(() => _announce = v),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: LwSpacing.xs),
            child: Text(
              _error!,
              key: const Key('routine-item-error'),
              style: t.bodyMedium?.copyWith(color: p.accentStrong),
            ),
          ),
      ],
    );
  }
}

/// "Copy this day to…": pick other days. Pops the chosen days.
class CopySheet extends StatefulWidget {
  const CopySheet({super.key, required this.from});

  final Weekday from;

  @override
  State<CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends State<CopySheet> {
  final _to = <Weekday>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _SheetFrame(
      key: const Key('routine-copy-sheet'),
      title: l.routineCopyTitle(dayName(context, widget.from)),
      footer: FilledButton(
        key: const Key('routine-copy-confirm'),
        onPressed: _to.isEmpty ? null : () => Navigator.of(context).pop(_to),
        child: Text(l.routineCopyAction),
      ),
      children: [
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final d in Weekday.values)
              if (d != widget.from)
                FilterChip(
                  key: Key('routine-copy-${d.name}'),
                  label: Text(dayName(context, d)),
                  selected: _to.contains(d),
                  onSelected: (on) =>
                      setState(() => on ? _to.add(d) : _to.remove(d)),
                ),
          ],
        ),
      ],
    );
  }
}

/// Quick-start templates. Pops the chosen one.
class TemplatesSheet extends StatelessWidget {
  const TemplatesSheet({super.key, required this.catalog});

  final RoutineCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _SheetFrame(
      key: const Key('routine-templates-sheet'),
      title: l.routineTemplatesTitle,
      children: [
        for (final tpl in catalog.templates)
          Card(
            child: ListTile(
              key: Key('routine-template-${tpl.id}'),
              title: Text(tpl.label),
              subtitle: Text(
                tpl.items
                    .map((i) => catalog.byId(i.$1)?.label ?? i.$1)
                    .join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(tpl),
            ),
          ),
      ],
    );
  }
}

/// What the modes sheet chose: a mode, or off (kind null).
class ModeChoice {
  const ModeChoice(this.kind);
  final ModeKind? kind;
}

/// Travel / Sick day / Busy week (FR-DLY-09).
class ModesSheet extends StatelessWidget {
  const ModesSheet({super.key, required this.current});

  final RoutineMode? current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final options = [
      (
        ModeKind.travel,
        Icons.luggage_outlined,
        l.routineModeTravel,
        l.routineModeTravelBody,
      ),
      (
        ModeKind.sick,
        Icons.healing_outlined,
        l.routineModeSick,
        l.routineModeSickBody,
      ),
      (
        ModeKind.busy,
        Icons.event_busy_outlined,
        l.routineModeBusy,
        l.routineModeBusyBody,
      ),
    ];
    return _SheetFrame(
      key: const Key('routine-modes-sheet'),
      title: l.routineModesTitle,
      children: [
        Text(l.routineModesBody, style: t.bodyMedium),
        const SizedBox(height: LwSpacing.sm),
        for (final (kind, icon, title, body) in options)
          Card(
            child: ListTile(
              key: Key('routine-mode-${kind.name}'),
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(body),
              selected: current?.kind == kind,
              onTap: () => Navigator.of(context).pop(ModeChoice(kind)),
            ),
          ),
        if (current != null)
          TextButton(
            key: const Key('routine-mode-off'),
            onPressed: () => Navigator.of(context).pop(const ModeChoice(null)),
            child: Text(l.routineModeOff),
          ),
      ],
    );
  }
}
