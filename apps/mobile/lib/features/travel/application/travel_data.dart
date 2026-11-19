import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/flavor.dart';
import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../checkin/domain/checkin.dart' show localDateKey;
import '../../home/domain/home_models.dart';
import '../../starter_plan/data/reminders.dart';
import '../data/device_location.dart';
import '../data/places_source.dart';
import '../data/time_zones.dart';
import '../data/trip_repository.dart';
import '../domain/places.dart';
import '../domain/travel_content.dart';
import '../domain/trip.dart';

/// Every trip, live (FR-TRV-01).
final tripsProvider = StreamProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).watch(),
);

String _today(Ref ref) => localDateKey(ref.watch(clockProvider)());

/// The trip on today's date, or null.
final currentTripProvider = Provider<Trip?>(
  (ref) => activeTrip(ref.watch(tripsProvider).value ?? const [], _today(ref)),
);

/// The next trip that hasn't started yet, or null.
final nextTripProvider = Provider<Trip?>(
  (ref) => nextTrip(ref.watch(tripsProvider).value ?? const [], _today(ref)),
);

/// Days the streak protects: every trip day so far (FR-TRV-01).
final travelProtectedDatesProvider = Provider<Set<String>>(
  (ref) =>
      protectedDates(ref.watch(tripsProvider).value ?? const [], _today(ref)),
);

/// The travel content this build may show: pending content only in dev;
/// null until it loads or when it isn't approved yet (D-86).
final usableTravelContentProvider = Provider<TravelContent?>((ref) {
  final content = ref.watch(travelContentProvider).value;
  if (content == null) return null;
  final isDev = ref.watch(flavorProvider) == Flavor.dev;
  return content.usable(isDev: isDev) ? content : null;
});

/// Today's step while a trip is on: a travel microhabit instead of the
/// plan's step (FR-TRV-01). Null when there's no trip today or no usable
/// content (the plan's own step stays).
final travelStepProvider = Provider<TodayStep?>((ref) {
  final trip = ref.watch(currentTripProvider);
  if (trip == null) return null;
  final content = ref.watch(usableTravelContentProvider);
  if (content == null) return null;
  final step = content.stepFor(
    tripDay: trip.dayOf(_today(ref)),
    activityLimited:
        ref.watch(currentProfileProvider).value?.activityLimited ?? false,
  );
  if (step == null) return null;
  final pillar = content.pillar(step.pillar);
  return TodayStep(
    driver: pillar == null
        ? content.stepLabel
        : '${content.stepLabel} · ${pillar.title}',
    title: step.title,
    reason: step.reason,
    minutes: step.minutes,
    smallerTitle: step.smallerTitle,
    smallerMinutes: step.smallerMinutes,
  );
});

/// The jet-lag tip for [trip] (from home's time zone to the trip's), or
/// null when a zone is unknown or the content isn't usable.
final jetLagTipProvider = Provider.family<JetLagTip?, Trip>((ref, trip) {
  final content = ref.watch(usableTravelContentProvider);
  if (content == null) return null;
  final zones = ref.watch(timeZonesProvider);
  final now = ref.watch(clockProvider)();
  final home = zones.offset(trip.homeTimeZone, now);
  final there = zones.offset(trip.timeZone, now);
  if (home == null || there == null) return null;
  return content.tipFor(JetLag.direction(home, there));
});

/// The phone's time zone now (the default destination and "home").
final deviceTimeZoneProvider = FutureProvider<String>(
  (ref) => ref.watch(remindersProvider).timeZone(),
);

/// Starting, ending and cancelling trips.
class TravelActions {
  TravelActions(this._ref);

  final Ref _ref;

  TripRepository get _repo => _ref.read(tripRepositoryProvider);
  String get _today => localDateKey(_ref.read(clockProvider)());

  /// Why the trip can't be saved, or null when it was saved.
  Future<TravelStartProblem?> start({
    required String start,
    required String end,
    required String timeZone,
  }) async {
    final problem = Trip.check(start, end, _today);
    if (problem != null) return TravelStartProblem.invalid(problem);
    final trips = _ref.read(tripsProvider).value ?? const [];
    if (overlaps(trips, start, end)) return const TravelStartProblem.overlap();
    String home;
    try {
      home = await _ref.read(remindersProvider).timeZone();
    } catch (_) {
      home = timeZone;
    }
    await _repo.save(
      Trip(start: start, end: end, timeZone: timeZone, homeTimeZone: home),
    );
    return null;
  }

  /// Ends [trip] now: the days so far stay protected; today counts as a
  /// normal day again. A trip that hasn't had a full day yet (or hasn't
  /// started) is removed.
  Future<void> end(Trip trip) async {
    final today = _ref.read(clockProvider)();
    final yesterday = localDateKey(
      DateTime(today.year, today.month, today.day - 1),
    );
    if (trip.start.compareTo(yesterday) > 0) {
      await _repo.delete(trip.id);
    } else {
      await _repo.save(trip.copyWith(end: yesterday));
    }
  }
}

final travelActionsProvider = Provider<TravelActions>(TravelActions.new);

/// Why a trip wasn't saved.
class TravelStartProblem {
  const TravelStartProblem.invalid(TripProblem this.problem);
  const TravelStartProblem.overlap() : problem = null;

  /// Null: it overlaps another trip.
  final TripProblem? problem;
}

/// Nearby places (FR-TRV-03): only with a maps provider set up and the
/// location permission given. The location is used once, for this search.
class NearbySearch {
  NearbySearch(this._ref);

  final Ref _ref;

  Future<NearbyResult> find(PlaceCategory category) async {
    final source = _ref.read(nearbyPlacesSourceProvider);
    if (source == null) return const NearbyNotConfigured();
    final location = await _ref.read(deviceLocationProvider).current();
    switch (location) {
      case LocationDenied(:final permanently):
        return NearbyNoLocation(permanently: permanently);
      case LocationServiceOff():
        return const NearbyNoLocation(permanently: false, serviceOff: true);
      case LocationFound(:final at):
        try {
          return NearbyListings(
            places: await source.search(category, at),
            provider: source.provider,
          );
        } catch (_) {
          // Nothing about the place or the error is logged.
          return const NearbyFailed();
        }
    }
  }
}

final nearbySearchProvider = Provider<NearbySearch>(NearbySearch.new);

/// The Near you section's state while the app is open (kept when the
/// section scrolls out of view). Never saved.
class NearbyState {
  const NearbyState({
    this.category = PlaceCategory.park,
    this.result,
    this.loading = false,
  });

  final PlaceCategory category;
  final NearbyResult? result;
  final bool loading;
}

class NearbyController extends Notifier<NearbyState> {
  @override
  NearbyState build() => const NearbyState();

  void choose(PlaceCategory category) =>
      state = NearbyState(category: category);

  Future<void> find() async {
    final category = state.category;
    state = NearbyState(category: category, loading: true);
    final result = await ref.read(nearbySearchProvider).find(category);
    if (state.category != category) return;
    state = NearbyState(category: category, result: result);
  }
}

final nearbyControllerProvider =
    NotifierProvider.autoDispose<NearbyController, NearbyState>(
      NearbyController.new,
    );
