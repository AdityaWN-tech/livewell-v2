import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../checkin/domain/checkin.dart' show localDateKey;
import '../application/travel_data.dart';
import '../data/device_location.dart';
import '../data/places_source.dart';
import '../data/time_zones.dart';
import '../domain/places.dart';
import '../domain/travel_content.dart';
import '../domain/trip.dart';

/// Basic Travel Mode (T-TRV-01, FR-TRV-01..03, D-86), under Plan: the trip
/// (dates and time zone), the jet-lag tip, the four travel pillars and
/// nearby places from a maps provider, clearly labelled as listings Live
/// Well doesn't endorse. One primary action: Start Travel Mode.
class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  static const path = '/plan/travel';

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  DateTimeRange? _dates;
  String? _zone;
  bool _saving = false;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickDates() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initialDateRange: _dates,
    );
    if (picked != null) setState(() => _dates = picked);
  }

  Future<void> _pickZone(String phoneZone) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ZoneSheet(phoneZone: phoneZone),
    );
    if (picked != null) setState(() => _zone = picked);
  }

  Future<void> _start(String zone) async {
    final dates = _dates;
    if (dates == null || _saving) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    final problem = await ref
        .read(travelActionsProvider)
        .start(
          start: localDateKey(dates.start),
          end: localDateKey(dates.end),
          timeZone: zone,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (problem == null) {
      setState(() {
        _dates = null;
        _zone = null;
      });
      _snack(l.travelStarted);
      return;
    }
    _snack(switch (problem.problem) {
      null => l.travelProblemOverlap,
      TripProblem.endBeforeStart => l.travelProblemEndBeforeStart,
      TripProblem.inThePast => l.travelProblemPast,
      TripProblem.tooLong => l.travelProblemTooLong(Trip.maxDays),
    });
  }

  Future<void> _end(Trip trip, {required bool started}) async {
    final l = AppLocalizations.of(context);
    await ref.read(travelActionsProvider).end(trip);
    if (mounted) _snack(started ? l.travelEnded : l.travelCancelled);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final current = ref.watch(currentTripProvider);
    final next = ref.watch(nextTripProvider);
    final trip = current ?? next;
    final content = ref.watch(usableTravelContentProvider);
    final tip = trip == null ? null : ref.watch(jetLagTipProvider(trip));
    final phoneZone = ref.watch(deviceTimeZoneProvider).value ?? 'UTC';
    final limited =
        ref.watch(currentProfileProvider).value?.activityLimited ?? false;
    // Keeps Near you's results while that section scrolls out of view.
    ref.listen(nearbyControllerProvider, (_, _) {});
    return LwScreen(
      title: l.travelTitle,
      children: [
        Text(l.travelIntro, style: t.bodyMedium),
        const SizedBox(height: LwSpacing.md),
        if (current != null)
          _TripStatus(
            key: const Key('travel-on'),
            title: l.travelOnTitle,
            body: l.travelOnBody(
              _date(context, current.end),
              TimeZones.label(current.timeZone),
            ),
            action: l.travelEnd,
            actionKey: const Key('travel-end'),
            onAction: () => _end(current, started: true),
          )
        else if (next != null)
          _TripStatus(
            key: const Key('travel-next'),
            title: l.travelNextTitle,
            body: l.travelNextBody(
              _date(context, next.start),
              _date(context, next.end),
              TimeZones.label(next.timeZone),
            ),
            action: l.travelCancel,
            actionKey: const Key('travel-cancel'),
            onAction: () => _end(next, started: false),
          )
        else
          _TripForm(
            dates: _dates,
            zone: _zone ?? phoneZone,
            saving: _saving,
            onPickDates: _pickDates,
            onPickZone: () => _pickZone(phoneZone),
            onStart: () => _start(_zone ?? phoneZone),
          ),
        if (tip != null) ...[
          const SizedBox(height: LwSpacing.sm),
          LwCard(
            key: const Key('travel-jet-lag'),
            eyebrow: l.travelJetLagEyebrow,
            title: tip.title,
            body: tip.body,
          ),
        ],
        LwSectionHeader(l.travelPillarsTitle),
        if (content == null)
          LwEmptyState(
            key: const Key('travel-content-pending'),
            icon: Icons.luggage_outlined,
            title: l.travelPillarsTitle,
            body: l.travelContentPending,
          )
        else
          for (final pillar in content.pillars)
            _PillarSection(pillar: pillar, activityLimited: limited),
        LwSectionHeader(l.travelNearbyTitle),
        const _NearbySection(),
      ],
    );
  }
}

String _date(BuildContext context, String date) =>
    DateFormat.MMMd(Localizations.localeOf(context).toString())
        .format(DateTime.parse(date));

