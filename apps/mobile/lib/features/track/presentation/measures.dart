import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../checkin/domain/checkin.dart' show localDateKey;
import '../application/track_data.dart';
import '../data/metric_repository.dart';
import '../domain/metric_point.dart';

/// The kinds shown, in order.
List<MetricKind> visibleMetricKinds({required bool edSafeMode}) => [
  for (final k in MetricKind.values)
    if (!(edSafeMode && k.hiddenInEdSafeMode)) k,
];

String healthAppName(AppLocalizations l) =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? l.healthAppleHealth
    : l.healthHealthConnect;

String metricName(AppLocalizations l, MetricKind k) => switch (k) {
  MetricKind.weight => l.metricWeight,
  MetricKind.bloodPressure => l.metricBloodPressure,
  MetricKind.glucose => l.metricGlucose,
  MetricKind.meal => l.metricMeals,
};

String metricAddTitle(AppLocalizations l, MetricKind k) => switch (k) {
  MetricKind.weight => l.metricAddWeight,
  MetricKind.bloodPressure => l.metricAddBloodPressure,
  MetricKind.glucose => l.metricAddGlucose,
  MetricKind.meal => l.metricAddMeal,
};

String mealName(AppLocalizations l, MealKind m) => switch (m) {
  MealKind.breakfast => l.mealBreakfast,
  MealKind.lunch => l.mealLunch,
  MealKind.dinner => l.mealDinner,
  MealKind.snack => l.mealSnack,
};

IconData metricIcon(MetricKind k) => switch (k) {
  MetricKind.weight => Icons.monitor_weight_outlined,
  MetricKind.bloodPressure => Icons.favorite_border,
  MetricKind.glucose => Icons.water_drop_outlined,
  MetricKind.meal => Icons.restaurant_outlined,
};

/// A weight with at most one decimal, in the locale's format.
String formatWeight(BuildContext context, double v) =>
    NumberFormat('0.#', Localizations.localeOf(context).toString()).format(v);

/// The value as entered, with its unit ("72.5 kg", "120/80 mmHg").
String formatPoint(BuildContext context, MetricPoint p) {
  final l = AppLocalizations.of(context);
  return switch (p.kind) {
    MetricKind.weight => l.metricValueUnit(
      formatWeight(context, p.value!),
      p.weightUnit!.id,
    ),
    MetricKind.bloodPressure => l.metricBpValue(
      '${p.systolic}',
      '${p.diastolic}',
      MetricLimits.bpUnit,
    ),
    MetricKind.glucose => l.metricValueUnit(
      '${p.value!.round()}',
      MetricLimits.glucoseUnit,
    ),
    MetricKind.meal => mealName(l, p.meal!),
  };
}

/// "Today, 8:30 AM", "Yesterday, 7:05 PM" or "Oct 12, 9:00 AM".
String formatWhen(BuildContext context, DateTime at, DateTime now) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final time = DateFormat.jm(locale).format(at);
  final day = localDateKey(at);
  if (day == localDateKey(now)) return l.metricToday(time);
  if (day == localDateKey(DateTime(now.year, now.month, now.day - 1))) {
    return l.metricYesterday(time);
  }
  return l.metricDateTime(DateFormat.MMMd(locale).format(at), time);
}

/// "Entered by you · Today, 8:30 AM": where a point came from and when.
String provenance(BuildContext context, MetricPoint p, DateTime now) {
  final l = AppLocalizations.of(context);
  final source = switch (p.source) {
    MetricSource.manual => l.metricSourceManual,
    MetricSource.health => l.metricSourceHealth(healthAppName(l)),
  };
  return l.metricProvenance(source, formatWhen(context, p.measuredAt, now));
}

/// "My measures" on Track (T-GOL-02, FR-GOL-04, D-72): weight, blood
/// pressure, glucose and meals, typed in by the person. Each row shows the
/// latest entry with where it came from and when; the row opens every entry
/// (each with its source and time), the + adds one.
///
/// Values are recorded, never judged: no "high", "low" or "normal", no
/// colours by value and no advice (spec 9.4; the clinician reads them).
/// Weight and meals are not offered in the eating-safe mode (FR-SAF-04).
/// Nothing typed here goes to analytics or logs (NFR-10).
class MeasuresCard extends ConsumerWidget {
  const MeasuresCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final points = ref.watch(metricPointsProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    final kinds = visibleMetricKinds(edSafeMode: ref.watch(edSafeModeProvider));
    return Card(
      key: const Key('track-measures'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.trackMeasuresIntro, style: t.bodySmall),
            const SizedBox(height: LwSpacing.xs),
            for (final k in kinds)
              _MeasureRow(
                kind: k,
                latest: points.where((p) => p.kind == k).lastOrNull,
                now: now,
              ),
          ],
        ),
      ),
    );
  }
}

