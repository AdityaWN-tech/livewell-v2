import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../application/learn_data.dart';
import '../data/learn_repository.dart';
import '../domain/portal.dart';

/// Where a portal card is shown. The name is the `surface` of every
/// portal event and the link's `utm_campaign` (spec 13.2).
enum PortalSurface {
  /// The Learn tab's portal courses section (D-26).
  learn('learn'),

  /// The end of a lesson in the reader (FR-LRN-04, D-74).
  lessonEnd('lesson_end');

  const PortalSurface(this.id);
  final String id;
}

/// "From the Live Well Portal" (spec 13.4): always labelled, paid offers say
/// so, and "Not now" is as big and visible as "View course".
///
/// [secondary] is for screens whose own action stays primary (the lesson
/// reader): a quiet surface, and both buttons outlined, still the same size.
/// Eligibility is decided by the caller (spec 13.3 step 1); this widget only
/// shows the card and logs card_shown, clicked and dismissed with ids only.
class PortalCard extends ConsumerStatefulWidget {
  const PortalCard({
    super.key,
    required this.offer,
    required this.surface,
    this.secondary = false,
  });

  final PortalOffer offer;
  final PortalSurface surface;
  final bool secondary;

  @override
  ConsumerState<PortalCard> createState() => _PortalCardState();
}

class _PortalCardState extends ConsumerState<PortalCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _logShown());
  }

  /// card_shown once a day per offer (the caps count days).
  void _logShown() {
    if (!mounted) return;
    final now = ref.read(clockProvider)();
    final events = ref.read(portalEventsProvider).value ?? const [];
    final shownToday = events.any(
      (e) =>
          e.event == 'card_shown' &&
          e.offerId == widget.offer.id &&
          e.at.year == now.year &&
          e.at.month == now.month &&
          e.at.day == now.day,
    );
    if (!shownToday) {
      ref
          .read(learnRepositoryProvider)
          .logEvent('card_shown', widget.offer.id, surface: widget.surface.id);
    }
  }

  static String _clickId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _view() async {
    final clickId = _clickId();
    await ref
        .read(learnRepositoryProvider)
        .logEvent(
          'clicked',
          widget.offer.id,
          clickId: clickId,
          surface: widget.surface.id,
        );
    final url = PortalEligibility.attributionUrl(
      widget.offer,
      context: widget.surface.id,
      clickId: clickId,
    );
    final opened = await ref.read(portalBrowserProvider).open(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).learnPortalOpenError),
        ),
      );
    }
  }

  Future<void> _notNow() => ref
      .read(learnRepositoryProvider)
      .logEvent('dismissed', widget.offer.id, surface: widget.surface.id);

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final o = widget.offer;
    final quiet = widget.secondary;
    final background = quiet ? p.surface : p.heroSurface;
    final onBackground = quiet ? p.textPrimary : p.onHeroSurface;
    final onBackgroundSecondary = quiet
        ? p.textSecondary
        : p.onHeroSurfaceSecondary;
    final label = o.isFree
        ? l.learnFreeLesson
        : (o.priceDisplay?.isNotEmpty ?? false)
        ? o.priceDisplay!
        : l.learnPaidCourse;
    const buttonSize = Size.fromHeight(LwSize.buttonHeight);
    final outlined = OutlinedButton.styleFrom(
      minimumSize: buttonSize,
      foregroundColor: onBackground,
      side: BorderSide(color: onBackgroundSecondary),
    );
    return Container(
      key: const Key('portal-card'),
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
                l.learnPortalEyebrow.toUpperCase(),
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
                  label,
                  key: const Key('portal-price'),
                  style: t.labelSmall?.copyWith(color: background),
                ),
              ),
            ],
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(o.title, style: t.titleLarge?.copyWith(color: onBackground)),
          if (o.description != null) ...[
            const SizedBox(height: LwSpacing.xxs),
            Text(
              o.description!,
              style: t.bodySmall?.copyWith(color: onBackgroundSecondary),
            ),
          ],
          const SizedBox(height: LwSpacing.md),
          if (quiet)
            OutlinedButton(
              key: const Key('portal-view'),
              style: outlined,
              onPressed: _view,
              child: Text(l.learnViewCourse),
            )
          else
            FilledButton(
              key: const Key('portal-view'),
              style: FilledButton.styleFrom(minimumSize: buttonSize),
              onPressed: _view,
              child: Text(l.learnViewCourse),
            ),
          const SizedBox(height: LwSpacing.xs),
          OutlinedButton(
            key: const Key('portal-not-now'),
            style: outlined,
            onPressed: _notNow,
            child: Text(l.learnNotNow),
          ),
        ],
      ),
    );
  }
}
