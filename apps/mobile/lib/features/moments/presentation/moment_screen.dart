import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/domain/coach_face.dart';
import '../../avatar/presentation/coach_avatar.dart'
    show avatarIdleMotionProvider, coachBackgroundProvider, coachImagesProvider;
import '../../routine/application/routine_moment.dart';
import '../../routine/presentation/routine_sheets.dart' show iconFor;
import '../../voice/presentation/voice_screen.dart' show AiVoiceLabel;
import '../application/coach_state.dart';
import '../application/moment_context.dart';
import '../application/moment_launcher.dart';
import '../data/coach_speaker.dart';
import '../domain/coach_message.dart';

/// The avatar's face for a moment's emotion. "Encouraging" uses the happy
/// face until the art kit has its own (T-AVT-06).
AvatarExpression expressionFor(CoachEmotion e) => switch (e) {
  CoachEmotion.waving => AvatarExpression.waving,
  CoachEmotion.happy || CoachEmotion.encouraging => AvatarExpression.happy,
  CoachEmotion.calm => AvatarExpression.calm,
  CoachEmotion.listening => AvatarExpression.listening,
  CoachEmotion.celebrating => AvatarExpression.celebrating,
};

String actionLabel(AppLocalizations l, MomentAction a) => switch (a) {
  MomentAction.checkIn => l.momentActionCheckIn,
  MomentAction.startStep => l.momentActionStartStep,
  MomentAction.makeSmaller => l.momentActionMakeSmaller,
  MomentAction.done => l.momentActionDone,
  MomentAction.notToday => l.momentActionNotToday,
  MomentAction.close => l.momentActionClose,
  MomentAction.reply => l.momentActionReply,
  MomentAction.restart => l.momentActionRestart,
  MomentAction.seeWeek => l.momentActionSeeWeek,
};

/// The full-screen Avatar Moment (T-DLY-03b): the coach large on their
/// background speaks the message, the words appear in the bubble as they
/// are said (captions always), and the moment's buttons sit at the bottom.
/// Pops with the [MomentAction] chosen, or null.
///
/// Fallbacks (FR-AVT-05): voice + moving avatar → still avatar + voice
/// (reduced motion) → text only (muted, or the voice can't start).
class MomentScreen extends ConsumerStatefulWidget {
  const MomentScreen({super.key, required this.moment, this.routine});

  final Moment moment;

  /// A routine reminder's payload, for [Moment.routineItem] (T-GOL-03d).
  final String? routine;

  static String pathFor(Moment m) => '/moment/${m.file}';

  /// The moment of a routine reminder (T-GOL-03d).
  static String routinePath(String payload) =>
      '/moment/${Moment.routineItem.file}?r=${Uri.encodeQueryComponent(payload)}';

  @override
  ConsumerState<MomentScreen> createState() => _MomentScreenState();
}

enum _Phase { idle, speaking, paused, done }

class _MomentScreenState extends ConsumerState<MomentScreen> {
  _Phase _phase = _Phase.idle;
  bool _muted = false;
  bool _textOnly = false;
  int _revealed = 0;

  /// The talking mouth (kept from T-AVT-06b): the vowels of the word being
  /// said, from the engine's word timing, else the caption pace.
  MouthShape? _mouth;
  int _wordAt = 0;
  int _tick = 0;
  Timer? _lips;
  Timer? _reveal;
  CoachMessage? _message;
  late final CoachSpeaker _speaker;

  @override
  void initState() {
    super.initState();
    // Read now: dispose (which stops the voice) must not use ref.
    _speaker = ref.read(coachSpeakerProvider);
    // Muted in an earlier moment: text only until the voice is turned on.
    _muted = ref.read(coachMutedProvider);
  }

  bool get _stillAvatar => MediaQuery.of(context).disableAnimations;

  @override
  void dispose() {
    _stopTimers();
    _speaker.stop();
    super.dispose();
  }

  void _stopTimers() {
    _lips?.cancel();
    _reveal?.cancel();
    _lips = _reveal = null;
    _mouth = null;
  }

