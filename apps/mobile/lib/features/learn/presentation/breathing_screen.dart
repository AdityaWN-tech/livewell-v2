import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/learn_repository.dart';
import '../domain/breathing.dart';
import '../domain/lesson.dart';

/// The breathing guide (FR-LRN-03, Step 4e): pick a pattern and a length,
/// then a circle grows as you breathe in and shrinks as you breathe out,
/// with the words and seconds, a light tap on every change (haptics) and
/// the phase read out to screen readers. Built in: works offline with
/// nothing to download. Reduced motion keeps the circle still; the words
/// and seconds still guide.
///
/// Opened from "Breathe with me" on Learn, or from a breathing session
/// ([item]), whose progress is saved.
class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key, this.pattern, this.minutes, this.item});

  static const path = '/learn/breathe';

  /// The lengths offered, in minutes.
  static const lengths = [1, 2, 5];

  final BreathingPattern? pattern;
  final int? minutes;

  /// The audio session this was opened from, or null.
  final Lesson? item;

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

enum _Stage { setup, running, paused, done }

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late BreathingPattern _pattern = widget.pattern ?? BreathingPattern.calm;
  late int _minutes = widget.minutes ?? BreathingScreen.lengths[1];
  _Stage _stage = _Stage.setup;

  late final Ticker _ticker = createTicker(_tick);

  /// Read once: progress is also saved while the screen closes, when ref
  /// can't be used any more.
  late final LearnRepository _learn;

  @override
  void initState() {
    super.initState();
    _learn = ref.read(learnRepositoryProvider);
  }

  /// Time breathed before the last pause.
  Duration _before = Duration.zero;
  Duration _elapsed = Duration.zero;
  BreathPhase? _lastPhase;

  int get _cycles => _pattern.cyclesFor(_minutes);
  Duration get _total => Duration(seconds: _cycles * _pattern.cycleSeconds);

  void _tick(Duration sinceStart) {
    final elapsed = _before + sinceStart;
    if (elapsed >= _total) {
      _finish();
      return;
    }
    final step = _pattern.stepAt(elapsed);
    if (step.phase != _lastPhase) {
      _lastPhase = step.phase;
      HapticFeedback.lightImpact();
      SemanticsService.sendAnnouncement(
        View.of(context),
        _phaseLabel(AppLocalizations.of(context), step.phase),
        Directionality.of(context),
      );
    }
    setState(() => _elapsed = elapsed);
  }

  void _start() {
    setState(() {
      _before = Duration.zero;
      _elapsed = Duration.zero;
      _lastPhase = null;
      _stage = _Stage.running;
    });
    _ticker.start();
  }

  void _pause() {
    _ticker.stop();
    setState(() {
      _before = _elapsed;
      _stage = _Stage.paused;
    });
    _save(completed: false);
  }

  void _resume() {
    setState(() => _stage = _Stage.running);
    _ticker.start();
  }

  void _finish() {
    _ticker.stop();
    HapticFeedback.mediumImpact();
    setState(() {
      _elapsed = _total;
      _stage = _Stage.done;
    });
    _save(completed: true);
  }

  /// Saves where a breathing session is (only when opened from one).
  void _save({required bool completed}) {
    final item = widget.item;
    if (item == null) return;
    final ms = _total.inMilliseconds;
    _learn.saveProgress(
      item.id,
      progress: completed || ms == 0 ? 1 : _elapsed.inMilliseconds / ms,
      completed: completed,
    );
  }

  @override
  void dispose() {
    if (_stage == _Stage.running) {
      _ticker.stop();
      _before = _elapsed;
      _save(completed: false);
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.item?.title ?? l.breatheTitle)),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.setup => _setup(context),
          _Stage.running || _Stage.paused => _session(context),
          _Stage.done => _done(context),
        },
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return ListView(
      key: const Key('breathe-setup'),
      padding: const EdgeInsets.all(LwSpacing.screenGutter),
      children: [
        Text(l.breathePatternLabel, style: t.titleMedium),
        const SizedBox(height: LwSpacing.xs),
        for (final x in BreathingPattern.values)
          Padding(
            padding: const EdgeInsets.only(bottom: LwSpacing.xs),
            child: _PatternTile(
              pattern: x,
              selected: x == _pattern,
              onTap: () => setState(() => _pattern = x),
            ),
          ),
        const SizedBox(height: LwSpacing.md),
        Text(l.breatheLengthLabel, style: t.titleMedium),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final m in {
              ...BreathingScreen.lengths,
              _minutes,
            }.toList()..sort())
              ChoiceChip(
                key: Key('breathe-length-$m'),
                label: Text(l.learnMinutes(m)),
                selected: m == _minutes,
                onSelected: (_) => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.lg),
        _SafetyNote(l.breatheSafety),
        const SizedBox(height: LwSpacing.lg),
        FilledButton(
          key: const Key('breathe-start'),
          onPressed: _start,
          child: Text(l.breatheStart),
        ),
      ],
    );
  }

  Widget _session(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final step = _pattern.stepAt(_elapsed);
    final still = MediaQuery.of(context).disableAnimations;
    final running = _stage == _Stage.running;
    return LayoutBuilder(
      builder: (context, box) {
        final size =
            (box.maxWidth < box.maxHeight * 0.55
                ? box.maxWidth
                : box.maxHeight * 0.55) *
            0.8;
        final scale = still ? 0.8 : 0.45 + 0.55 * step.fullness;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          child: Column(
            key: const Key('breathe-session'),
            children: [
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: Container(
                      key: const Key('breathe-circle'),
                      width: size * scale,
                      height: size * scale,
                      decoration: BoxDecoration(
                        color: p.primaryTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.primary, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: LwSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _phaseLabel(l, step.phase),
                  key: const Key('breathe-phase'),
                  style: t.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                '${step.secondsLeft}',
                key: const Key('breathe-seconds'),
                style: t.displaySmall?.copyWith(color: p.primary),
              ),
              const SizedBox(height: LwSpacing.xs),
              Text(
                l.breatheBreathOf(step.breath, _cycles),
                key: const Key('breathe-count'),
                style: t.bodyMedium,
              ),
              const SizedBox(height: LwSpacing.sm),
              ClipRRect(
                borderRadius: LwRadius.pillAll,
                child: LinearProgressIndicator(
                  value: _elapsed.inMilliseconds / _total.inMilliseconds,
                  minHeight: LwSpacing.xxs,
                  color: p.accent,
                  backgroundColor: p.surfaceMuted,
                ),
              ),
              const SizedBox(height: LwSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: running
                    ? OutlinedButton(
                        key: const Key('breathe-pause'),
                        onPressed: _pause,
                        child: Text(l.breathePause),
                      )
                    : FilledButton(
                        key: const Key('breathe-resume'),
                        onPressed: _resume,
                        child: Text(l.breatheResume),
                      ),
              ),
              const SizedBox(height: LwSpacing.md),
              _SafetyNote(l.breatheSafety),
            ],
          ),
        );
      },
    );
  }

  Widget _done(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    return ListView(
      key: const Key('breathe-done'),
      padding: const EdgeInsets.all(LwSpacing.screenGutter),
      children: [
        const SizedBox(height: LwSpacing.xl),
        Icon(Icons.spa_outlined, size: LwSize.minTapTarget, color: p.primary),
        const SizedBox(height: LwSpacing.md),
        Text(
          l.breatheDoneTitle,
          style: t.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LwSpacing.xs),
        Text(
          l.breatheDoneBody(_cycles),
          style: t.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LwSpacing.xl),
        FilledButton(
          key: const Key('breathe-close'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l.breatheClose),
        ),
        const SizedBox(height: LwSpacing.xs),
        OutlinedButton(
          key: const Key('breathe-again'),
          onPressed: () => setState(() => _stage = _Stage.setup),
          child: Text(l.breatheAgain),
        ),
      ],
    );
  }
}

