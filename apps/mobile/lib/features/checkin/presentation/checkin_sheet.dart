import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/design/tokens.dart';
import '../../../core/speech/dictation.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../consent/presentation/microphone_consent.dart';
import '../../moments/application/coach_state.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/domain/safety_rules.dart';
import '../../safety/presentation/safety_screens.dart';
import '../data/checkin_repository.dart';
import '../domain/checkin.dart';

/// Opens the daily check-in as a bottom sheet. Returns the saved check-in,
/// or null if the user closed it.
Future<CheckIn?> showCheckInSheet(
  BuildContext context, {
  required String date,
  String? firstName,
}) => showModalBottomSheet<CheckIn>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => CheckInSheet(date: date, firstName: firstName),
);

/// Daily check-in, mood first (T-DLY-02, FR-DLY-02). One question per step;
/// tapping an answer moves on, so the whole flow fits in under 30 seconds.
class CheckInSheet extends ConsumerStatefulWidget {
  const CheckInSheet({super.key, required this.date, this.firstName});

  final String date;
  final String? firstName;

  static const steps = 6;

  @override
  ConsumerState<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<CheckInSheet> {
  final _barrier = TextEditingController();
  final _timer = Stopwatch()..start();
  late final Dictation _dictation = ref.read(dictationProvider);
  int _step = 0;
  int? _mood, _energy, _sleep, _stress, _time;
  bool _saving = false;
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) _dictation.stop();
    _barrier.dispose();
    super.dispose();
  }

  void _answer(int value) {
    setState(() {
      switch (_step) {
        case 0:
          _mood = value;
        case 1:
          _energy = value;
        case 2:
          _sleep = value;
        case 3:
          _stress = value;
        case 4:
          _time = value;
      }
      _step++;
    });
  }

  void _skipQuestion() => setState(() => _step++);

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _dictation.stop();
      setState(() => _listening = false);
      return;
    }
    if (!await ensureMicrophoneConsent(context, ref) || !mounted) return;
    final before = _barrier.text.trim();
    final started = await _dictation.start((words, isFinal) {
      if (!mounted) return;
      final text = before.isEmpty ? words : '$before $words';
      _barrier.text = text.length > barrierMaxLength
          ? text.substring(0, barrierMaxLength)
          : text;
      if (isFinal) setState(() => _listening = false);
    });
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).whyDictationUnavailable),
        ),
      );
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _finish() async {
    final mood = _mood;
    if (mood == null || _saving) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    if (_listening) await _dictation.stop();

    var barrierText = _barrier.text.trim().isEmpty
        ? null
        : _barrier.text.trim();
    var gentle = isGentleDay(mood: mood, stress: _stress);

    // Red flags in the free text come first, before any other response
    // (FR-SAF-01/02, T-DLY-02 Safety).
    if (barrierText != null) {
      final rules = await ref.read(safetyRulesProvider.future);
      final result = rules.check(barrierText);
      if (!result.isClear) {
        // The coach stays quiet for the rest of today (T-DLY-03d).
        ref.read(safetyHoldStoreProvider.notifier).holdToday();
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        final region = uid == null
            ? null
            : (await ref.read(profileRepositoryProvider).get(uid))?.region;
        if (!mounted) return;
        final proceed = await showSafetyResponse(
          context,
          result,
          rules.contactsFor(region),
          continueLabel: l.checkinContinue,
        );
        final distress =
            result.interrupts ||
            result.category == SafetyCategory.disorderedEating;
        if (distress) {
          // Not kept, like the Why (FR-SAF-04 suppresses this content), and
          // no portal card today (spec 15.3).
          barrierText = null;
          gentle = true;
        } else if (!proceed) {
          // "Change it": stay on this step to edit.
          if (mounted) setState(() => _saving = false);
          return;
        }
      }
    }

    final checkIn = CheckIn(
      date: widget.date,
      mood: mood,
      energy: _energy,
      sleep: _sleep,
      stress: _stress,
      timeAvailable: _time,
      barrierText: barrierText,
      gentleDay: gentle,
    );
    try {
      await ref.read(checkInRepositoryProvider).save(checkIn);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.checkinSaveError)));
        setState(() => _saving = false);
      }
      return;
    }
    // Only counts and duration, never the answers (NFR-10).
    unawaited(
      ref
          .read(analyticsProvider)
          .checkinCompleted(
            durationSeconds: _timer.elapsed.inSeconds,
            stepsAnswered: checkIn.stepsAnswered,
          ),
    );
    if (mounted) Navigator.of(context).pop(checkIn);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final name = widget.firstName;
    final (question, options) = switch (_step) {
      0 => (
        name == null || name.isEmpty
            ? l.checkinMoodQuestion
            : l.checkinMoodQuestionNamed(name),
        [
          (1, l.checkinMood1, Icons.sentiment_very_dissatisfied_outlined),
          (2, l.checkinMood2, Icons.sentiment_dissatisfied_outlined),
          (3, l.checkinMood3, Icons.sentiment_neutral_outlined),
          (4, l.checkinMood4, Icons.sentiment_satisfied_outlined),
          (5, l.checkinMood5, Icons.sentiment_very_satisfied_outlined),
        ],
      ),
      1 => (
        l.checkinEnergyQuestion,
        _scale([
          l.checkinEnergy1,
          l.checkinEnergy2,
          l.checkinEnergy3,
          l.checkinEnergy4,
          l.checkinEnergy5,
        ]),
      ),
      2 => (
        l.checkinSleepQuestion,
        _scale([
          l.checkinSleep1,
          l.checkinSleep2,
          l.checkinSleep3,
          l.checkinSleep4,
          l.checkinSleep5,
        ]),
      ),
      3 => (
        l.checkinStressQuestion,
        _scale([
          l.checkinStress1,
          l.checkinStress2,
          l.checkinStress3,
          l.checkinStress4,
          l.checkinStress5,
        ]),
      ),
      4 => (
        l.checkinTimeQuestion,
        [
          for (final m in timeOptions)
            (m, l.checkinMinutes(m), null as IconData?),
        ],
      ),
      _ => (l.checkinBarrierQuestion, const <(int, String, IconData?)>[]),
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        LwSpacing.screenGutter,
        0,
        LwSpacing.screenGutter,
        LwSpacing.screenGutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressDots(
            step: _step,
            total: CheckInSheet.steps,
            label: l.checkinStepOf(_step + 1, CheckInSheet.steps),
          ),
          const SizedBox(height: LwSpacing.md),
          Semantics(header: true, child: Text(question, style: t.titleLarge)),
          const SizedBox(height: LwSpacing.md),
          if (_step < 5)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (value, label, icon)) in options.indexed) ...[
                  if (i > 0) const SizedBox(width: LwSpacing.xs),
                  Expanded(
                    child: _Option(
                      key: Key('checkin-option-$_step-$value'),
                      label: label,
                      semanticsLabel: _step == 4
                          ? l.checkinMinutesLong(value)
                          : label,
                      icon: icon,
                      number: icon == null && _step < 4 ? value : null,
                      onTap: () => _answer(value),
                    ),
                  ),
                ],
              ],
            )
          else ...[
            TextField(
              key: const Key('checkin-barrier'),
              controller: _barrier,
              maxLength: barrierMaxLength,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l.checkinBarrierHint),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _toggleDictation,
                icon: Icon(
                  _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                ),
                label: Text(_listening ? l.whyListening : l.checkinSpeak),
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
            FilledButton(
              onPressed: _saving ? null : _finish,
              child: Text(l.checkinDone),
            ),
          ],
          if (_step > 0) ...[
            const SizedBox(height: LwSpacing.sm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: LwSpacing.xs,
              children: [
                if (_step < 5)
                  TextButton(
                    onPressed: _saving ? null : _skipQuestion,
                    child: Text(l.checkinSkipQuestion),
                  ),
                TextButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(l.checkinSkipForNow),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static List<(int, String, IconData?)> _scale(List<String> labels) => [
    for (final (i, label) in labels.indexed) (i + 1, label, null),
  ];
}

/// One answer: a face or number above a text label. Never icon-only.
class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.icon,
    this.number,
  });

  final String label;
  final String semanticsLabel;
  final IconData? icon;
  final int? number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: LwRadius.mdAll,
          side: BorderSide(color: p.outlineStrong),
        ),
        child: InkWell(
          borderRadius: LwRadius.mdAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: LwSize.minTapTarget + LwSpacing.lg,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LwSpacing.sm,
                horizontal: LwSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(icon, size: LwSize.iconMd * 1.5, color: p.primary),
                  if (number != null)
                    Text(
                      '$number',
                      style: t.titleLarge?.copyWith(color: p.primary),
                    ),
                  const SizedBox(height: LwSpacing.xxs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: t.labelSmall?.copyWith(color: p.textPrimary),
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

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: LwSpacing.xxs),
              width: i == step ? LwSpacing.md : LwSpacing.xs,
              height: LwSpacing.xs,
              decoration: BoxDecoration(
                color: i <= step ? p.primary : p.outlineSoft,
                borderRadius: LwRadius.pillAll,
              ),
            ),
        ],
      ),
    );
  }
}
