import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/places.dart';

/// Where the phone is, only when the person asks for nearby places
/// (FR-TRV-03: listings require location permission). Approximate accuracy
/// is enough; the location is used once for the search and never saved or
/// logged.
abstract class DeviceLocation {
  Future<LocationOutcome> current();
}

sealed class LocationOutcome {
  const LocationOutcome();
}

class LocationFound extends LocationOutcome {
  const LocationFound(this.at);
  final LatLng at;
}

class LocationDenied extends LocationOutcome {
  const LocationDenied({required this.permanently});
  final bool permanently;
}

class LocationServiceOff extends LocationOutcome {
  const LocationServiceOff();
}

class GeolocatorLocation implements DeviceLocation {
  @override
  Future<LocationOutcome> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServiceOff();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const LocationDenied(permanently: false);
        case LocationPermission.deniedForever:
          return const LocationDenied(permanently: true);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 15),
            ),
          );
          return LocationFound(LatLng(p.latitude, p.longitude));
      }
    } catch (_) {
      // Timed out or unavailable: treated like no location.
      return const LocationDenied(permanently: false);
    }
  }
}

final deviceLocationProvider = Provider<DeviceLocation>(
  (ref) => GeolocatorLocation(),
);

/// Opens the phone's settings for this app (location denied for good).
final openLocationSettingsProvider = Provider<Future<bool> Function()>(
  (ref) => Geolocator.openAppSettings,
);