/// A trip that is on or planned, with one quiet way to end or cancel it.
class _TripStatus extends StatelessWidget {
  const _TripStatus({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(color: p.sky, borderRadius: LwRadius.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.luggage_outlined,
                  color: p.onTint,
                  size: LwSize.iconMd,
                ),
              ),
              const SizedBox(width: LwSpacing.xs),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.titleMedium?.copyWith(color: p.onTint),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LwSpacing.xxs),
          Text(body, style: t.bodyMedium?.copyWith(color: p.onTintSecondary)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dates, time zone and the screen's one primary action.
class _TripForm extends StatelessWidget {
  const _TripForm({
    required this.dates,
    required this.zone,
    required this.saving,
    required this.onPickDates,
    required this.onPickZone,
    required this.onStart,
  });

  final DateTimeRange? dates;
  final String zone;
  final bool saving;
  final VoidCallback onPickDates;
  final VoidCallback onPickZone;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final d = dates;
    return Card(
      key: const Key('travel-form'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.travelTripTitle, style: t.titleMedium),
            ),
            ListTile(
              key: const Key('travel-dates'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range_outlined),
              title: Text(l.travelDates),
              subtitle: Text(
                d == null
                    ? l.travelDatesPick
                    : l.travelDatesValue(
                        _date(context, localDateKey(d.start)),
                        _date(context, localDateKey(d.end)),
                      ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPickDates,
            ),
            ListTile(
              key: const Key('travel-zone'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l.travelTimeZone),
              subtitle: Text(TimeZones.label(zone)),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPickZone,
            ),
            const SizedBox(height: LwSpacing.xs),
            FilledButton(
              key: const Key('travel-start'),
              onPressed: d == null || saving ? null : onStart,
              child: Text(l.travelStart),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the destination's time zone: this phone's, common ones, or any
/// from the search (the search words are never saved).
class _ZoneSheet extends ConsumerStatefulWidget {
  const _ZoneSheet({required this.phoneZone});

  final String phoneZone;

  @override
  ConsumerState<_ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends ConsumerState<_ZoneSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final zones = ref.watch(timeZonesProvider);
    final q = _query.trim().toLowerCase().replaceAll(' ', '_');
    final names = q.isEmpty
        ? [
            widget.phoneZone,
            for (final z in TimeZones.common)
              if (z != widget.phoneZone) z,
          ]
        : [
            for (final z in zones.all)
              if (z.toLowerCase().contains(q)) z,
          ];
    return SafeArea(
      child: Padding(
        key: const Key('travel-zone-sheet'),
        padding: EdgeInsets.only(
          left: LwSpacing.lg,
          right: LwSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.travelTimeZone, style: t.titleLarge),
              const SizedBox(height: LwSpacing.sm),
              TextField(
                key: const Key('travel-zone-search'),
                decoration: InputDecoration(
                  labelText: l.travelZoneSearch,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: LwSpacing.xs),
              Expanded(
                child: names.isEmpty
                    ? Text(l.travelZoneNone, style: t.bodyMedium)
                    : ListView(
                        children: [
                          for (final z in names)
                            ListTile(
                              key: Key('travel-zone-$z'),
                              title: Text(TimeZones.label(z)),
                              subtitle: z == widget.phoneZone
                                  ? Text(l.travelZonePhone)
                                  : null,
                              onTap: () => Navigator.of(context).pop(z),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One travel pillar and its routines and tips (FR-TRV-02).
class _PillarSection extends StatelessWidget {
  const _PillarSection({required this.pillar, required this.activityLimited});

  final TravelPillar pillar;
  final bool activityLimited;

  static IconData iconOf(String icon) => switch (icon) {
    'eat' => Icons.restaurant_outlined,
    'move' => Icons.directions_walk,
    'sleep' => Icons.bedtime_outlined,
    'breathe' => Icons.air,
    _ => Icons.luggage_outlined,
  };

  void _open(BuildContext context, TravelItem item) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          key: Key('travel-item-sheet-${item.id}'),
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.lg,
            0,
            LwSpacing.lg,
            LwSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(pillar.title.toUpperCase(), style: t.labelSmall),
              Text(item.title, style: t.titleLarge),
              const SizedBox(height: LwSpacing.xxs),
              Text(l.planMinutes(item.minutes), style: t.labelMedium),
              const SizedBox(height: LwSpacing.sm),
              Text(item.body, style: t.bodyLarge),
              if (item.movement && activityLimited) ...[
                const SizedBox(height: LwSpacing.sm),
                Text(
                  l.routineClinicianFirst,
                  key: const Key('travel-item-clinician'),
                  style: t.titleSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: Key('travel-pillar-${pillar.id}'),
      padding: const EdgeInsets.only(bottom: LwSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  iconOf(pillar.icon),
                  color: p.primaryDark,
                  size: LwSize.iconMd,
                ),
              ),
              const SizedBox(width: LwSpacing.xs),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(pillar.title, style: t.titleMedium),
                ),
              ),
            ],
          ),
          Text(pillar.intro, style: t.bodySmall),
          const SizedBox(height: LwSpacing.xs),
          Card(
            child: Column(
              children: [
                for (final (i, item) in pillar.items.indexed) ...[
                  if (i > 0) const Divider(indent: LwSpacing.md),
                  Semantics(
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    label: l.travelItemLabel(item.title, item.minutes),
                    child: ListTile(
                      key: Key('travel-item-${item.id}'),
                      title: Text(item.title),
                      subtitle: Text(l.planMinutes(item.minutes)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(context, item),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parks, grocery stores and plant-forward restaurants (FR-TRV-03). With a
/// maps provider: listings after the location permission, each labelled
/// with its source and "not endorsed". Without one: a labelled search in
/// the phone's maps app.
class _NearbySection extends ConsumerStatefulWidget {
  const _NearbySection();

  @override
  ConsumerState<_NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends ConsumerState<_NearbySection> {
  String _query(AppLocalizations l, PlaceCategory category) =>
      switch (category) {
        PlaceCategory.park => l.travelMapsQueryPark,
        PlaceCategory.grocery => l.travelMapsQueryGrocery,
        PlaceCategory.plantForward => l.travelMapsQueryPlant,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final configured = ref.watch(nearbyPlacesSourceProvider) != null;
    final launch = ref.watch(mapsLauncherProvider);
    final labels = {
      PlaceCategory.park: l.travelCategoryPark,
      PlaceCategory.grocery: l.travelCategoryGrocery,
      PlaceCategory.plantForward: l.travelCategoryPlant,
    };
    final nearby = ref.watch(nearbyControllerProvider);
    final controller = ref.read(nearbyControllerProvider.notifier);
    final result = nearby.result;
    final loading = nearby.loading;
    return Column(
      key: const Key('travel-nearby'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.travelNearbyBody, style: t.bodyMedium),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final c in PlaceCategory.values)
              ChoiceChip(
                key: Key('travel-category-${c.name}'),
                label: Text(labels[c]!),
                selected: c == nearby.category,
                onSelected: (_) => controller.choose(c),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.sm),
        if (configured) ...[
          OutlinedButton.icon(
            key: const Key('travel-nearby-find'),
            onPressed: loading ? null : controller.find,
            icon: const Icon(Icons.near_me_outlined),
            label: Text(l.travelNearbyFind),
          ),
          const SizedBox(height: LwSpacing.xxs),
          Text(l.travelNearbyLocationNote, style: t.bodySmall),
        ] else ...[
          OutlinedButton.icon(
            key: const Key('travel-maps-search'),
            onPressed: () => launch(mapsSearchUri(_query(l, nearby.category))),
            icon: const Icon(Icons.map_outlined),
            label: Text(l.travelMapsSearch),
          ),
          const SizedBox(height: LwSpacing.xxs),
          Text(
            l.travelMapsNote,
            key: const Key('travel-maps-note'),
            style: t.bodySmall,
          ),
        ],
        if (loading)
          const Padding(
            padding: EdgeInsets.all(LwSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!loading && result != null) ...[
          const SizedBox(height: LwSpacing.sm),
          _NearbyResultView(result: result, onOpen: launch),
        ],
      ],
    );
  }
}

class _NearbyResultView extends ConsumerWidget {
  const _NearbyResultView({required this.result, required this.onOpen});

  final NearbyResult result;
  final Future<bool> Function(Uri) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget note(String text, {Key? key}) =>
        Text(text, key: key, style: t.bodyMedium);
    return switch (result) {
      NearbyNotConfigured() => note(l.travelMapsNote),
      NearbyFailed() => note(
        l.travelNearbyFailed,
        key: const Key('travel-nearby-failed'),
      ),
      NearbyNoLocation(serviceOff: true) => note(
        l.travelNearbyServiceOff,
        key: const Key('travel-nearby-service-off'),
      ),
      NearbyNoLocation(permanently: true) => Column(
        key: const Key('travel-nearby-denied-forever'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          note(l.travelNearbyDeniedForever),
          TextButton(
            onPressed: () => ref.read(openLocationSettingsProvider)(),
            child: Text(l.travelNearbyOpenSettings),
          ),
        ],
      ),
      NearbyNoLocation() => note(
        l.travelNearbyDenied,
        key: const Key('travel-nearby-denied'),
      ),
      NearbyListings(:final places, :final provider) => Column(
        key: const Key('travel-listings'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The source label (FR-TRV-03): map-provider listings, not
          // endorsed. Always shown with the listings.
          Text(
            l.travelListingsSource(provider),
            key: const Key('travel-listings-source'),
            style: t.bodySmall,
          ),
          const SizedBox(height: LwSpacing.xs),
          if (places.isEmpty)
            note(l.travelNearbyNone, key: const Key('travel-nearby-none'))
          else
            for (final place in places)
              Semantics(
                button: place.mapsUri != null,
                container: true,
                excludeSemantics: true,
                label: l.travelListingOpenLabel(place.name, provider),
                child: Card(
                  child: ListTile(
                    title: Text(place.name),
                    subtitle: place.address == null
                        ? null
                        : Text(place.address!),
                    trailing: LwTag(l.travelListingTag(provider)),
                    onTap: place.mapsUri == null
                        ? null
                        : () => onOpen(place.mapsUri!),
                  ),
                ),
              ),
        ],
      ),
    };
  }
}
