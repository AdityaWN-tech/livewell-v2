import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/media_service.dart';
import '../domain/avatar_frames.dart';
import 'avatar_maker_api.dart';

/// Where a frame set's files can be downloaded: short-lived signed URLs
/// from Cloud Storage `avatars/{uid}/{version}/`, one per file name
/// (`avatar_frames.json` and each frame).
abstract class AvatarFrameSource {
  Future<Map<String, Uri>> signedUrls({
    required String uid,
    required int version,
  });
}

/// Not built yet: the Media Service makes frame sets in T-AVT-08c/d, and the
/// Core API will sign the URLs. Until then there is nothing to download.
class UnavailableFrameSource implements AvatarFrameSource {
  @override
  Future<Map<String, Uri>> signedUrls({
    required String uid,
    required int version,
  }) async => const {};
}

/// Frame sets kept by the Media Service itself (development without Cloud
/// Storage, D-64): `GET v1/avatar/frames/{version}` with the ID token gives
/// short-lived signed links on the same service.
class MediaServiceFrameSource implements AvatarFrameSource {
  MediaServiceFrameSource({
    required this.base,
    required this.idToken,
    FetchJson? fetch,
  }) : _fetch = fetch ?? _getJson;

  final Uri base;
  final Future<String> Function() idToken;
  final FetchJson _fetch;

  @override
  Future<Map<String, Uri>> signedUrls({
    required String uid,
    required int version,
  }) async {
    if (!mediaUrlAllowed(base)) return const {};
    final json = await _fetch(
      base.resolve('v1/avatar/frames/$version'),
      await idToken(),
    );
    return {
      for (final e in json.entries)
        if (e.value is String) e.key: base.resolve(e.value as String),
    };
  }
}

/// GETs JSON with a bearer token (swappable in tests).
typedef FetchJson = Future<Map<String, dynamic>> Function(
  Uri url,
  String idToken,
);

Future<Map<String, dynamic>> _getJson(Uri url, String idToken) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(url);
    req.headers.set('Authorization', 'Bearer $idToken');
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

/// Fetches one URL's bytes (swappable in tests).
typedef FetchBytes = Future<List<int>> Function(Uri url);

Future<List<int>> _httpGet(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final res = await (await client.getUrl(url)).close();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    final out = <int>[];
    await for (final chunk in res) {
      out.addAll(chunk);
    }
    return out;
  } finally {
    client.close();
  }
}

/// A frame set on the device: its manifest and folder.
class CachedFrameSet {
  const CachedFrameSet(this.manifest, this.dir);

  final AvatarFrameManifest manifest;
  final Directory dir;

  /// The file for [frame], if it is on the device.
  File? file(AvatarFrame frame, {double devicePixelRatio = 3}) {
    final name = manifest.fileFor(frame, devicePixelRatio: devicePixelRatio);
    if (name == null) return null;
    final f = File('${dir.path}/$name');
    return f.existsSync() ? f : null;
  }

  /// The small face for [expression] (an expression name; talking uses
  /// neutral), if the set has one on the device.
  File? thumbnail(String expression) {
    final name =
        manifest.thumbnails[expression == 'talking' ? 'neutral' : expression];
    if (name == null) return null;
    final f = File('${dir.path}/$name');
    return f.existsSync() ? f : null;
  }

  /// Every frame is on the device.
  bool get complete =>
      manifest.complete &&
      AvatarFrame.values.every(
        (f) => manifest.sizes.every((s) {
          final name = manifest.files[f]?[s];
          return name != null && File('${dir.path}/$name').existsSync();
        }),
      );
}

/// Keeps frame sets on the device (T-AVT-08a) so the coach works offline:
/// `<app support>/avatars/{uid}/{version}/`. A set is downloaded once per
/// version, into a temporary folder that only becomes the cache when every
/// file arrived. Only HTTPS links to Cloud Storage are followed, and links
/// to [mediaService]'s own frame files (D-64).
class AvatarFrameCache {
  AvatarFrameCache({
    required this.root,
    required this.source,
    this.mediaService,
    FetchBytes? fetch,
  }) : _fetch = fetch ?? _httpGet;

