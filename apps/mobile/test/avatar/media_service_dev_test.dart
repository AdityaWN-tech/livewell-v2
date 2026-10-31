import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/config/media_service.dart';
import 'package:livewell/features/avatar/data/avatar_frames_store.dart';
import 'package:livewell/features/avatar/data/avatar_maker_api.dart';

/// D-64: the dev Media Service on the developer's computer (LW_MEDIA_URL,
/// reached through `adb reverse`), and its own frame links.
void main() {
  group('which Media Service address is used', () {
    test('HTTPS anywhere; HTTP only to this phone in a debug build', () {
      expect(mediaUrlAllowed(Uri.parse('https://media.example.com/')), isTrue);
      expect(mediaUrlAllowed(Uri.parse('http://127.0.0.1:6800/')), isTrue);
      expect(mediaUrlAllowed(Uri.parse('http://localhost:6800/')), isTrue);
      expect(
        mediaUrlAllowed(Uri.parse('http://127.0.0.1:6800/'), debug: false),
        isFalse,
      );
      expect(mediaUrlAllowed(Uri.parse('http://192.168.1.5:6800/')), isFalse);
      expect(mediaUrlAllowed(Uri.parse('http://media.example.com/')), isFalse);
    });

    test('only the dev flavor, and only with an address', () {
      const url = 'http://127.0.0.1:6800';
      expect(
        mediaServiceBase(Flavor.dev, url: url),
        Uri.parse('http://127.0.0.1:6800/'),
      );
      expect(mediaServiceBase(Flavor.prod, url: url), isNull);
      expect(mediaServiceBase(Flavor.staging, url: url), isNull);
      expect(mediaServiceBase(Flavor.dev, url: ''), isNull);
      expect(mediaServiceBase(Flavor.dev, url: url, debug: false), isNull);
      expect(mediaServiceBase(Flavor.dev, url: 'http://10.0.0.9:1'), isNull);
    });

    test('without LW_MEDIA_URL nothing changes: flags off, nothing sent', () {
      // No flavor override: an unset address never reads it.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(mediaServiceBaseProvider), isNull);
      expect(c.read(featureFlagsProvider).avatarFromPhoto, isFalse);
      expect(c.read(featureFlagsProvider).avatarMaker, isFalse);
      expect(c.read(avatarMakerApiProvider).available, isFalse);
      expect(c.read(avatarFrameSourceProvider), isA<UnavailableFrameSource>());
    });

    test('with an address: the photo and maker ways turn on', () {
      final c = ProviderContainer(
        overrides: [
          mediaServiceBaseProvider.overrideWithValue(
            Uri.parse('http://127.0.0.1:6800/'),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(featureFlagsProvider).avatarFromPhoto, isTrue);
      expect(c.read(featureFlagsProvider).avatarMaker, isTrue);
      expect(c.read(avatarMakerApiProvider), isA<HttpAvatarMaker>());
      expect(c.read(avatarFrameSourceProvider), isA<MediaServiceFrameSource>());
    });
  });

  group('frame links on the Media Service', () {
    final base = Uri.parse('http://127.0.0.1:6800/');

    test('the source asks with the ID token and resolves the links', () async {
      final asked = <(Uri, String)>[];
      final source = MediaServiceFrameSource(
        base: base,
        idToken: () async => 'id-token',
        fetch: (url, token) async {
          asked.add((url, token));
          return {
            'avatar_frames.json':
                'v1/avatar/files/u1/3/avatar_frames.json?exp=9&sig=ab',
            'odd': 7,
          };
        },
      );
      final urls = await source.signedUrls(uid: 'u1', version: 3);
      expect(asked.single.$1, Uri.parse('${base}v1/avatar/frames/3'));
      expect(asked.single.$2, 'id-token');
      expect(urls.keys, ['avatar_frames.json']);
      expect(
        urls['avatar_frames.json'],
        Uri.parse(
          'http://127.0.0.1:6800/v1/avatar/files/u1/3/avatar_frames.json'
          '?exp=9&sig=ab',
        ),
      );
    });

    test('the cache follows only that service\'s frame files', () {
      final cache = AvatarFrameCache(
        root: () async => Directory.systemTemp,
        source: UnavailableFrameSource(),
        mediaService: base,
      );
      bool follows(String u) => cache.follows(Uri.parse(u));
      expect(
        follows('http://127.0.0.1:6800/v1/avatar/files/u1/1/a.webp'),
        isTrue,
      );
      expect(follows('https://storage.googleapis.com/b/a.webp'), isTrue);
      expect(
        follows('http://127.0.0.1:6801/v1/avatar/files/u1/1/a.webp'),
        isFalse,
      );
      expect(follows('http://127.0.0.1:6800/v1/avatar/jobs/x'), isFalse);
      expect(
        follows('http://evil.example.com/v1/avatar/files/a.webp'),
        isFalse,
      );
      final prod = AvatarFrameCache(
        root: () async => Directory.systemTemp,
        source: UnavailableFrameSource(),
      );
      expect(
        prod.follows(
          Uri.parse('http://127.0.0.1:6800/v1/avatar/files/u1/1/a.webp'),
        ),
        isFalse,
      );
    });
  });
}