  Future<void> _play(CoachMessage m) async {
    _stopTimers();
    final speed = await ref.read(coachVoiceSpeedProvider.future);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.speaking;
      _textOnly = false;
      // Reduced motion: the whole text at once, still avatar.
      _revealed = _stillAvatar ? m.text.length : 0;
    });
    final ok = await _speaker.speak(
      m,
      speed: speed,
      onWord: (start, end) {
        _wordAt = start;
        _tick = 0;
        if (mounted && end > _revealed) setState(() => _revealed = end);
      },
      onDone: () {
        if (!mounted) return;
        _stopTimers();
        setState(() {
          _phase = _Phase.done;
          _revealed = m.text.length;
        });
      },
    );
    if (!mounted) return;
    if (!ok) {
      // The voice can't start: the message as text (FR-AVT-05).
      _stopTimers();
      setState(() {
        _textOnly = true;
        _phase = _Phase.done;
        _revealed = m.text.length;
      });
      return;
    }
    if (_stillAvatar || _phase != _Phase.speaking) return;
    // The mouth follows the words while the coach speaks (the avatar
    // blinks by itself).
    _wordAt = 0;
    _tick = 0;
    _lips = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (!mounted) return;
      setState(() {
        final at = _wordAt > 0
            ? _wordAt
            : (_revealed - 1).clamp(0, m.text.length);
        _mouth = visemeAt(m.text, at, _tick++);
      });
    });
    // Engines that don't report words: reveal at a speaking pace.
    final perTick = (m.text.length / (m.text.split(' ').length / 2.6 / speed))
        .clamp(4, 60)
        .round();
    _reveal = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _Phase.speaking) return;
      setState(() => _revealed = (_revealed + perTick).clamp(0, m.text.length));
    });
  }

  Future<void> _toggleMute(CoachMessage m) async {
    ref.read(coachMutedProvider.notifier).set(!_muted);
    if (_muted) {
      setState(() => _muted = false);
      await _play(m);
    } else {
      await _finish(mute: true);
    }
  }

  Future<void> _pause() async {
    await _speaker.pause();
    _stopTimers();
    if (mounted) setState(() => _phase = _Phase.paused);
  }

  /// Stops the voice and shows the whole message.
  Future<void> _finish({bool mute = false}) async {
    await _speaker.stop();
    _stopTimers();
    if (!mounted) return;
    setState(() {
      if (mute) _muted = true;
      _phase = _Phase.done;
      _revealed = _message?.text.length ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final routine = widget.moment == Moment.routineItem;
    final async = routine
        ? ref.watch(routineMessageProvider(widget.routine ?? ''))
        : ref.watch(coachMessageProvider(widget.moment));
    final background = ref.watch(coachBackgroundProvider);
    final m = async.value;
    if (m != null && _message == null) {
      _message = m;
      if (_muted) {
        _phase = _Phase.done;
        _revealed = m.text.length;
      }
      // Speaks automatically when the moment opens (setting in T-DLY-03e).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_muted) _play(m);
      });
      // Played: the morning card on Home and the reminder go (T-DLY-03c).
      if (widget.moment == Moment.morning ||
          widget.moment == Moment.missedDay) {
        ref.read(momentLauncherProvider).morningSeen();
      }
    }
    final speaking = _phase == _Phase.speaking;
    final voiceOn = !_muted && !_textOnly;
    // Talking: the neutral face with the mouth frames; at rest, the
    // moment's expression. Reduced motion: the player shows a still face.
    final face = speaking && !_stillAvatar
        ? AvatarExpression.talking
        : m == null
        ? AvatarExpression.happy
        // Some moments change face once said (the first hello waves, then
        // smiles).
        : expressionFor(
            _phase == _Phase.done ? m.thenEmotion ?? m.emotion : m.emotion,
          );
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxHeight - LwSpacing.screenGutter * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        voiceOn: voiceOn,
                        muted: _muted,
                        onClose: () => Navigator.of(context).pop(),
                        onMute: m == null ? null : () => _toggleMute(m),
                      ),
                      const SizedBox(height: LwSpacing.md),
                      if (async.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (m == null)
                        Padding(
                          padding: const EdgeInsets.all(LwSpacing.lg),
                          child: Text(
                            l.momentNone,
                            key: const Key('moment-none'),
                            textAlign: TextAlign.center,
                            style: t.titleMedium?.copyWith(
                              color: LwPalette.light.textPrimary,
                            ),
                          ),
                        )
                      else ...[
                        _Bubble(text: m.text, revealed: _revealed),
                        // The items by name, as text only: a custom label
                        // is never spoken (FR-VOC-05).
                        if (routine) ...[
                          const SizedBox(height: LwSpacing.xs),
                          _RoutineItems(payload: widget.routine ?? ''),
                        ],
                        if (_textOnly) ...[
                          const SizedBox(height: LwSpacing.xs),
                          Text(
                            l.momentTextOnly,
                            key: const Key('moment-text-only'),
                            textAlign: TextAlign.center,
                            style: t.bodySmall?.copyWith(
                              color: LwPalette.light.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: LwSpacing.md),
                        Center(
                          child: LayoutBuilder(
                            builder: (context, b) => AvatarView(
                              key: const Key('moment-avatar'),
                              images: ref.watch(coachImagesProvider).value,
                              background: background,
                              expression: face,
                              mouth: speaking ? _mouth : null,
                              animate: ref.watch(avatarIdleMotionProvider),
                              size: (b.maxWidth * 0.62).clamp(140, 260),
                              semanticLabel: l.coachAvatarLabel,
                            ),
                          ),
                        ),
                        const SizedBox(height: LwSpacing.sm),
                        _Controls(
                          phase: _phase,
                          voiceOn: voiceOn,
                          onPause: _pause,
                          onPlay: () => _play(m),
                          onSkip: () => _finish(),
                        ),
                      ],
                    ],
                  ),
                  if (m != null) ...[
                    const SizedBox(height: LwSpacing.lg),
                    FilledButton(
                      key: Key('moment-action-${m.primaryAction.name}'),
                      onPressed: () =>
                          Navigator.of(context).pop(m.primaryAction),
                      child: Text(actionLabel(l, m.primaryAction)),
                    ),
                    for (final a in m.secondaryActions)
                      Padding(
                        padding: const EdgeInsets.only(top: LwSpacing.xs),
                        child: TextButton(
                          key: Key('moment-action-${a.name}'),
                          style: TextButton.styleFrom(
                            foregroundColor: LwPalette.light.primaryDark,
                          ),
                          onPressed: () => Navigator.of(context).pop(a),
                          child: Text(actionLabel(l, a)),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.voiceOn,
    required this.muted,
    required this.onClose,
    required this.onMute,
  });

  final bool voiceOn;
  final bool muted;
  final VoidCallback onClose;
  final VoidCallback? onMute;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The art backgrounds are light pastels in both themes: dark ink.
    final ink = LwPalette.light.textPrimary;
    return Row(
      children: [
        IconButton(
          key: const Key('moment-close'),
          tooltip: l.momentClose,
          onPressed: onClose,
          icon: Icon(Icons.close, color: ink),
        ),
        const Spacer(),
        // The "AI voice" label whenever the voice plays (FR-VOC-08).
        if (voiceOn) const AiVoiceLabel(),
        IconButton(
          key: const Key('moment-mute'),
          tooltip: muted ? l.momentUnmute : l.momentMute,
          onPressed: onMute,
          icon: Icon(
            muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            color: ink,
          ),
        ),
      ],
    );
  }
}