  /// Resolves the cache root (the app support folder on a phone).
  final Future<Directory> Function() root;
  final AvatarFrameSource source;

  /// The Media Service, when it keeps the frame sets itself.
  final Uri? mediaService;
  final FetchBytes _fetch;

  static const manifestName = 'avatar_frames.json';

  /// Signed Cloud Storage links only (V4 signed URLs).
  static bool allowed(Uri url) =>
      url.scheme == 'https' &&
      (url.host == 'storage.googleapis.com' ||
          url.host == 'firebasestorage.googleapis.com');

  /// [allowed], or a frame file link on [mediaService] (same origin).
  bool follows(Uri url) {
    final m = mediaService;
    if (allowed(url)) return true;
    return m != null &&
        mediaUrlAllowed(url) &&
        url.scheme == m.scheme &&
        url.host == m.host &&
        url.port == m.port &&
        url.path.startsWith('${m.path}v1/avatar/files/');
  }

  Future<Directory> _dir(String uid, int version) async =>
      Directory('${(await root()).path}/avatars/$uid/$version');

  /// The cached set, if it is on the device (complete or not).
  Future<CachedFrameSet?> cached(String uid, int version) async {
    final dir = await _dir(uid, version);
    final file = File('${dir.path}/$manifestName');
    if (!await file.exists()) return null;
    try {
      final m = AvatarFrameManifest.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
      return CachedFrameSet(m, dir);
    } catch (_) {
      return null;
    }
  }

  /// The set for [uid] at [version]: from the device when it is all there,
  /// else downloaded. Returns whatever could be had (maybe only some
  /// frames), or null when nothing is available.
  Future<CachedFrameSet?> load(String uid, int version) async {
    final have = await cached(uid, version);
    if (have != null && have.complete) return have;
    try {
      return await _download(uid, version) ?? have;
    } catch (_) {
      // Offline or refused: what's on the device, if anything.
      return have;
    }
  }

  Future<CachedFrameSet?> _download(String uid, int version) async {
    final urls = await source.signedUrls(uid: uid, version: version);
    final manifestUrl = urls[manifestName];
    if (manifestUrl == null || !follows(manifestUrl)) return null;
    final manifest = AvatarFrameManifest.fromJson(
      jsonDecode(utf8.decode(await _fetch(manifestUrl)))
          as Map<String, dynamic>,
    );
    final dir = await _dir(uid, version);
    final tmp = Directory('${dir.path}.part');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    // Neutral first: if the rest fails, the coach can still show it.
    final names = <String>{
      ...?manifest.files[AvatarFrame.neutral]?.values,
      for (final f in manifest.files.values) ...f.values,
      ...manifest.thumbnails.values,
    };
    for (final name in names) {
      final url = urls[name];
      if (url == null || !follows(url)) continue;
      try {
        await File('${tmp.path}/$name').writeAsBytes(await _fetch(url));
      } catch (_) {
        // Skipped: the set stays incomplete and falls back.
      }
    }
    await File('${tmp.path}/$manifestName')
        .writeAsString(jsonEncode(manifest.toJson()));
    if (await dir.exists()) await dir.delete(recursive: true);
    await tmp.rename(dir.path);
    return CachedFrameSet(manifest, dir);
  }

  /// Forgets every cached set for [uid] (Delete my avatar, sign-out).
  Future<void> clear(String uid) async {
    final dir = Directory('${(await root()).path}/avatars/$uid');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// The Media Service's own links in dev (D-64); Cloud Storage links from
/// the Core API at deploy (TODO(T-AVT-08 deploy)).
final avatarFrameSourceProvider = Provider<AvatarFrameSource>((ref) {
  final base = ref.watch(mediaServiceBaseProvider);
  if (base == null) return UnavailableFrameSource();
  return MediaServiceFrameSource(base: base, idToken: firebaseIdToken);
});

final avatarFrameCacheProvider = Provider<AvatarFrameCache>(
  (ref) => AvatarFrameCache(
    root: getApplicationSupportDirectory,
    source: ref.watch(avatarFrameSourceProvider),
    mediaService: ref.watch(mediaServiceBaseProvider),
  ),
);
