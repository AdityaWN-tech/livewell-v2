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
import '../../routine/application/routine_week_data.dart';
import '../application/track_data.dart';
import '../data/reflection_repository.dart';
import '../domain/track_models.dart';
import '../domain/track_stats.dart';
import 'health_connect_sheet.dart';
import 'weekly_wins_screen.dart';

/// The streak card's data. Null until habit logs and the streak engine exist.
/// TODO(T-DLY-07): read users/{uid}/streaks/current and this week's logs.
final streakProvider = Provider<StreakSummary?>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.streak : null,
);

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
/// metric cards with mini bars, the Mon-Sun Progress chart, the streak, the
/// Weekly Reflection card and the evening reflection.
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

/// Progress: Steps / Sleep / Mood / Habits chips and a Mon-Sun bar chart
/// for this week, the selected day highlighted with its value in a bubble.
/// Each bar is labelled for screen readers (FR-GOL-05), and the selected
/// one is marked by its bubble and position, not colour alone.
class _ProgressChart extends ConsumerStatefulWidget {
  const _ProgressChart();

  @override
  ConsumerState<_ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends ConsumerState<_ProgressChart> {
  TrackMetric _metric = TrackMetric.mood;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final dates = weekDates(now);
    final todayIndex = now.weekday - 1;
    final history = {
      for (final c in ref.watch(trackHistoryProvider).value ?? <CheckIn>[])
        c.date: c,
    };
    final health = ref.watch(healthSummaryProvider);
    final habits = ref.watch(habitsWeekProvider);
    final routine = ref.watch(routineWeekProvider);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final dayNames = [
      for (final d in dates) DateFormat.E().format(DateTime.parse(d)),
    ];
    final fullDays = [
      for (final d in dates) DateFormat.EEEE().format(DateTime.parse(d)),
    ];

    // Per day: bar height 0..1 and the words for the bubble and label.
    final List<(double, String)?> days;
    String? empty;
    switch (_metric) {
      case TrackMetric.steps:
        if (health == null) {
          days = List.filled(7, null);
          empty = l.trackChartStepsEmpty;
        } else {
          final top = [
            health.stepsGoal,
            ...health.stepsWeek,
          ].reduce((a, b) => a > b ? a : b);
          days = [
            for (var i = 0; i < 7; i++)
              i > todayIndex || health.stepsWeek[i] == 0
                  ? null
                  : (
                      health.stepsWeek[i] / top,
                      number.format(health.stepsWeek[i]),
                    ),
          ];
        }
      case TrackMetric.habits:
        if (habits == null) {
          days = List.filled(7, null);
          empty = l.trackChartHabitsEmpty;
        } else {
          days = [
            for (var i = 0; i < 7; i++)
              i > todayIndex
                  ? null
                  : (habits[i] / 3, l.trackHabitsKept(habits[i])),
          ];
        }
      case TrackMetric.routine:
        // Items done per day (T-GOL-03e). A day with none simply has no
        // bar: never red, never "missed" (spec 4.1).
        if (routine == null) {
          days = List.filled(7, null);
          empty = l.trackChartRoutineEmpty;
        } else {
          final top = routine.fold(3, (a, b) => a > b ? a : b);
          days = [
            for (var i = 0; i < 7; i++)
              i > todayIndex || routine[i] == 0
                  ? null
                  : (routine[i] / top, l.trackRoutineDone(routine[i])),
          ];
        }
      case TrackMetric.sleep:
      case TrackMetric.mood:
        days = [
          for (final d in dates)
            if ((_metric == TrackMetric.sleep
                    ? history[d]?.sleep
                    : history[d]?.mood)
                case final v?)
              (v / 5, scaleWord(l, _metric, v))
            else
              null,
        ];
        if (days.every((d) => d == null)) empty = l.trackChartEmpty;
    }

    // Today, or the latest earlier day with a value, until one is tapped.
    var latest = todayIndex;
    while (latest > 0 && days[latest] == null) {
      latest--;
    }
    final selected = _selected ?? latest;

    final chips = [
      (TrackMetric.steps, l.trackSteps),
      (TrackMetric.sleep, l.trackSleep),
      (TrackMetric.mood, l.trackMood),
      (TrackMetric.habits, l.trackChipHabits),
      (TrackMetric.routine, l.trackChipRoutine),
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
            Text(l.trackThisWeekLabel, style: t.labelSmall),
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
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _Bar(
                        key: Key('track-bar-$i'),
                        height: chartHeight,
                        value: days[i]?.$1,
                        bubble: i == selected ? days[i]?.$2 : null,
                        day: dayNames[i],
                        colour: i == selected ? p.accent : bar,
                        label: days[i] == null
                            ? l.trackChartBarEmpty(fullDays[i])
                            : l.trackChartBarLabel(fullDays[i], days[i]!.$2),
                        selected: i == selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // The bubble and day names don't grow past 130%, so 7 fit across.
    final small = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      selected: selected,
      label: selected ? l.trackChartSelected(label) : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: LwRadius.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
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
                style: t.labelSmall?.copyWith(
                  color: selected ? p.textPrimary : p.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
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