/// The speech bubble. Words appear as they are spoken; the rest is laid out
/// but invisible so the bubble doesn't jump. Screen readers get the whole
/// message at once (captions, NFR-06).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.revealed});

  final String text;
  final int revealed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final light = LwPalette.light;
    final shown = revealed.clamp(0, text.length);
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        key: const Key('moment-bubble'),
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        decoration: BoxDecoration(
          color: light.surface,
          borderRadius: LwRadius.lgAll,
          boxShadow: LwShadow.soft,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text.substring(0, shown)),
              TextSpan(
                text: text.substring(shown),
                style: TextStyle(color: light.textPrimary.withValues(alpha: 0)),
              ),
            ],
          ),
          key: const Key('moment-text'),
          style: t.titleMedium?.copyWith(color: light.textPrimary),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.voiceOn,
    required this.onPause,
    required this.onPlay,
    required this.onSkip,
  });

  final _Phase phase;
  final bool voiceOn;
  final VoidCallback onPause;
  final VoidCallback onPlay;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ink = LwPalette.light.primaryDark;
    final speaking = phase == _Phase.speaking;
    if (!voiceOn) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: Key(speaking ? 'moment-pause' : 'moment-play'),
          tooltip: speaking
              ? l.momentPause
              : (phase == _Phase.done ? l.momentReplay : l.momentPlay),
          onPressed: speaking ? onPause : onPlay,
          icon: Icon(
            speaking
                ? Icons.pause_circle_outline
                : (phase == _Phase.done
                      ? Icons.replay_circle_filled_outlined
                      : Icons.play_circle_outline),
            color: ink,
            size: LwSize.iconMd * 1.4,
          ),
        ),
        if (speaking)
          TextButton(
            key: const Key('moment-skip'),
            style: TextButton.styleFrom(foregroundColor: ink),
            onPressed: onSkip,
            child: Text(l.momentSkip),
          ),
      ],
    );
  }
}

/// The items of a routine reminder, by name (T-GOL-03d).
class _RoutineItems extends ConsumerWidget {
  const _RoutineItems({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final ink = LwPalette.light;
    final items = ref.watch(routineReminderItemsProvider(payload)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('moment-routine-items'),
      padding: const EdgeInsets.all(LwSpacing.sm),
      decoration: BoxDecoration(
        color: ink.surface.withValues(alpha: 0.9),
        borderRadius: LwRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.routineMomentItems,
            style: t.labelMedium?.copyWith(color: ink.textSecondary),
          ),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: LwSpacing.xxs),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(iconFor(i.icon), color: ink.primaryDark),
                  ),
                  const SizedBox(width: LwSpacing.xs),
                  Expanded(
                    child: Text(
                      i.label,
                      style: t.titleSmall?.copyWith(color: ink.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
