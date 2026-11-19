import 'package:livewell/features/travel/data/device_location.dart';
import 'package:livewell/features/travel/data/places_source.dart';
import 'package:livewell/features/travel/domain/places.dart';

/// The phone's location in tests: granted by default.
class FakeDeviceLocation implements DeviceLocation {
  LocationOutcome outcome = const LocationFound(LatLng(51.5, -0.12));
  int asked = 0;

  @override
  Future<LocationOutcome> current() async {
    asked++;
    return outcome;
  }
}

/// A maps provider in tests.
class FakePlacesSource implements NearbyPlacesSource {
  FakePlacesSource({this.places = const [], this.fail = false});

  final List<Place> places;
  final bool fail;
  final searches = <PlaceCategory>[];

  @override
  String get provider => 'Fake Maps';

  @override
  Future<List<Place>> search(
    PlaceCategory category,
    LatLng at, {
    int limit = 10,
  }) async {
    searches.add(category);
    if (fail) throw const NearbySearchException(500);
    return places;
  }
}
