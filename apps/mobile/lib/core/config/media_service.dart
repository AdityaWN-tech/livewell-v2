import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flavor.dart';

/// The Media Service's address (avatars, T-AVT-08), from
/// `--dart-define=LW_MEDIA_URL=...`. Empty: not set up, and the Studio hides
/// the ways that need it.
const mediaServiceUrl = String.fromEnvironment('LW_MEDIA_URL');

/// Whether the app may talk to [url]: HTTPS always; plain HTTP only to this
/// phone itself (127.0.0.1 or localhost, a Media Service on the developer's
/// computer through `adb reverse`) and only in a debug build (D-64).
bool mediaUrlAllowed(Uri url, {bool debug = kDebugMode}) =>
    url.scheme == 'https' ||
    (debug &&
        url.scheme == 'http' &&
        (url.host == '127.0.0.1' || url.host == 'localhost'));

/// The Media Service base for [flavor], or null when it isn't set up. Only
/// the dev flavor has one until the service is deployed (D-17, D-39).
Uri? mediaServiceBase(
  Flavor flavor, {
  String url = mediaServiceUrl,
  bool debug = kDebugMode,
}) {
  if (flavor != Flavor.dev || url.isEmpty) return null;
  final parsed = Uri.tryParse(url.endsWith('/') ? url : '$url/');
  if (parsed == null || !parsed.hasAuthority) return null;
  return mediaUrlAllowed(parsed, debug: debug) ? parsed : null;
}

/// [mediaServiceBase] for the running app. The flavor is only read when an
/// address was given, so builds and tests without one never need it.
final mediaServiceBaseProvider = Provider<Uri?>(
  (ref) => mediaServiceUrl.isEmpty
      ? null
      : mediaServiceBase(ref.watch(flavorProvider)),
);