class _MeasureRow extends StatelessWidget {
  const _MeasureRow({
    required this.kind,
    required this.latest,
    required this.now,
  });

  final MetricKind kind;
  final MetricPoint? latest;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final name = metricName(l, kind);
    final last = latest;
    final value = last == null
        ? l.metricNothingYet
        : formatPoint(context, last);
    final when = last == null ? null : provenance(context, last, now);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: when == null
                ? l.metricRowEmptyLabel(name)
                : l.metricRowLabel(name, value, when),
            child: InkWell(
              key: Key('metric-row-${kind.id}'),
              borderRadius: LwRadius.smAll,
              onTap: () => showMetricHistory(context, kind),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LwSize.minTapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: LwSpacing.xs),
                  child: Row(
                    children: [
                      Icon(metricIcon(kind), color: p.primary),
                      const SizedBox(width: LwSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: t.labelLarge),
                            Text(
                              value,
                              key: Key('metric-${kind.id}-value'),
                              style: t.titleMedium,
                            ),
                            if (when != null)
                              Text(
                                when,
                                key: Key('metric-${kind.id}-when'),
                                style: t.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('metric-add-${kind.id}'),
          tooltip: metricAddTitle(l, kind),
          onPressed: () => showMetricEntry(context, kind),
          icon: Icon(Icons.add_circle_outline, color: p.accentStrong),
        ),
      ],
    );
  }
}

Future<void> showMetricEntry(BuildContext context, MetricKind kind) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(child: _EntrySheet(kind)),
    );

Future<void> showMetricHistory(BuildContext context, MetricKind kind) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: _HistorySheet(
          kind,
          onAdd: () {
            Navigator.of(sheet).pop();
            showMetricEntry(context, kind);
          },
        ),
      ),
    );

