/// Nearby places for Travel Mode (FR-TRV-03, D-86): parks, grocery stores
/// and plant-forward restaurants from a maps provider. Every listing shows
/// where it came from and that Live Well doesn't endorse it. A place's
/// details and the person's location are never saved or logged.
library;

enum PlaceCategory { park, grocery, plantForward }

/// A point on the map (approximate; never stored).
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// One listing from the maps provider.
class Place {
  const Place({required this.name, this.address, this.mapsUri});

  final String name;
  final String? address;

  /// Opens the place in the provider's maps app or site.
  final Uri? mapsUri;
}

/// What a nearby search gave.
sealed class NearbyResult {
  const NearbyResult();
}

/// Listings, with the provider's name for the source label.
class NearbyListings extends NearbyResult {
  const NearbyListings({required this.places, required this.provider});

  final List<Place> places;

  /// The maps provider, e.g. "Google Maps".
  final String provider;
}

/// No in-app listings in this build: no maps provider is set up. The screen
/// offers to search in the phone's maps app instead.
class NearbyNotConfigured extends NearbyResult {
  const NearbyNotConfigured();
}

/// Location permission was not given (or location is off).
class NearbyNoLocation extends NearbyResult {
  const NearbyNoLocation({required this.permanently, this.serviceOff = false});

  /// Denied for good: only the phone's settings can change it.
  final bool permanently;

  /// Location services are off on the phone.
  final bool serviceOff;
}

/// The provider couldn't be reached (offline, quota, error).
class NearbyFailed extends NearbyResult {
  const NearbyFailed();
}

/// A search in the phone's maps app, no key and no location needed by Live
/// Well (the fallback when no provider is set up).
Uri mapsSearchUri(String query) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});
