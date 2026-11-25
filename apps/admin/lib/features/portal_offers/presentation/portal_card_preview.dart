import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../domain/portal_offer.dart';

/// What app users will see: the app's portal card (apps/mobile
/// `PortalCard`, spec 13.4), drawn with the same tokens and words, so
/// reviewers approve the real thing. Always labelled "From the Live Well
/// Portal"; paid offers show the price as entered or "Paid course"; "Not
/// now" is as big as "View course". Keep in step with the app's card
/// (needs a shared package later; D-92).
///
/// The buttons are inert here and hidden from screen readers; the whole
/// card is announced as a preview.
class PortalCardPreview extends StatelessWidget {
  const PortalCardPreview({
    super.key,
    required this.fields,
    this.secondary = false,
  });

  final OfferFields fields;

  /// The quiet style used at the end of a lesson (D-74).
  final bool secondary;

  static const eyebrow = 'From the Live Well Portal';
  static const paidCourse = 'Paid course';
  static const freeLesson = 'Free lesson';

  static String priceLabel(OfferFields o) => o.offerType == OfferType.freeLesson
      ? freeLesson
      : o.priceDisplay.trim().isNotEmpty
      ? o.priceDisplay.trim()
      : paidCourse;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final quiet = secondary;
    final background = quiet ? p.surface : p.heroSurface;
    final onBackground = quiet ? p.textPrimary : p.onHeroSurface;
    final onBackgroundSecondary = quiet
        ? p.textSecondary
        : p.onHeroSurfaceSecondary;
    const buttonSize = Size.fromHeight(LwSize.buttonHeight);
    final outlined = OutlinedButton.styleFrom(
      minimumSize: buttonSize,
      foregroundColor: onBackground,
      side: BorderSide(color: onBackgroundSecondary),
    );
    final title = fields.title.trim().isEmpty ? 'Title' : fields.title.trim();
    final description = fields.description.trim();
    return Semantics(
      container: true,
      label: 'Preview of the app card',
      child: Container(
        key: const Key('portal-card-preview'),
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        decoration: BoxDecoration(
          color: background,
          borderRadius: LwRadius.lgAll,
          border: quiet ? Border.all(color: p.outlineSoft) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xxs,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: onBackgroundSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LwSpacing.xs,
                    vertical: LwSpacing.xxs / 2,
                  ),
                  decoration: BoxDecoration(
                    color: onBackground,
                    borderRadius: LwRadius.pillAll,
                  ),
                  child: Text(
                    priceLabel(fields),
                    key: const Key('preview-price'),
                    style: t.labelSmall?.copyWith(color: background),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LwSpacing.xs),
            Text(title, style: t.titleLarge?.copyWith(color: onBackground)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: LwSpacing.xxs),
              Text(
                description,
                style: t.bodySmall?.copyWith(color: onBackgroundSecondary),
              ),
            ],
            const SizedBox(height: LwSpacing.md),
            ExcludeSemantics(
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (quiet)
                      OutlinedButton(
                        style: outlined,
                        onPressed: () {},
                        child: const Text('View course'),
                      )
                    else
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: buttonSize),
                        onPressed: () {},
                        child: const Text('View course'),
                      ),
                    const SizedBox(height: LwSpacing.xs),
                    OutlinedButton(
                      style: outlined,
                      onPressed: () {},
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
