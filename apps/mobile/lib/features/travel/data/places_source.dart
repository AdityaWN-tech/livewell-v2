import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../domain/places.dart';

/// A maps provider's nearby search (FR-TRV-03). An adapter, so the provider
/// can change and tests use a fake.
abstract class NearbyPlacesSource {
  /// The provider's name for the source label, e.g. "Google Maps".
  String get provider;

  /// Up to [limit] places of [category] near [at]. Throws when the provider
  /// can't be reached.
  Future<List<Place>> search(PlaceCategory category, LatLng at, {int limit});
}

/// Google Places API (New) "Nearby Search". Sends only the category and an
/// approximate location; asks only for the name, address and Maps link
/// (the cheapest field set). Nothing is cached or logged.
class GooglePlacesSource implements NearbyPlacesSource {
  GooglePlacesSource(this._client, this._apiKey);

  final http.Client _client;
  final String _apiKey;

  static final endpoint = Uri.https(
    'places.googleapis.com',
    '/v1/places:searchNearby',
  );

  /// Search radius around the person, in metres.
  static const radiusMetres = 2000.0;

  static const fieldMask =
      'places.displayName,places.formattedAddress,places.googleMapsUri';

  /// Google place types for each category. "Plant-forward" is approximated
  /// by vegetarian and vegan restaurants (D-86).
  static const types = {
    PlaceCategory.park: ['park'],
    PlaceCategory.grocery: ['grocery_store', 'supermarket'],
    PlaceCategory.plantForward: ['vegetarian_restaurant', 'vegan_restaurant'],
  };

  @override
  String get provider => 'Google Maps';

  @override
  Future<List<Place>> search(
    PlaceCategory category,
    LatLng at, {
    int limit = 10,
  }) async {
    final response = await _client.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': fieldMask,
      },
      body: jsonEncode({
        'includedTypes': types[category],
        'maxResultCount': limit,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {'latitude': at.latitude, 'longitude': at.longitude},
            'radius': radiusMetres,
          },
        },
      }),
    );
    if (response.statusCode != 200) {
      // Only the status: the body could echo the request.
      throw NearbySearchException(response.statusCode);
    }
    return parse(response.body);
  }

  /// The places in a Nearby Search response.
  static List<Place> parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map || json['places'] is! List) return const [];
    return [
      for (final p in (json['places'] as List).whereType<Map>())
        if (_name(p) case final name?)
          Place(
            name: name,
            address: switch (p['formattedAddress']) {
              final String a when a.trim().isNotEmpty => a.trim(),
              _ => null,
            },
            mapsUri: switch (p['googleMapsUri']) {
              final String s => _safeUri(s),
              _ => null,
            },
          ),
    ];
  }

  /// Only web links are opened (never another scheme from a response).
  static Uri? _safeUri(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && uri.isScheme('https') ? uri : null;
  }

  static String? _name(Map p) {
    final d = p['displayName'];
    final text = d is Map ? d['text'] : null;
    return text is String && text.trim().isNotEmpty ? text.trim() : null;
  }
}

class NearbySearchException implements Exception {
  const NearbySearchException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'NearbySearchException($statusCode)';
}

/// The Places key for this build, never in the repo: set per build with
/// `--dart-define=LW_PLACES_API_KEY=...` from Secret Manager / CI secrets
/// (see .env.example). Empty (the default): no in-app listings; the
/// Travel screen offers the phone's maps app instead.
const placesApiKey = String.fromEnvironment('LW_PLACES_API_KEY');

/// The maps provider, or null when none is set up in this build.
final nearbyPlacesSourceProvider = Provider<NearbyPlacesSource?>((ref) {
  if (placesApiKey.isEmpty) return null;
  final client = http.Client();
  ref.onDispose(client.close);
  return GooglePlacesSource(client, placesApiKey);
});

/// Opens a listing or a maps search in the phone's maps app or browser.
final mapsLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
