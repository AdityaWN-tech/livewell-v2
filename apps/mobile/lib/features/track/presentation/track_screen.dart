import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/design/components/illustrated.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../core/speech/dictation.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/presentation/microphone_consent.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/domain/safety_rules.dart';
import '../../safety/presentation/safety_screens.dart';
import '../../profile/presentation/profile_button.dart';
import '../application/track_data.dart';
import '../data/reflection_repository.dart';
import '../domain/track_models.dart';
import '../domain/streak.dart';
import '../domain/chart_series.dart';
import '../domain/metric_point.dart';
import '../domain/track_stats.dart';
import 'health_connect_sheet.dart';
import 'measures.dart';
import 'weekly_wins_screen.dart';

/// The streak card's data, from the habits done (D-60); null before the
/// first one. TODO(T-DLY-07): read users/{uid}/streaks/current once the
/// server's streak engine exists.
final streakProvider = Provider<StreakSummary?>((ref) {
  if (ref.watch(previewModeProvider)) return PreviewSamples.streak;
  final dates = ref.watch(recentDoneDatesProvider).value;
  if (dates == null) return null;
  return streakFrom(dates.toSet(), ref.watch(clockProvider)());
});

/// Today's reflection, live.
final todayReflectionProvider = StreamProvider<Reflection?>((ref) {
  final today = localDateKey(ref.watch(clockProvider)());
  return ref.watch(reflectionRepositoryProvider).watchDay(today);
});

/// The 1 to 5 answer words from the check-in, shared by cards and chart.
String scaleWord(
  AppLocalizations l,
  TrackMetric m,
  int v, {
  bool stress = false,
}) {
  final words = stress
      ? [
          l.checkinStress1,
          l.checkinStress2,
          l.checkinStress3,
          l.checkinStress4,
          l.checkinStress5,
        ]
      : m == TrackMetric.sleep
      ? [
          l.checkinSleep1,
          l.checkinSleep2,
          l.checkinSleep3,
          l.checkinSleep4,
          l.checkinSleep5,
        ]
      : [
          l.checkinMood1,
          l.checkinMood2,
          l.checkinMood3,
          l.checkinMood4,
          l.checkinMood5,
        ];
  return words[v.clamp(1, 5) - 1];
}

/// Track tab (T-UI-02e, illustrated design): period picker, the 2 x 2
/// metric cards with mini bars, the Progress chart for the period, My
/// measures (T-GOL-02), the streak, the Weekly Reflection card and the
/// evening reflection.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return LwScreen(
      eyebrow: l.trackEyebrow,
      title: l.tabTrack,
      profile: const ProfileButton(),
      actions: const [_PeriodPicker()],
      children: [
        const _MetricGrid(),
        LwSectionHeader(l.trackProgressTitle),
        const _ProgressChart(),
        LwSectionHeader(l.trackMeasuresTitle),
        const MeasuresCard(),
        const SizedBox(height: LwSpacing.sectionGap),
        _WeekStreakCard(ref.watch(streakProvider)),
        LwSectionHeader(l.trackWeeklyTitle),
        _WeeklyCard(onTap: () => context.push(WeeklyWinsScreen.path)),
        const SizedBox(height: LwSpacing.sectionGap),
        const _ReflectionCard(),
      ],
    );
  }
}