/// Adds one point. Typos outside the fixed limits are caught kindly; any
/// value inside them is saved as it is, without comment (D-72).
class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet(this.kind);
  final MetricKind kind;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  final _value = TextEditingController();
  final _diastolic = TextEditingController();
  late WeightUnit _unit = ref.read(weightUnitProvider);
  MealKind? _meal;
  DateTime? _at;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    _diastolic.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = ref.read(clockProvider)();
    final current = _at ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(
        MetricLimits.maxBackdate - const Duration(days: 1),
      ),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _at = at.isAfter(now) ? now : at);
  }

  MetricPoint? _point(String id, DateTime at) {
    switch (widget.kind) {
      case MetricKind.weight:
        final v = parseMeasure(_value.text);
        if (v == null) return null;
        return MetricPoint.weight(
          id: id,
          kgOrLb: (v * 10).round() / 10,
          unit: _unit,
          measuredAt: at,
        );
      case MetricKind.bloodPressure:
        final s = int.tryParse(_value.text.trim());
        final d = int.tryParse(_diastolic.text.trim());
        if (s == null || d == null) return null;
        return MetricPoint.bloodPressure(
          id: id,
          systolic: s,
          diastolic: d,
          measuredAt: at,
        );
      case MetricKind.glucose:
        final g = int.tryParse(_value.text.trim());
        if (g == null) return null;
        return MetricPoint.glucose(id: id, mgDl: g, measuredAt: at);
      case MetricKind.meal:
        final m = _meal;
        if (m == null) return null;
        return MetricPoint.meal(id: id, meal: m, measuredAt: at);
    }
  }

  String _rangeMessage(AppLocalizations l) => switch (widget.kind) {
    MetricKind.weight => l.metricWeightRange(
      formatWeight(context, _unit.min),
      formatWeight(context, _unit.max),
      _unit.id,
    ),
    MetricKind.bloodPressure => l.metricBpRange,
    MetricKind.glucose => l.metricGlucoseRange,
    MetricKind.meal => l.metricMealPick,
  };

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(metricRepositoryProvider);
    final now = ref.read(clockProvider)();
    final point = _point(repo.newId(), _at ?? now);
    if (point == null || !point.isValidAt(now)) {
      setState(() => _error = _rangeMessage(l));
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await repo.add(point);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.metricSaveError)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(l.metricSaved)));
  }

  Widget _numberField(
    TextEditingController c,
    String key,
    String label,
    String unit, {
    bool decimal = false,
  }) => TextField(
    key: Key(key),
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(labelText: label, suffixText: unit),
    onChanged: (_) {
      if (_error != null) setState(() => _error = null);
    },
  );

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final when = formatWhen(context, _at ?? now, now);
    final fields = switch (widget.kind) {
      MetricKind.weight => [
        _numberField(
          _value,
          'metric-value',
          l.metricWeight,
          _unit.id,
          decimal: true,
        ),
        const SizedBox(height: LwSpacing.sm),
        SegmentedButton<WeightUnit>(
          key: const Key('metric-unit'),
          segments: [
            for (final u in WeightUnit.values)
              ButtonSegment(
                value: u,
                label: Text(u.id, key: Key('metric-unit-${u.id}')),
              ),
          ],
          selected: {_unit},
          onSelectionChanged: (s) => setState(() {
            _unit = s.first;
            _error = null;
          }),
        ),
      ],
      MetricKind.bloodPressure => [
        _numberField(
          _value,
          'metric-systolic',
          l.metricSystolic,
          MetricLimits.bpUnit,
        ),
        const SizedBox(height: LwSpacing.sm),
        _numberField(
          _diastolic,
          'metric-diastolic',
          l.metricDiastolic,
          MetricLimits.bpUnit,
        ),
      ],
      MetricKind.glucose => [
        _numberField(
          _value,
          'metric-value',
          l.metricGlucose,
          MetricLimits.glucoseUnit,
        ),
      ],
      MetricKind.meal => [
        Text(l.metricMealPick, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final m in MealKind.values)
              ChoiceChip(
                key: Key('metric-meal-${m.name}'),
                label: Text(mealName(l, m)),
                selected: _meal == m,
                onSelected: (_) => setState(() {
                  _meal = m;
                  _error = null;
                }),
              ),
          ],
        ),
      ],
    };
    return SingleChildScrollView(
      key: const Key('metric-entry-sheet'),
      padding: EdgeInsets.fromLTRB(
        LwSpacing.lg,
        0,
        LwSpacing.lg,
        LwSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(metricAddTitle(l, widget.kind), style: t.titleLarge),
          const SizedBox(height: LwSpacing.md),
          ...fields,
          const SizedBox(height: LwSpacing.sm),
          Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: l.metricChangeTimeLabel(when),
            child: InkWell(
              key: const Key('metric-when'),
              onTap: _saving ? null : _pickTime,
              borderRadius: LwRadius.smAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LwSize.minTapTarget,
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: p.textSecondary),
                    const SizedBox(width: LwSpacing.xs),
                    Expanded(
                      child: Text(
                        '${l.metricWhen}: $when',
                        key: const Key('metric-when-text'),
                        style: t.bodyMedium,
                      ),
                    ),
                    Text(
                      l.metricChangeTime,
                      style: t.labelLarge?.copyWith(color: p.accentStrong),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.kind != MetricKind.meal) ...[
            const SizedBox(height: LwSpacing.xs),
            Text(l.metricRecordNote, style: t.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: LwSpacing.sm),
            Text(
              _error!,
              key: const Key('metric-error'),
              style: t.bodyMedium?.copyWith(color: p.textPrimary),
            ),
          ],
          const SizedBox(height: LwSpacing.lg),
          FilledButton(
            key: const Key('metric-save'),
            onPressed: _saving ? null : _save,
            child: Text(l.metricSave),
          ),
        ],
      ),
    );
  }
}

/// Every entry of one kind in the last 90 days, newest first, each with
/// its source and time. Wrong entries can be deleted.
class _HistorySheet extends ConsumerWidget {
  const _HistorySheet(this.kind, {required this.onAdd});
  final MetricKind kind;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final points = [
      for (final p in (ref.watch(metricPointsProvider).value ?? const []))
        if (p.kind == kind) p,
    ].reversed.toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LwSpacing.lg,
          0,
          LwSpacing.lg,
          LwSpacing.lg,
        ),
        child: Column(
          key: const Key('metric-history-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(metricName(l, kind), style: t.titleLarge),
            ),
            const SizedBox(height: LwSpacing.sm),
            if (points.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: LwSpacing.md),
                child: Text(l.metricHistoryEmpty, style: t.bodyMedium),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in points) _HistoryRow(point: p, now: now),
                  ],
                ),
              ),
            const SizedBox(height: LwSpacing.md),
            FilledButton(
              key: const Key('metric-history-add'),
              onPressed: onAdd,
              child: Text(metricAddTitle(l, kind)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.point, required this.now});
  final MetricPoint point;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final value = formatPoint(context, point);
    final when = provenance(context, point, now);
    return Row(
      key: Key('metric-point-${point.id}'),
      children: [
        Expanded(
          child: Semantics(
            container: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: LwSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: t.titleMedium),
                  Text(when, style: t.bodySmall),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('metric-delete-${point.id}'),
          tooltip: l.metricDelete('$value, $when'),
          icon: Icon(Icons.delete_outline, color: p.textSecondary),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await ref.read(metricRepositoryProvider).delete(point.id);
            messenger.showSnackBar(SnackBar(content: Text(l.metricDeleted)));
          },
        ),
      ],
    );
  }
}