String _phaseLabel(AppLocalizations l, BreathPhase phase) => switch (phase) {
  BreathPhase.breatheIn => l.breatheIn,
  BreathPhase.holdIn || BreathPhase.holdOut => l.breatheHold,
  BreathPhase.breatheOut => l.breatheOut,
};

/// A pattern's name and its steps ("In 4, out 6").
(String, String) patternText(
  AppLocalizations l,
  BreathingPattern x,
) => switch (x) {
  BreathingPattern.box => (l.breathePatternBox, l.breathePatternBoxSteps),
  BreathingPattern.calm => (l.breathePatternCalm, l.breathePatternCalmSteps),
  BreathingPattern.sleep => (l.breathePatternSleep, l.breathePatternSleepSteps),
};

class _PatternTile extends StatelessWidget {
  const _PatternTile({
    required this.pattern,
    required this.selected,
    required this.onTap,
  });

  final BreathingPattern pattern;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final (name, steps) = patternText(AppLocalizations.of(context), pattern);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        key: Key('breathe-pattern-${pattern.id}'),
        color: selected ? p.primaryTint : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: LwRadius.mdAll,
          side: BorderSide(
            color: selected ? p.primary : p.outlineSoft,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? p.primary : p.textSecondary,
                  ),
                  const SizedBox(width: LwSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: t.titleSmall?.copyWith(
                            color: selected ? p.onPrimaryTint : null,
                          ),
                        ),
                        Text(
                          steps,
                          style: t.bodySmall?.copyWith(
                            color: selected ? p.onPrimaryTint : null,
                          ),
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
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Row(
      key: const Key('breathe-safety'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: LwSize.iconSm, color: p.textSecondary),
        const SizedBox(width: LwSpacing.xs),
        Expanded(child: Text(text, style: t.bodySmall)),
      ],
    );
  }
}
