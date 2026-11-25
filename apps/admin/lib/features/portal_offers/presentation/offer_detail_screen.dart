import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/staff.dart';
import '../../../core/design/admin_layout.dart';
import '../../../core/design/tokens.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../data/portal_offers_api.dart';
import '../domain/portal_offer.dart';
import 'portal_card_preview.dart';
import 'status_chip.dart';

/// One offer: the card as app users will see it, its details, and the
/// review steps the signed-in person may take (D-92).
class OfferDetailScreen extends ConsumerWidget {
  const OfferDetailScreen({super.key, required this.offerId});

  final String offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(portalOffersProvider);
    final me = ref.watch(sessionProvider).value;
    final back = IconButton(
      tooltip: 'Back to the catalog',
      onPressed: () => context.go('/offers'),
      icon: const Icon(Icons.arrow_back),
    );
    final offer = offers.value?.where((o) => o.id == offerId).firstOrNull;
    if (offer == null || me == null) {
      return AdminScaffold(
        title: 'Offer',
        leading: back,
        body: offers.isLoading
            ? const Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading'),
              )
            : const Text(
                'This offer was not found.',
                key: Key('offer-missing'),
              ),
      );
    }
    return AdminScaffold(
      title: offer.fields.title,
      leading: back,
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= AdminLayout.twoColumnBreakpoint;
          final details = _Details(offer: offer, me: me);
          final preview = _Previews(fields: offer.fields);
          return SingleChildScrollView(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: details),
                      const SizedBox(width: LwSpacing.xl),
                      Expanded(flex: 2, child: preview),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: LwSpacing.xl),
                      preview,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Previews extends StatelessWidget {
  const _Previews({required this.fields});

  final OfferFields fields;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('In the app (Learn tab)', style: t.titleSmall),
        ),
        const SizedBox(height: LwSpacing.xs),
        PortalCardPreview(fields: fields),
        const SizedBox(height: LwSpacing.lg),
        Semantics(
          header: true,
          child: Text('At the end of a lesson', style: t.titleSmall),
        ),
        const SizedBox(height: LwSpacing.xs),
        PortalCardPreview(fields: fields, secondary: true),
      ],
    );
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.offer, required this.me});

  final PortalOffer offer;
  final StaffSession me;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  bool _busy = false;

  /// Steps that change what app users see, or end a review, are confirmed.
  static const _confirm = {
    OfferAction.approve:
        'Approve this offer? You confirm the title, description, link and '
        'price are accurate and make no health-outcome claims (spec 13.4).',
    OfferAction.reject: 'Send this offer back to the editor for changes?',
    OfferAction.publish: 'Publish this offer? App users can see it right away.',
    OfferAction.unpublish: 'Take this offer out of the app now?',
    OfferAction.archive: 'Archive this offer? It leaves the app if live.',
  };

  Future<void> _run(OfferAction a) async {
    final question = _confirm[a];
    if (question != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(a.label),
          content: Text(question),
          actions: [
            TextButton(
              key: const Key('confirm-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-ok'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(a.label),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(portalOffersApiProvider)
          .transition(widget.offer.id, widget.offer.rev, a);
      messenger.showSnackBar(SnackBar(content: Text('Done: ${a.label}.')));
    } on ApiFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(portalOffersProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final me = widget.me;
    final t = Theme.of(context).textTheme;
    final actions = actionsFor(o, me);
    final allowed = [
      for (final e in actions.entries)
        if (e.value == null) e.key,
    ];
    // One primary step: the one that moves the offer forward.
    final primary = const [
      OfferAction.approve,
      OfferAction.publish,
      OfferAction.submit,
      OfferAction.restore,
    ].where(allowed.contains).firstOrNull;
    final f = o.fields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusChips(offer: o),
        const SizedBox(height: LwSpacing.md),
        _Row('Type', f.offerType.label),
        _Row('Price shown', PortalCardPreview.priceLabel(f)),
        _Row('Link', f.url),
        _Row(
          'Driver tags',
          f.driverTags.isEmpty ? '—' : f.driverTags.join(', '),
        ),
        _Row('Topic tags', f.topicTags.isEmpty ? '—' : f.topicTags.join(', ')),
        _Row('Version', '${o.version}'),
        const SizedBox(height: LwSpacing.lg),
        if (actions[OfferAction.approve] == ActionBlock.ownOffer)
          Padding(
            padding: const EdgeInsets.only(bottom: LwSpacing.sm),
            child: Text(
              'You edited or sent this version for review, so another '
              'reviewer must approve it.',
              key: const Key('own-offer-note'),
              style: t.bodyMedium,
            ),
          ),
        if (o.status == ReviewStatus.inReview &&
            !me.hasAny(actionRoles[OfferAction.approve]!))
          Padding(
            padding: const EdgeInsets.only(bottom: LwSpacing.sm),
            child: Text(
              'Waiting for a clinical reviewer.',
              key: const Key('waiting-review-note'),
              style: t.bodyMedium,
            ),
          ),
        Wrap(
          spacing: LwSpacing.sm,
          runSpacing: LwSpacing.sm,
          children: [
            for (final a in allowed)
              a == primary
                  ? FilledButton(
                      key: Key('action-${a.id}'),
                      onPressed: _busy ? null : () => _run(a),
                      child: Text(a.label),
                    )
                  : OutlinedButton(
                      key: Key('action-${a.id}'),
                      onPressed: _busy ? null : () => _run(a),
                      child: Text(a.label),
                    ),
            if (canEdit(o, me))
              OutlinedButton.icon(
                key: const Key('action-edit'),
                onPressed: _busy
                    ? null
                    : () => context.go('/offers/${o.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LwSpacing.xs),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AdminLayout.labelColumn,
              child: Text(label, style: t.labelMedium),
            ),
            Expanded(child: Text(value, style: t.bodyLarge)),
          ],
        ),
      ),
    );
  }
}
