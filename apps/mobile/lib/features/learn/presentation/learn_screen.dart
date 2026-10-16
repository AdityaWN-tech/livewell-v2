import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_button.dart';
import '../application/learn_data.dart';
import '../data/learn_repository.dart';
import '../domain/lesson.dart';
import '../domain/portal.dart';

/// Learn tab (T-UI-01e, Screen 4): one portal card when every spec 13.3
/// check passes, then the curated library.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  static const libraryPath = '/learn/library';

  /// Lessons shown on the tab before "View all".
  static const preview = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final offer = ref.watch(portalCardProvider);
    final lessons = ref.watch(lessonsProvider).value ?? const <Lesson>[];
    final t = Theme.of(context).textTheme;
    return LwScreen(
      eyebrow: l.learnEyebrow,
      title: l.tabLearn,
      profile: const ProfileButton(),
      children: [
        if (offer != null) ...[
          _PortalCard(key: ValueKey(offer.id), offer: offer),
          const SizedBox(height: LwSpacing.lg),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(l.learnLibrary, style: t.titleSmall),
            ),
            if (lessons.length > preview)
              TextButton(
                key: const Key('learn-view-all'),
                onPressed: () => context.push(libraryPath),
                child: Text(l.learnViewAll(lessons.length)),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.xs),
        if (lessons.isEmpty)
          LwEmptyState(
            icon: Icons.menu_book_outlined,
            title: l.learnLessonsEmptyTitle,
            body: l.learnLessonsEmptyBody,
          )
        else
          for (final lesson in lessons.take(preview)) ...[
            LessonRow(lesson),
            const SizedBox(height: LwSpacing.sm),
          ],
      ],
    );
  }
}

/// "From the Live Well Portal" (spec 13.4): always labelled, paid offers say
/// so, and "Not now" is as big and visible as "View course".
class _PortalCard extends ConsumerStatefulWidget {
  const _PortalCard({super.key, required this.offer});
  final PortalOffer offer;

  @override
  ConsumerState<_PortalCard> createState() => _PortalCardState();
}

class _PortalCardState extends ConsumerState<_PortalCard> {
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
      ref.read(learnRepositoryProvider).logEvent('card_shown', widget.offer.id);
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
        .logEvent('clicked', widget.offer.id, clickId: clickId);
    final url = PortalEligibility.attributionUrl(
      widget.offer,
      context: 'learn',
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

  Future<void> _notNow() =>
      ref.read(learnRepositoryProvider).logEvent('dismissed', widget.offer.id);

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final o = widget.offer;
    final label = o.isFree
        ? l.learnFreeLesson
        : (o.priceDisplay?.isNotEmpty ?? false)
        ? o.priceDisplay!
        : l.learnPaidCourse;
    const buttonSize = Size.fromHeight(LwSize.buttonHeight);
    return Container(
      key: const Key('portal-card'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(
        color: p.heroSurface,
        borderRadius: LwRadius.lgAll,
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
                style: t.labelSmall?.copyWith(color: p.onHeroSurfaceSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: LwSpacing.xs,
                  vertical: LwSpacing.xxs / 2,
                ),
                decoration: BoxDecoration(
                  color: p.onHeroSurface,
                  borderRadius: LwRadius.pillAll,
                ),
                child: Text(
                  label,
                  key: const Key('portal-price'),
                  style: t.labelSmall?.copyWith(color: p.heroSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(o.title, style: t.titleLarge?.copyWith(color: p.onHeroSurface)),
          if (o.description != null) ...[
            const SizedBox(height: LwSpacing.xxs),
            Text(
              o.description!,
              style: t.bodySmall?.copyWith(color: p.onHeroSurfaceSecondary),
            ),
          ],
          const SizedBox(height: LwSpacing.md),
          FilledButton(
            key: const Key('portal-view'),
            style: FilledButton.styleFrom(minimumSize: buttonSize),
            onPressed: _view,
            child: Text(l.learnViewCourse),
          ),
          const SizedBox(height: LwSpacing.xs),
          OutlinedButton(
            key: const Key('portal-not-now'),
            style: OutlinedButton.styleFrom(
              minimumSize: buttonSize,
              foregroundColor: p.onHeroSurface,
              side: BorderSide(color: p.onHeroSurfaceSecondary),
            ),
            onPressed: _notNow,
            child: Text(l.learnNotNow),
          ),
        ],
      ),
    );
  }
}

/// One lesson in the library list. Not tappable until the lesson reader
/// exists (T-LRN-01).
class LessonRow extends StatelessWidget {
  const LessonRow(this.lesson, {super.key});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Card(
      key: Key('lesson-${lesson.id}'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: LwSize.avatarSm,
                height: LwSize.avatarSm,
                decoration: BoxDecoration(
                  color: p.heroSurface,
                  borderRadius: LwRadius.smAll,
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  size: LwSize.iconSm,
                  color: p.onHeroSurface,
                ),
              ),
            ),
            const SizedBox(width: LwSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: LwSpacing.xs,
                    children: [
                      Text(
                        lesson.category.toUpperCase(),
                        style: t.labelSmall?.copyWith(color: p.accentStrong),
                      ),
                      if (lesson.readMinutes != null)
                        Text(
                          l.learnReadTime(lesson.readMinutes!),
                          style: t.labelSmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: LwSpacing.xxs),
                  Text(lesson.title, style: t.titleSmall),
                  if (lesson.summary != null)
                    Text(lesson.summary!, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
