import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/admin_layout.dart';
import '../../../core/design/tokens.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../data/portal_offers_api.dart';
import '../domain/offer_validation.dart';
import '../domain/portal_offer.dart';
import 'portal_card_preview.dart';

/// New offer, or edit one. Saving an edit takes the offer out of the app
/// and back to draft, so it is reviewed again (D-92). Only content editors
/// and admins reach this screen (router), and the Core API checks again.
class OfferFormScreen extends ConsumerWidget {
  const OfferFormScreen({super.key, this.offerId});

  /// Null for a new offer.
  final String? offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = offerId;
    if (id == null) return const _Form(offer: null);
    final offers = ref.watch(portalOffersProvider);
    final offer = offers.value?.where((o) => o.id == id).firstOrNull;
    if (offer == null) {
      return AdminScaffold(
        title: 'Edit offer',
        body: offers.isLoading
            ? const Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading'),
              )
            : const Text('This offer was not found.'),
      );
    }
    return _Form(key: ValueKey('${offer.id}-${offer.rev}'), offer: offer);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.offer});

  final PortalOffer? offer;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _url;
  late final TextEditingController _price;
  late final TextEditingController _drivers;
  late final TextEditingController _topics;
  late OfferType _type;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.offer?.fields;
    _title = TextEditingController(text: f?.title ?? '');
    _description = TextEditingController(text: f?.description ?? '');
    _url = TextEditingController(
      text: f?.url ?? 'https://${portalHosts.first}/web/courses/',
    );
    _price = TextEditingController(text: f?.priceDisplay ?? '');
    _drivers = TextEditingController(text: f?.driverTags.join(', ') ?? '');
    _topics = TextEditingController(text: f?.topicTags.join(', ') ?? '');
    _type = f?.offerType ?? OfferType.course;
    for (final c in _controllers) {
      c.addListener(_changed);
    }
  }

  List<TextEditingController> get _controllers => [
    _title,
    _description,
    _url,
    _price,
    _drivers,
    _topics,
  ];

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  OfferFields get _fields => OfferFields(
    title: _title.text.trim(),
    description: _description.text.trim(),
    url: _url.text.trim(),
    offerType: _type,
    priceDisplay: _type == OfferType.freeLesson ? '' : _price.text.trim(),
    driverTags: parseTags(_drivers.text),
    topicTags: parseTags(_topics.text),
  );

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(portalOffersApiProvider);
    final offer = widget.offer;
    try {
      final String id;
      if (offer == null) {
        id = await api.create(_fields);
      } else {
        await api.update(offer.id, offer.rev, _fields);
        id = offer.id;
      }
      ref.invalidate(portalOffersProvider);
      if (mounted) context.go('/offers/$id');
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final free = _type == OfferType.freeLesson;
    final cancelTo = offer == null ? '/offers' : '/offers/${offer.id}';
    final form = Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offer != null && offer.status != ReviewStatus.draft)
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.md),
                child: Text(
                  offer.isLive
                      ? 'This offer is live. Saving changes takes it out of '
                            'the app and back to draft until it is reviewed '
                            'and published again.'
                      : 'Saving changes sends this offer back to draft for '
                            'review.',
                  key: const Key('edit-resets-note'),
                  style: t.bodyMedium,
                ),
              ),
            TextFormField(
              key: const Key('field-title'),
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: validateTitle,
            ),
            const SizedBox(height: LwSpacing.sm),
            TextFormField(
              key: const Key('field-description'),
              controller: _description,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Short description (optional)',
                helperText:
                    'Plain facts about the offer. No health-outcome '
                    'claims (spec 13.4).',
              ),
              validator: validateDescription,
            ),
            const SizedBox(height: LwSpacing.sm),
            TextFormField(
              key: const Key('field-url'),
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Portal link',
                helperText:
                    'https://${portalHosts.first}/… The app adds '
                    'tracking parameters itself.',
              ),
              validator: validateUrl,
            ),
            const SizedBox(height: LwSpacing.md),
            DropdownButtonFormField<OfferType>(
              key: const Key('field-type'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Offer type'),
              items: [
                for (final ty in OfferType.values)
                  DropdownMenuItem(value: ty, child: Text(ty.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: LwSpacing.md),
            TextFormField(
              key: const Key('field-price'),
              controller: _price,
              enabled: !free,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: 'Price shown (optional)',
                helperText: free
                    ? 'Free lessons show "Free lesson".'
                    : 'Shown exactly as typed, e.g. \$49. Empty shows '
                          '"Paid course".',
              ),
              validator: (v) => validatePrice(v, free: free),
            ),
            const SizedBox(height: LwSpacing.sm),
            TextFormField(
              key: const Key('field-drivers'),
              controller: _drivers,
              decoration: const InputDecoration(
                labelText: 'Driver tags (optional)',
                helperText: 'Comma-separated, e.g. nutrition, sleep',
              ),
              validator: validateTags,
            ),
            const SizedBox(height: LwSpacing.md),
            TextFormField(
              key: const Key('field-topics'),
              controller: _topics,
              decoration: const InputDecoration(
                labelText: 'Topic tags (optional)',
                helperText:
                    'Comma-separated, e.g. gut_health. '
                    '"Not now" pauses offers on the same topic for 14 days.',
              ),
              validator: validateTags,
            ),
            if (_error != null) ...[
              const SizedBox(height: LwSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('form-error'),
                  style: t.bodyMedium?.copyWith(color: p.emergency),
                ),
              ),
            ],
            const SizedBox(height: LwSpacing.lg),
            Wrap(
              spacing: LwSpacing.sm,
              runSpacing: LwSpacing.sm,
              children: [
                FilledButton(
                  key: const Key('form-save'),
                  onPressed: _busy ? null : _save,
                  child: Text(
                    _busy
                        ? 'Saving…'
                        : offer == null
                        ? 'Save as draft'
                        : 'Save changes',
                  ),
                ),
                OutlinedButton(
                  key: const Key('form-cancel'),
                  onPressed: _busy ? null : () => context.go(cancelTo),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Preview in the app', style: t.titleSmall),
        ),
        const SizedBox(height: LwSpacing.xs),
        PortalCardPreview(fields: _fields),
      ],
    );
    return AdminScaffold(
      title: offer == null ? 'New offer' : 'Edit offer',
      leading: IconButton(
        tooltip: 'Cancel',
        onPressed: () => context.go(cancelTo),
        icon: const Icon(Icons.close),
      ),
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: c.maxWidth >= AdminLayout.twoColumnBreakpoint
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: form),
                    const SizedBox(width: LwSpacing.xl),
                    Expanded(flex: 2, child: preview),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    form,
                    const SizedBox(height: LwSpacing.xl),
                    preview,
                  ],
                ),
        ),
      ),
    );
  }
}
