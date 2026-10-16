import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/speech_bubble.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/avatar_repository.dart';
import '../domain/avatar_config.dart';

export '../../../core/design/avatar/avatar_art.dart' show AvatarExpression;

/// The person's coach avatar from users/{uid}/avatar/current, or the
/// friendly default until they have made one (never a guessed look, D-28).
final coachAvatarConfigProvider = FutureProvider<AvatarConfig>((ref) async {
  try {
    return await ref.watch(avatarRepositoryProvider).load() ?? defaultCoach;
  } catch (_) {
    // Offline or unreadable: the default look, never an error on screen.
    return defaultCoach;
  }
});

/// The design's default coach: the neutral look in a green top.
final defaultCoach = AvatarConfig.fallback.copyWith(clothingColour: 0);

/// The coach with an [expression] and an optional speech [bubble]
/// (T-UI-02b), used on Home, Care and the Studio. The bubble sits beside
/// the coach, or below it when there isn't room (small phones, large text).
/// TODO(T-AVT-01): the stylized renderer and final character art
/// (docs/design/asset-brief.md) replace the drawn placeholder.
class CoachAvatar extends ConsumerWidget {
  const CoachAvatar({
    super.key,
    this.expression = AvatarExpression.happy,
    this.bubble,
    this.size = 120,
    this.config,
  });

  final AvatarExpression expression;
  final String? bubble;
  final double size;

  /// Shows this look instead of the saved one (previews, the Studio).
  final AvatarConfig? config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look =
        config ?? ref.watch(coachAvatarConfigProvider).value ?? defaultCoach;
    final face = AvatarView(
      key: Key('coach-avatar-${expression.name}'),
      config: look,
      size: size,
      expression: expression,
      semanticLabel: l.coachAvatarLabel,
    );
    if (bubble == null) return face;
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final beside = c.maxWidth >= size + 180 && scale <= 1.3;
        final speech = SpeechBubble(
          key: const Key('coach-bubble'),
          text: bubble!,
          tail: beside ? BubbleTail.left : BubbleTail.bottom,
        );
        if (beside) {
          return Row(
            children: [
              face,
              const SizedBox(width: LwSpacing.xs),
              Expanded(child: speech),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            speech,
            const SizedBox(height: LwSpacing.xs),
            face,
          ],
        );
      },
    );
  }
}
