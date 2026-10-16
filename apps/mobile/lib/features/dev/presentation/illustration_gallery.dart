import 'package:flutter/material.dart';

import '../../../core/design/components/speech_bubble.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../avatar/presentation/coach_avatar.dart';

/// Dev-flavour screen showing every illustration in the manifest and the
/// coach in all 6 expressions (T-UI-02b), for review on a phone. Not
/// reachable in staging or prod.
class IllustrationGallery extends StatelessWidget {
  const IllustrationGallery({super.key});

  static const path = '/dev/illustrations';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Illustrations')),
      body: FutureBuilder<IllustrationCatalog>(
        future: IllustrationCatalog.load(),
        initialData: IllustrationCatalog.current,
        builder: (context, snap) {
          final entries = snap.data?.entries.toList() ?? const [];
          final kinds = {for (final e in entries) e.kind};
          final finals = entries.where((e) => e.isFinal).length;
          return ListView(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            children: [
              Text(
                '${entries.length} assets · $finals final · '
                '${entries.length - finals} placeholder',
                style: t.bodyMedium?.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: LwSpacing.md),
              Text('Coach expressions', style: t.titleMedium),
              const SizedBox(height: LwSpacing.xs),
              Wrap(
                spacing: LwSpacing.sm,
                runSpacing: LwSpacing.sm,
                children: [
                  for (final x in AvatarExpression.values)
                    Column(
                      children: [
                        CoachAvatar(
                          expression: x,
                          size: 88,
                          config: defaultCoach,
                        ),
                        Text(x.name, style: t.labelSmall),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: LwSpacing.md),
              CoachAvatar(
                expression: AvatarExpression.waving,
                config: defaultCoach,
                size: 96,
                bubble: 'Good morning! Let\'s make today a great day.',
              ),
              const SizedBox(height: LwSpacing.sm),
              const SpeechBubble(
                text: 'Bubble with its tail at the bottom.',
                tail: BubbleTail.bottom,
              ),
              for (final kind in kinds) ...[
                const SizedBox(height: LwSpacing.lg),
                Text(kind, style: t.titleMedium),
                const SizedBox(height: LwSpacing.xs),
                Wrap(
                  spacing: LwSpacing.xs,
                  runSpacing: LwSpacing.xs,
                  children: [
                    for (final e in entries.where((e) => e.kind == kind))
                      SizedBox(
                        width: 96,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Illustration(e.id, width: 96, height: 72),
                            Text(
                              e.id,
                              style: t.labelSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
