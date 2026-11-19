import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../domain/portal_offer.dart';

/// Review status in words (never colour alone), plus "Live in app" when
/// app users can see the offer.
class StatusChips extends StatelessWidget {
  const StatusChips({super.key, required this.offer});

  final PortalOffer offer;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return Wrap(
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xxs,
      children: [
        _Chip(
          label: offer.status.label,
          background: switch (offer.status) {
            ReviewStatus.approved => p.primaryTint,
            ReviewStatus.inReview => p.accentTint,
            ReviewStatus.rejected => p.rose,
            ReviewStatus.draft || ReviewStatus.archived => p.surfaceMuted,
          },
          foreground: switch (offer.status) {
            ReviewStatus.approved => p.onPrimaryTint,
            ReviewStatus.inReview => p.onAccentTint,
            ReviewStatus.rejected => p.onTint,
            ReviewStatus.draft || ReviewStatus.archived => p.textPrimary,
          },
        ),
        if (offer.isLive)
          _Chip(
            key: const Key('live-chip'),
            label: 'Live in app',
            background: p.primary,
            foreground: p.onPrimary,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: LwSpacing.xs,
      vertical: LwSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: LwRadius.pillAll,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: foreground),
    ),
  );
}
