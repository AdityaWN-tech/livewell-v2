import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/design/tokens.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../data/portal_offers_api.dart';
import '../domain/portal_offer.dart';
import 'status_chip.dart';

/// Which offers the list shows.
enum OfferFilter {
  all('All'),
  needsReview('In review'),
  live('Live in app'),
  drafts('Drafts'),
  archived('Archived');

  const OfferFilter(this.label);
  final String label;

  bool matches(PortalOffer o) => switch (this) {
    all => o.status != ReviewStatus.archived,
    needsReview => o.status == ReviewStatus.inReview,
    live => o.isLive,
    drafts =>
      o.status == ReviewStatus.draft || o.status == ReviewStatus.rejected,
    archived => o.status == ReviewStatus.archived,
  };
}

class OfferFilterNotifier extends Notifier<OfferFilter> {
  @override
  OfferFilter build() => OfferFilter.all;

  void select(OfferFilter f) => state = f;
}

final offerFilterProvider = NotifierProvider<OfferFilterNotifier, OfferFilter>(
  OfferFilterNotifier.new,
);

/// The portal catalog (spec 13.2): every offer with its review status.
class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value;
    final offers = ref.watch(portalOffersProvider);
    final filter = ref.watch(offerFilterProvider);
    final t = Theme.of(context).textTheme;
    final canCreate = me != null && me.hasAny(editRoles);
    return AdminScaffold(
      title: 'Portal catalog',
      actions: [
        IconButton(
          key: const Key('offers-refresh'),
          tooltip: 'Reload',
          onPressed: () => ref.invalidate(portalOffersProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: LwSpacing.sm,
            spacing: LwSpacing.md,
            children: [
              Text(
                'Offers app users can be shown after review. Only approved '
                'offers that are published appear in the app.',
                style: t.bodyMedium,
              ),
              if (canCreate)
                FilledButton.icon(
                  key: const Key('offer-new'),
                  onPressed: () => context.go('/offers/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New offer'),
                ),
            ],
          ),
          const SizedBox(height: LwSpacing.md),
          Wrap(
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xs,
            children: [
              for (final f in OfferFilter.values)
                ChoiceChip(
                  key: Key('filter-${f.name}'),
                  label: Text(f.label),
                  selected: filter == f,
                  onSelected: (_) =>
                      ref.read(offerFilterProvider.notifier).select(f),
                ),
            ],
          ),
          const SizedBox(height: LwSpacing.md),
          Expanded(
            child: switch (offers) {
              AsyncData(:final value) => _List(
                offers: value.where(filter.matches).toList(),
                empty: value.isEmpty
                    ? 'No offers yet.'
                    : 'No offers match this filter.',
              ),
              AsyncError(:final error) => _Error(
                message: error is ApiFailure
                    ? error.message
                    : 'Could not load the catalog.',
                onRetry: () => ref.invalidate(portalOffersProvider),
              ),
              _ => const Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading'),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.offers, required this.empty});

  final List<PortalOffer> offers;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    if (offers.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(empty, key: const Key('offers-empty'), style: t.bodyMedium),
      );
    }
    return ListView.separated(
      itemCount: offers.length,
      separatorBuilder: (_, _) => Divider(color: p.outlineSoft, height: 1),
      itemBuilder: (context, i) {
        final o = offers[i];
        return ListTile(
          key: Key('offer-row-${o.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: LwSpacing.xs,
            vertical: LwSpacing.xxs,
          ),
          title: Text(o.fields.title, style: t.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: LwSpacing.xxs),
            child: Wrap(
              spacing: LwSpacing.sm,
              runSpacing: LwSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChips(offer: o),
                Text(
                  '${o.fields.offerType.label} · version ${o.version}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/offers/${o.id}'),
        );
      },
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, key: const Key('offers-error')),
        const SizedBox(height: LwSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
