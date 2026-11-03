import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/domain/coach_face.dart';
import '../../avatar/domain/coaches.dart';
import '../../avatar/presentation/coach_avatar.dart';

/// Developer > Avatar frames (dev flavour only, T-AVT-08a): the frame
/// player with the default coach's frame set (placeholders for now): every expression, blinking,
/// breathing, and the mouth frames following a sample line. Nothing is
/// spoken here; the Avatar Moments speak approved lines.
class AvatarFramesGallery extends ConsumerStatefulWidget {
  const AvatarFramesGallery({super.key});

  static const path = '/dev/avatar-frames';

  /// Only for moving the mouth; never sent to text-to-speech.
  static const sample = 'Good morning! Shall we take a short walk today?';

  @override
  ConsumerState<AvatarFramesGallery> createState() =>
      _AvatarFramesGalleryState();
}

class _AvatarFramesGalleryState extends ConsumerState<AvatarFramesGallery> {
  AvatarExpression _expression = AvatarExpression.talking;
  MouthShape? _mouth;
  Timer? _lips;
  int _tick = 0;
  int _at = 0;

  void _talk() {
    _lips?.cancel();
    _tick = 0;
    _at = 0;
    setState(() => _expression = AvatarExpression.talking);
    const text = AvatarFramesGallery.sample;
    _lips = Timer.periodic(const Duration(milliseconds: 160), (t) {
      if (!mounted) return;
      // About 2.6 words a second, like the Moment player's caption pace.
      _at = (t.tick * 160 * text.length / 4500).floor();
      if (_at >= text.length) {
        t.cancel();
        setState(() => _mouth = null);
        return;
      }
      setState(() => _mouth = visemeAt(text, _at, _tick++));
    });
  }

  @override
  void dispose() {
    _lips?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final images = ref
        .watch(readyCoachFramesProvider(ReadyCoach.fallback))
        .value;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('dev-avatar-frames'),
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            LwPageTitle(l.devAvatarFrames),
            Center(
              child: AvatarView(
                key: const Key('dev-avatar-frames-player'),
                images: images,
                expression: _expression,
                mouth: _mouth,
                animate: ref.watch(avatarIdleMotionProvider),
                size: 240,
                semanticLabel: l.coachAvatarLabel,
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
            Text(
              _mouth == null
                  ? _expression.name
                  : '${_expression.name} · ${_mouth!.frame.id}',
              key: const Key('dev-avatar-frames-now'),
              textAlign: TextAlign.center,
              style: t.labelLarge,
            ),
            const SizedBox(height: LwSpacing.md),
            Wrap(
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xs,
              children: [
                for (final e in AvatarExpression.values)
                  ChoiceChip(
                    key: Key('dev-avatar-${e.name}'),
                    label: Text(e.name),
                    selected: _mouth == null && _expression == e,
                    onSelected: (_) {
                      _lips?.cancel();
                      setState(() {
                        _mouth = null;
                        _expression = e;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: LwSpacing.md),
            FilledButton.icon(
              key: const Key('dev-avatar-talk'),
              onPressed: _talk,
              icon: const Icon(Icons.graphic_eq),
              label: Text(l.devAvatarTalk),
            ),
            const SizedBox(height: LwSpacing.xs),
            Text(
              '"${AvatarFramesGallery.sample}"',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
