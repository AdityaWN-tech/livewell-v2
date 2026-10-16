import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/speech/dictation.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/domain/checkin.dart';
import '../../checkin/presentation/checkin_sheet.dart';
import '../../consent/presentation/microphone_consent.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/domain/safety_rules.dart';
import '../../safety/presentation/safety_screens.dart';
import '../../profile/presentation/profile_button.dart';
import '../data/reflection_repository.dart';
import '../domain/track_models.dart';

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

/// Track tab (T-UI-01d, Screen 3): streak, today's check-in and the evening
/// reflection.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    return LwScreen(
      eyebrow: l.trackEyebrow,
      title: l.tabTrack,
      profile: const ProfileButton(),
      actions: [
        FilledButton.icon(
          key: const Key('track-weekly-wins'),
          style: FilledButton.styleFrom(
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
            shape: const StadiumBorder(),
            minimumSize: const Size(LwSize.minTapTarget, LwSize.minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: LwSpacing.md),
          ),
          onPressed: () => _weeklyWins(context),
          icon: const Icon(Icons.emoji_events_outlined),
          label: Text(l.trackWeeklyWins),
        ),
      ],
      children: [
        _StreakCard(ref.watch(streakProvider)),
        const SizedBox(height: LwSpacing.lg),
        _CheckInGrid(checkIn: ref.watch(todayCheckInProvider).value),
        const SizedBox(height: LwSpacing.lg),
        const _ReflectionCard(),
      ],
    );
  }

  /// FR-DLY-06 weekly review isn't built yet.
  Future<void> _weeklyWins(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          key: const Key('track-weekly-wins-soon'),
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
              Text(l.trackWeeklyWinsSoonTitle, style: t.titleLarge),
              const SizedBox(height: LwSpacing.xs),
              Text(l.trackWeeklyWinsSoonBody, style: t.bodyMedium),
              const SizedBox(height: LwSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.trackGotIt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard(this.streak);
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

class _CheckInGrid extends ConsumerWidget {
  const _CheckInGrid({required this.checkIn});
  final CheckIn? checkIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = checkIn;
    // The 1 to 5 scale words from the check-in, never percentages.
    final tiles = [
      (
        'energy',
        l.trackEnergy,
        Icons.bolt_rounded,
        switch (c?.energy) {
          1 => l.checkinEnergy1,
          2 => l.checkinEnergy2,
          3 => l.checkinEnergy3,
          4 => l.checkinEnergy4,
          5 => l.checkinEnergy5,
          _ => null,
        },
      ),
      (
        'sleep',
        l.trackSleep,
        Icons.bedtime_outlined,
        switch (c?.sleep) {
          1 => l.checkinSleep1,
          2 => l.checkinSleep2,
          3 => l.checkinSleep3,
          4 => l.checkinSleep4,
          5 => l.checkinSleep5,
          _ => null,
        },
      ),
      (
        'stress',
        l.trackStress,
        Icons.spa_outlined,
        switch (c?.stress) {
          1 => l.checkinStress1,
          2 => l.checkinStress2,
          3 => l.checkinStress3,
          4 => l.checkinStress4,
          5 => l.checkinStress5,
          _ => null,
        },
      ),
      (
        'mood',
        l.trackMood,
        Icons.sentiment_satisfied_outlined,
        switch (c?.mood) {
          1 => l.checkinMood1,
          2 => l.checkinMood2,
          3 => l.checkinMood3,
          4 => l.checkinMood4,
          5 => l.checkinMood5,
          _ => null,
        },
      ),
    ];

    Future<void> open() => showCheckInSheet(
      context,
      date: localDateKey(ref.read(clockProvider)()),
      firstName: ref.read(firstNameProvider),
    );

    final oneColumn = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: LwSpacing.sm,
          children: [
            Semantics(
              header: true,
              child: Text(l.trackCheckInTitle, style: t.titleSmall),
            ),
            Text(l.trackCheckInTap, style: t.bodySmall),
          ],
        ),
        const SizedBox(height: LwSpacing.sm),
        LayoutBuilder(
          builder: (context, box) {
            final w = oneColumn
                ? box.maxWidth
                : (box.maxWidth - LwSpacing.sm) / 2;
            return Wrap(
              spacing: LwSpacing.sm,
              runSpacing: LwSpacing.sm,
              children: [
                for (final (id, name, icon, value) in tiles)
                  SizedBox(
                    width: w,
                    child: _Tile(
                      key: Key('track-tile-$id'),
                      name: name,
                      icon: icon,
                      value: value,
                      onTap: open,
                    ),
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
    required this.name,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final String? value;
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
      label: value == null
          ? l.trackTileEmptyLabel(name)
          : l.trackTileLabel(name, value!),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: t.bodySmall)),
                    Icon(icon, size: LwSize.iconSm, color: p.accent),
                  ],
                ),
                const SizedBox(height: LwSpacing.xs),
                Text(
                  value ?? l.trackNotLogged,
                  style: value == null
                      ? t.titleMedium?.copyWith(color: p.textSecondary)
                      : t.titleLarge,
                ),
              ],
            ),
          ),
        ),
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