/// "This Week / This Month / 90 days", a pill below the title.
class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final period = ref.watch(trackPeriodProvider);
    String name(TrackPeriod x) => switch (x) {
      TrackPeriod.week => l.trackPeriodWeek,
      TrackPeriod.month => l.trackPeriodMonth,
      TrackPeriod.quarter => l.trackPeriodQuarter,
    };
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: l.trackPeriodLabel(name(period)),
      child: PopupMenuButton<TrackPeriod>(
        key: const Key('track-period'),
        initialValue: period,
        onSelected: ref.read(trackPeriodProvider.notifier).set,
        itemBuilder: (context) => [
          for (final x in TrackPeriod.values)
            PopupMenuItem(
              key: Key('track-period-${x.name}'),
              value: x,
              child: Text(name(x)),
            ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: LwSpacing.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: LwRadius.pillAll,
            border: Border.all(color: p.outlineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name(period), style: t.labelLarge),
              const SizedBox(width: LwSpacing.xxs),
              Icon(Icons.expand_more, color: p.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Steps, Sleep, Mood and Stress: 2 across (1 across with large text).
class _MetricGrid extends ConsumerWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    final stats = ref.watch(trackStatsProvider);
    final health = ref.watch(healthSummaryProvider);
    final today = ref.watch(clockProvider)();
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    String avg(double v) => NumberFormat('0.0').format(v);

    // Steps: only with Apple Health / Health Connect (and its consent).
    final LwMetric steps;
    if (health == null) {
      steps = LwMetric(
        id: 'steps',
        name: l.trackSteps,
        art: 'icon_steps',
        tint: p.mint,
        value: l.trackConnectHealth,
        detail: '',
        bars: const [],
        label: l.trackConnectHealthLabel,
        onTap: () => showConnectHealth(context),
      );
    } else {
      final todaySteps = health.stepsWeek[today.weekday - 1];
      steps = LwMetric(
        id: 'steps',
        name: l.trackSteps,
        art: 'icon_steps',
        tint: p.mint,
        value: number.format(todaySteps),
        detail: l.trackStepsOf(number.format(health.stepsGoal)),
        bars: [
          for (final s in health.stepsWeek.take(today.weekday))
            s / health.stepsGoal,
        ],
      );
    }

    final sleepAvg = stats?.sleep;
    final sleepWord = sleepAvg == null
        ? null
        : scaleWord(l, TrackMetric.sleep, TrackStats.nearest(sleepAvg));
    // Sleep hours from the health app when it has any, else the check-in.
    final sleepMinutes = health?.sleepMinutesAverage;
    final sleep = LwMetric(
      id: 'sleep',
      name: l.trackSleep,
      art: 'icon_sleep',
      tint: p.lavender,
      value: sleepMinutes != null
          ? l.trackSleepHours(sleepMinutes ~/ 60, sleepMinutes % 60)
          : sleepWord ?? l.trackNoCheckIns,
      detail: sleepMinutes != null
          ? (sleepWord ?? '')
          : (sleepWord == null ? '' : l.trackFromCheckIns),
      bars: [for (final v in stats?.recent((c) => c.sleep) ?? <int>[]) v / 5],
    );

    LwMetric scale(
      String id,
      String name,
      String art,
      Color tint,
      double? value,
      int? Function(CheckIn) pick, {
      bool stress = false,
    }) => LwMetric(
      id: id,
      name: name,
      art: art,
      tint: tint,
      value: value == null ? l.trackNoCheckIns : l.trackOutOf5(avg(value)),
      detail: value == null
          ? ''
          : scaleWord(
              l,
              TrackMetric.mood,
              TrackStats.nearest(value),
              stress: stress,
            ),
      bars: [for (final v in stats?.recent(pick) ?? <int>[]) v / 5],
    );

    final cards = [
      steps,
      sleep,
      scale(
        'mood',
        l.trackMood,
        'icon_mood',
        p.butter,
        stats?.mood,
        (c) => c.mood,
      ),
      scale(
        'stress',
        l.trackStress,
        'icon_stress',
        p.sky,
        stats?.stress,
        (c) => c.stress,
        stress: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final scaleF = MediaQuery.textScalerOf(context).scale(1);
        final columns = box.maxWidth / scaleF >= 260 ? 2 : 1;
        final w = (box.maxWidth - LwSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: LwSpacing.sm,
          runSpacing: LwSpacing.sm,
          children: [
            for (final c in cards) SizedBox(width: w, child: LwMetricCard(c)),
          ],
        );
      },
    );
  }
}

/// Progress: one chip per value and a bar chart for the picked period
/// (FR-GOL-05): This Week by day (Monday to Sunday), This Month and 90 days
/// by week (Monday to Sunday, clipped to the period). The selected bar is
/// highlighted with its value in a bubble. Each bar is labelled for screen
/// readers, and the selected one is marked by its bubble, position and bold
/// day, not colour alone. Under the chart: where the values came from (and
/// for Health, when they were read), FR-GOL-04.
class _ProgressChart extends ConsumerStatefulWidget {
  const _ProgressChart();

  @override
  ConsumerState<_ProgressChart> createState() => _ProgressChartState();
}

/// One chart's data: per-day values, how weeks combine them, the bar
/// scale, and the words for a value (a day, or a week's average).
class _Series {
  const _Series({
    required this.daily,
    required this.combine,
    required this.top,
    required this.word,
    this.source,
  });

  final Map<String, Reading> daily;
  final Combine combine;

  /// The value of a full bar.
  final double Function(List<Reading?> values) top;

  /// The bubble's words for a value; [week] for a week's bar.
  final String Function(Reading r, {required bool week}) word;
  final String? source;
}

class _ProgressChartState extends ConsumerState<_ProgressChart> {
  TrackMetric _metric = TrackMetric.mood;
  int? _selected;
  TrackPeriod? _period;

  static double _max(List<Reading?> v, double floor) =>
      v.nonNulls.fold(floor, (m, r) => r.a > m ? r.a : m);

  /// The series for the chip, or the kind note to show instead.
  (_Series?, String?) _series(AppLocalizations l, DateTime now) {
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final one = NumberFormat('0.0');
    String perDay(Reading r) => l.trackPerDay(one.format(r.a));
    switch (_metric) {
      case TrackMetric.steps:
        final steps = ref.watch(healthStepsProvider).value;
        if (steps == null) return (null, l.trackChartStepsEmpty);
        return (
          _Series(
            daily: {
              for (final e in steps.days.entries)
                e.key: (a: e.value.toDouble(), b: null),
            },
            combine: Combine.mean,
            top: (v) => _max(v, steps.goal.toDouble()),
            word: (r, {required week}) => number.format(r.a.round()),
            source: l.trackChartFromHealth(
              healthAppName(l),
              DateFormat.jm(Localizations.localeOf(context).toString())
                  .format(steps.readAt),
            ),
          ),
          null,
        );
      case TrackMetric.sleep:
      case TrackMetric.mood:
        final history = ref.watch(trackHistoryProvider).value ?? <CheckIn>[];
        return (
          _Series(
            daily: {
              for (final c in history)
                if ((_metric == TrackMetric.sleep ? c.sleep : c.mood)
                    case final v?)
                  c.date: (a: v.toDouble(), b: null),
            },
            combine: Combine.mean,
            top: (_) => 5,
            word: (r, {required week}) =>
                scaleWord(l, _metric, TrackStats.nearest(r.a)),
            source: l.trackFromCheckIns,
          ),
          l.trackChartEmpty,
        );
      case TrackMetric.habits:
        final habits = ref.watch(habitsDailyProvider);
        if (habits == null) return (null, l.trackChartHabitsEmpty);
        return (
          _Series(
            daily: {
              for (final e in habits.entries)
                e.key: (a: e.value.toDouble(), b: null),
            },
            combine: Combine.perDay,
            top: (v) => _max(v, 3),
            word: (r, {required week}) =>
                week ? perDay(r) : l.trackHabitsKept(r.a.round()),
            source: l.trackChartFromApp,
          ),
          null,
        );
      case TrackMetric.routine:
        // Items done per day (T-GOL-03e). A day with none simply has no
        // bar: never red, never "missed" (spec 4.1).
        final routine = ref.watch(routineDailyProvider).value;
        if (routine == null) return (null, l.trackChartRoutineEmpty);
        return (
          _Series(
            daily: {
              for (final e in routine.entries)
                e.key: (a: e.value.toDouble(), b: null),
            },
            combine: Combine.perDay,
            top: (v) => _max(v, 3),
            word: (r, {required week}) =>
                week ? perDay(r) : l.trackRoutineDone(r.a.round()),
            source: l.trackChartFromApp,
          ),
          null,
        );
      case TrackMetric.weight:
      case TrackMetric.bloodPressure:
      case TrackMetric.glucose:
      case TrackMetric.meals:
        final kind = switch (_metric) {
          TrackMetric.weight => MetricKind.weight,
          TrackMetric.bloodPressure => MetricKind.bloodPressure,
          TrackMetric.glucose => MetricKind.glucose,
          _ => MetricKind.meal,
        };
        final unit = ref.watch(weightUnitProvider);
        final points = [
          for (final p
              in ref.watch(metricPointsProvider).value ?? <MetricPoint>[])
            if (p.kind == kind) p,
        ];
        // Bars start at zero, so a change looks as big as it is.
        return (
          _Series(
            daily: dailyFromPoints(points, kind, unit),
            combine: kind == MetricKind.meal ? Combine.perDay : Combine.mean,
            top: (v) => _max(v, kind == MetricKind.meal ? 3 : 1),
            word: (r, {required week}) => switch (kind) {
              MetricKind.weight => l.metricValueUnit(
                formatWeight(context, r.a),
                unit.id,
              ),
              MetricKind.bloodPressure => l.metricBpValue(
                '${r.a.round()}',
                '${r.b!.round()}',
                MetricLimits.bpUnit,
              ),
              MetricKind.glucose => l.metricValueUnit(
                '${r.a.round()}',
                MetricLimits.glucoseUnit,
              ),
              MetricKind.meal =>
                week ? perDay(r) : l.metricMealsCount(r.a.round()),
            },
            source: points.any((p) => p.source == MetricSource.health)
                ? (points.any((p) => p.source == MetricSource.manual)
                      ? l.trackChartFromYouAndHealth(healthAppName(l))
                      : l.metricSourceHealth(healthAppName(l)))
                : l.trackChartFromYou,
          ),
          l.trackChartMeasureEmpty,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = ref.watch(clockProvider)();
    final period = ref.watch(trackPeriodProvider);
    if (period != _period) {
      _period = period;
      _selected = null;
    }
    final edSafe = ref.watch(edSafeModeProvider);
    if (edSafe &&
        (_metric == TrackMetric.weight || _metric == TrackMetric.meals)) {
      _metric = TrackMetric.mood;
    }
    final buckets = chartBuckets(period, now);
    final byDay = period == TrackPeriod.week;
    final today = DateTime(now.year, now.month, now.day);
    final current = buckets.indexWhere(
      (b) => !today.isBefore(b.first) && !today.isAfter(b.last),
    );

    final (series, note) = _series(l, now);
    final values = series == null
        ? List<Reading?>.filled(buckets.length, null)
        : bucketValues(buckets, series.daily, now, series.combine);
    // A note instead of the bars: no series, or a series that is
    // empty-noted when nothing is in the period.
    final String? empty = series == null
        ? note
        : (note != null && values.every((v) => v == null) ? note : null);
    final top = series?.top(values) ?? 1;

    // The bar's day under it and its full name for screen readers.
    final short = [
      for (var i = 0; i < buckets.length; i++)
        byDay
            ? DateFormat.E(locale).format(buckets[i].first)
            : period == TrackPeriod.month
            ? DateFormat.MMMd(locale).format(buckets[i].first)
            // 90 days: every third week, newest last, so they fit.
            : ((buckets.length - 1 - i) % 3 == 0
                  ? DateFormat.Md(locale).format(buckets[i].first)
                  : ''),
    ];
    final full = [
      for (final b in buckets)
        byDay
            ? DateFormat.EEEE(locale).format(b.first)
            : l.trackChartWeekOf(DateFormat.MMMMd(locale).format(b.first)),
    ];

    // Today's bar, or the latest earlier one with a value, until one is
    // tapped.
    var latest = current < 0 ? buckets.length - 1 : current;
    while (latest > 0 && values[latest] == null) {
      latest--;
    }
    final selected = _selected ?? latest;
    // 90 days has too many bars to tap: each is still read out.
    final interactive = buckets.length <= 7;

    final chips = [
      (TrackMetric.steps, l.trackSteps),
      (TrackMetric.sleep, l.trackSleep),
      (TrackMetric.mood, l.trackMood),
      (TrackMetric.habits, l.trackChipHabits),
      (TrackMetric.routine, l.trackChipRoutine),
      if (!edSafe) (TrackMetric.weight, l.metricWeight),
      (TrackMetric.bloodPressure, l.metricBloodPressure),
      (TrackMetric.glucose, l.metricGlucose),
      if (!edSafe) (TrackMetric.meals, l.metricMeals),
    ];
    const chartHeight = 140.0;
    final bar = LwPalette.richer(p.mint);
    return Card(
      key: const Key('track-progress'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xs,
              children: [
                for (final (m, name) in chips)
                  ChoiceChip(
                    key: Key('track-chip-${m.name}'),
                    label: Text(name),
                    selected: _metric == m,
                    onSelected: (_) => setState(() {
                      _metric = m;
                      _selected = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: LwSpacing.sm),
            Text(
              switch (period) {
                TrackPeriod.week => l.trackThisWeekLabel,
                TrackPeriod.month => l.trackChartMonthLabel,
                TrackPeriod.quarter => l.trackChartQuarterLabel,
              },
              key: const Key('track-chart-period'),
              style: t.labelSmall,
            ),
            const SizedBox(height: LwSpacing.sm),
            if (empty != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: LwSpacing.lg),
                child: Text(
                  empty,
                  key: const Key('track-chart-empty'),
                  style: t.bodyMedium,
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < buckets.length; i++)
                    Expanded(
                      child: () {
                        final v = values[i];
                        final words = v == null
                            ? null
                            : series!.word(v, week: !byDay);
                        final spoken = words == null
                            ? null
                            : (byDay || series!.combine == Combine.perDay
                                  ? words
                                  : l.trackOnAverage(words));
                        return _Bar(
                          key: Key('track-bar-$i'),
                          height: chartHeight,
                          value: v == null ? null : v.a / top,
                          bubble: i == selected ? words : null,
                          day: short[i],
                          colour: i == selected ? p.accent : bar,
                          label: spoken == null
                              ? l.trackChartBarEmpty(full[i])
                              : l.trackChartBarLabel(full[i], spoken),
                          selected: i == selected,
                          onTap: interactive
                              ? () => setState(() => _selected = i)
                              : null,
                        );
                      }(),
                    ),
                ],
              ),
              if (series?.source case final source?) ...[
                const SizedBox(height: LwSpacing.sm),
                Text(
                  source,
                  key: const Key('track-chart-source'),
                  style: t.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.height,
    required this.value,
    required this.bubble,
    required this.day,
    required this.colour,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double height;
  final double? value;
  final String? bubble;
  final String day;
  final Color colour;
  final String label;
  final bool selected;

  /// Null: read out but not tappable (90 days).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // The bubble and day names don't grow past 130%, so 7 fit across.
    final small = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: onTap == null ? 0 : LwSize.minTapTarget,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                if (value != null)
                  FractionallySizedBox(
                    heightFactor: (value! * 0.8).clamp(0.06, 0.8),
                    widthFactor: 0.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colour,
                        borderRadius: LwRadius.smAll,
                      ),
                    ),
                  ),
                if (bubble != null)
                  Positioned(
                    top: 0,
                    child: Container(
                      key: const Key('track-bubble'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: LwSpacing.xs,
                        vertical: LwSpacing.xxs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: LwRadius.pillAll,
                      ),
                      child: Text(
                        bubble!,
                        textScaler: small,
                        style: t.labelSmall?.copyWith(color: p.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: LwSpacing.xxs),
          Text(
            day,
            textScaler: small,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: t.labelSmall?.copyWith(
              color: selected ? p.textPrimary : p.textSecondary,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      selected: selected,
      label: selected ? l.trackChartSelected(label) : label,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: LwRadius.smAll, child: content),
    );
  }
}

/// "How was your week?" (opens the weekly review, FR-DLY-06).
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: l.trackWeeklyLabel,
      child: Card(
        key: const Key('track-weekly-wins'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Row(
              children: [
                const Illustration('icon_reflection', width: 48, height: 48),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.trackWeeklyQuestion, style: t.titleSmall),
                      Text(l.trackWeeklyBody, style: t.bodySmall),
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

class _WeekStreakCard extends StatelessWidget {
  const _WeekStreakCard(this.streak);
  final StreakSummary? streak;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final s = streak;
    final ml = MaterialLocalizations.of(context);
    // Monday first, as in the mockup.
    final letters = [
      l.trackDayMon,
      l.trackDayTue,
      l.trackDayWed,
      l.trackDayThu,
      l.trackDayFri,
      l.trackDaySat,
      l.trackDaySun,
    ];
    final fullNames = [
      for (var i = 0; i < 7; i++)
        ml.formatFullDate(DateTime(2024, 1, 1 + i)).split(',').first,
    ];

    return Card(
      key: const Key('track-streak'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.trackStreakEyebrow.toUpperCase(), style: t.labelSmall),
            const SizedBox(height: LwSpacing.xxs),
            if (s == null)
              Text(l.trackStreakEmpty, style: t.bodyMedium)
            else ...[
              Wrap(
                spacing: LwSpacing.sm,
                runSpacing: LwSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.trackStreakDays(s.length), style: t.headlineSmall),
                  if (s.isPersonalBest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LwSpacing.xs,
                        vertical: LwSpacing.xxs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.accentTint,
                        borderRadius: LwRadius.pillAll,
                      ),
                      child: Text(
                        l.trackPersonalBest,
                        style: t.labelMedium?.copyWith(color: p.onAccentTint),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: LwSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _DayMark(
                      key: Key('streak-day-$i'),
                      letter: letters[i],
                      day: s.week[i],
                      label: switch (s.week[i]) {
                        StreakDay.done => l.trackDayDone(fullNames[i]),
                        StreakDay.rest => l.trackDayRest(fullNames[i]),
                        StreakDay.restart => l.trackDayRestart(fullNames[i]),
                        StreakDay.today => l.trackDayToday(fullNames[i]),
                        StreakDay.upcoming => l.trackDayUpcoming(fullNames[i]),
                      },
                    ),
                ],
              ),
              if (s.week.contains(StreakDay.rest)) ...[
                const SizedBox(height: LwSpacing.sm),
                Text(l.trackStreakLegend, style: t.bodySmall),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One day in the streak row. No red and no alarm for a missed day: a rest
/// day is a calm moon, a restart a gentle arrow (spec 4.1, FR-DLY-07).
class _DayMark extends StatelessWidget {
  const _DayMark({
    super.key,
    required this.letter,
    required this.day,
    required this.label,
  });

  final String letter;
  final StreakDay day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    const size = LwSize.avatarSm * 0.9;
    final (fill, border, icon, iconColor) = switch (day) {
      StreakDay.done => (p.primary, p.primary, Icons.check, p.onPrimary),
      StreakDay.rest => (
        p.primaryTint,
        p.outlineStrong,
        Icons.bedtime_outlined,
        p.onPrimaryTint,
      ),
      StreakDay.restart => (
        p.primaryTint,
        p.outlineStrong,
        Icons.replay,
        p.onPrimaryTint,
      ),
      StreakDay.today => (p.surface, p.accent, null, null),
      StreakDay.upcoming => (p.surface, p.outlineStrong, null, null),
    };
    return Semantics(
      label: label,
      container: true,
      excludeSemantics: true,
      child: Column(
        children: [
          Text(letter, style: t.labelSmall),
          const SizedBox(height: LwSpacing.xxs),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: border,
                width: day == StreakDay.today ? 2 : 1,
              ),
            ),
            child: icon == null
                ? null
                : Icon(icon, size: LwSize.iconSm, color: iconColor),
          ),
        ],
      ),
    );
  }
}

/// "What went well today?" Saved to users/{uid}/reflections/{date} after
/// the red-flag check (FR-DLY-05, FR-SAF-01/02). Voice needs the microphone
/// consent.
class _ReflectionCard extends ConsumerStatefulWidget {
  const _ReflectionCard();

  @override
  ConsumerState<_ReflectionCard> createState() => _ReflectionCardState();
}

class _ReflectionCardState extends ConsumerState<_ReflectionCard> {
  final _text = TextEditingController();
  late final Dictation _dictation = ref.read(dictationProvider);
  bool _listening = false;
  bool _usedVoice = false;
  bool _saving = false;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_listening) _dictation.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    final l = AppLocalizations.of(context);
    if (_listening) {
      await _dictation.stop();
      setState(() => _listening = false);
      return;
    }
    if (!await ensureMicrophoneConsent(context, ref) || !mounted) return;
    final before = _text.text.trim();
    final started = await _dictation.start((words, isFinal) {
      if (!mounted) return;
      final text = before.isEmpty ? words : '$before $words';
      _text.text = text.length > Reflection.maxLength
          ? text.substring(0, Reflection.maxLength)
          : text;
      if (isFinal) setState(() => _listening = false);
    });
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.whyDictationUnavailable)));
      return;
    }
    setState(() {
      _listening = true;
      _usedVoice = true;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final text = _text.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    if (_listening) {
      await _dictation.stop();
      _listening = false;
    }

    // Red flags first (FR-SAF-01/02), as for the Why and the check-in note.
    final rules = await ref.read(safetyRulesProvider.future);
    final result = rules.check(text);
    if (!result.isClear) {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      final region = uid == null
          ? null
          : (await ref.read(profileRepositoryProvider).get(uid))?.region;
      if (!mounted) return;
      final proceed = await showSafetyResponse(
        context,
        result,
        rules.contactsFor(region),
        continueLabel: l.trackReflectionSave,
      );
      final distress =
          result.interrupts ||
          result.category == SafetyCategory.disorderedEating;
      if (distress || !proceed) {
        if (mounted) {
          setState(() => _saving = false);
          if (distress) {
            // Not kept (FR-SAF-04), like the Why and the check-in note.
            _text.clear();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.trackReflectionNotSaved)));
          }
        }
        return;
      }
    }

    final today = localDateKey(ref.read(clockProvider)());
    try {
      await ref
          .read(reflectionRepositoryProvider)
          .save(Reflection(date: today, text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.trackReflectionError)));
        setState(() => _saving = false);
      }
      return;
    }
    // Only how it was given, never the text (NFR-10).
    unawaited(
      ref.read(analyticsProvider).reflectionSubmitted(voice: _usedVoice),
    );
    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() {
        _saving = false;
        _saved = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final stored = ref.watch(todayReflectionProvider).value;
    // Show today's saved reflection once it loads, unless they're typing.
    if (stored != null && _saved == null && _text.text.isEmpty) {
      _saved = stored.text;
      _text.text = stored.text;
    }
    final text = _text.text.trim();
    final isSaved = _saved != null && text == _saved;

    return Card(
      key: const Key('track-reflection'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.trackReflectionTitle, style: t.titleSmall),
            const SizedBox(height: LwSpacing.xs),
            Text(l.trackReflectionQuestion, style: t.titleLarge),
            const SizedBox(height: LwSpacing.sm),
            TextField(
              key: const Key('reflection-field'),
              controller: _text,
              minLines: 2,
              maxLines: 6,
              maxLength: Reflection.maxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l.trackReflectionHint,
                suffixIcon: IconButton(
                  key: const Key('reflection-mic'),
                  tooltip: _listening
                      ? l.trackReflectionStop
                      : l.trackReflectionSpeak,
                  onPressed: _saving ? null : _toggleDictation,
                  icon: Icon(
                    _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                    color: _listening ? p.accentStrong : p.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: LwSpacing.xs),
            if (isSaved)
              Row(
                key: const Key('reflection-saved'),
                children: [
                  Icon(Icons.check_circle, color: p.success),
                  const SizedBox(width: LwSpacing.xs),
                  Expanded(
                    child: Text(l.trackReflectionSaved, style: t.bodyMedium),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('reflection-save'),
                  onPressed: text.isEmpty || _saving ? null : _save,
                  child: Text(l.trackReflectionSave),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
