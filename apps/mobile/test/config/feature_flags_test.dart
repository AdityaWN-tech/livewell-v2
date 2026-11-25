import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/config/remote_flags.dart';

/// T-FND-11 / D-73: feature flags from Remote Config over safe per-flavour
/// defaults.
class FakeRemoteFlagSource implements RemoteFlagSource {
  FakeRemoteFlagSource({
    this.cachedValues = const {},
    this.fetched = const {},
    this.cachedFails = false,
    this.fetchFails = false,
  });

  final Map<String, String> cachedValues;
  final Map<String, String> fetched;
  final bool cachedFails;
  final bool fetchFails;
  int fetches = 0;

  @override
  Future<Map<String, String>> cached() async {
    if (cachedFails) throw StateError('no cache');
    return cachedValues;
  }

  @override
  Future<Map<String, String>> fetchAndActivate() async {
    fetches++;
    if (fetchFails) throw StateError('offline');
    return fetched;
  }
}

Map<String, String> allRemote(String value) => {
  for (final f in Flag.values) f.remoteKey: value,
};

const sensitive = {
  Flag.voiceClone,
  Flag.drGokulaVoice,
  Flag.avatarFromPhoto,
  Flag.lovedOneVoice,
  Flag.photorealStreaming,
};

ProviderContainer container(Flavor flavor, RemoteFlagSource? source) {
  final c = ProviderContainer(
    overrides: [
      flavorProvider.overrideWithValue(flavor),
      remoteFlagSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('defaults per flavour (nothing changes until the console is set)', () {
    for (final flavor in Flavor.values) {
      test('${flavor.name}: every flag off without a Media Service', () {
        final flags = resolveFeatureFlags(flavor);
        for (final f in Flag.values) {
          expect(flags[f], isFalse, reason: f.name);
        }
      });
    }

    test('dev with a Media Service turns the avatar maker and photo on', () {
      final flags = resolveFeatureFlags(Flavor.dev, mediaDev: true);
      expect(flags.avatarMaker, isTrue);
      expect(flags.avatarFromPhoto, isTrue);
      expect(flags.voiceClone, isFalse);
    });

    test('staging and prod ignore a Media Service', () {
      for (final flavor in [Flavor.staging, Flavor.prod]) {
        final flags = resolveFeatureFlags(flavor, mediaDev: true);
        expect(flags.avatarMaker, isFalse);
        expect(flags.avatarFromPhoto, isFalse);
      }
    });

    test('provider without Firebase: the defaults', () {
      final c = container(Flavor.prod, null);
      expect(
        c.read(featureFlagsProvider).toString(),
        const FeatureFlags().toString(),
      );
    });
  });

  group('remote values override the defaults', () {
    test('dev and staging: every flag can be turned on and off', () {
      for (final flavor in [Flavor.dev, Flavor.staging]) {
        final on = resolveFeatureFlags(flavor, remote: allRemote('true'));
        final off = resolveFeatureFlags(
          flavor,
          remote: allRemote('false'),
          mediaDev: true,
        );
        for (final f in Flag.values) {
          expect(on[f], isTrue, reason: '${flavor.name} ${f.name} on');
          expect(off[f], isFalse, reason: '${flavor.name} ${f.name} off');
        }
      }
    });

    test('prod: the unlocked flags can be turned on', () {
      final flags = resolveFeatureFlags(Flavor.prod, remote: allRemote('true'));
      for (final f in Flag.values.where((f) => !f.prodLocked)) {
        expect(flags[f], isTrue, reason: f.name);
      }
    });

    test('kill switch: a remote false turns a dev default off', () {
      final flags = resolveFeatureFlags(
        Flavor.dev,
        remote: {Flag.avatarMaker.remoteKey: 'false'},
        mediaDev: true,
      );
      expect(flags.avatarMaker, isFalse);
      expect(flags.avatarFromPhoto, isTrue);
    });

    test('the provider applies cached values, then the fetched ones', () async {
      final source = FakeRemoteFlagSource(
        cachedValues: {Flag.briefings.remoteKey: 'true'},
        fetched: {Flag.portalCards.remoteKey: 'true'},
      );
      final c = container(Flavor.staging, source);
      expect(c.read(featureFlagsProvider).briefings, isFalse);
      await c.read(remoteFlagValuesProvider.notifier).load();
      final flags = c.read(featureFlagsProvider);
      expect(flags.portalCards, isTrue);
      expect(flags.briefings, isFalse, reason: 'fetched values replace');
      expect(source.fetches, 1);
    });

    test('offline: the cached values stay', () async {
      final c = container(
        Flavor.staging,
        FakeRemoteFlagSource(
          cachedValues: {Flag.coachChat.remoteKey: 'true'},
          fetchFails: true,
        ),
      );
      await c.read(remoteFlagValuesProvider.notifier).load();
      expect(c.read(featureFlagsProvider).coachChat, isTrue);
    });

    test('Remote Config failing entirely: the defaults, no error', () async {
      final c = container(
        Flavor.dev,
        FakeRemoteFlagSource(cachedFails: true, fetchFails: true),
      );
      await c.read(remoteFlagValuesProvider.notifier).load();
      expect(
        c.read(featureFlagsProvider).toString(),
        const FeatureFlags().toString(),
      );
    });
  });

  group('invalid or missing values fall back to the default', () {
    test('only true/false (any case, trimmed) are read', () {
      expect(parseFlagValue('true'), isTrue);
      expect(parseFlagValue(' TRUE '), isTrue);
      expect(parseFlagValue('False'), isFalse);
      for (final bad in [null, '', '1', '0', 'yes', 'on', 'tru', '{}']) {
        expect(parseFlagValue(bad), isNull, reason: '$bad');
      }
    });

    test('garbage keeps the default either way', () {
      final flags = resolveFeatureFlags(
        Flavor.dev,
        mediaDev: true,
        remote: {
          Flag.avatarMaker.remoteKey: 'nope',
          Flag.briefings.remoteKey: '1',
        },
      );
      expect(flags.avatarMaker, isTrue);
      expect(flags.briefings, isFalse);
    });

    test('unknown parameters do nothing', () {
      final flags = resolveFeatureFlags(
        Flavor.prod,
        remote: {
          'safety_routing': 'false',
          'consent_required': 'false',
          'frequency_cap': 'false',
          'closed_script': 'false',
          'voiceClone': 'true', // the Dart name, not the parameter name
        },
      );
      expect(flags.toString(), const FeatureFlags().toString());
    });
  });

  group('prod-locked flags (counsel / licence sign-off)', () {
    test('exactly the sensitive flags are locked', () {
      expect(Flag.values.where((f) => f.prodLocked).toSet(), sensitive);
    });

    test('prod: cannot be turned on remotely', () {
      final flags = resolveFeatureFlags(Flavor.prod, remote: allRemote('true'));
      for (final f in sensitive) {
        expect(flags[f], isFalse, reason: f.name);
      }
    });

    test('prod through the provider, with the real build (no allow)', () async {
      final c = container(
        Flavor.prod,
        FakeRemoteFlagSource(fetched: allRemote('true')),
      );
      await c.read(remoteFlagValuesProvider.notifier).load();
      final flags = c.read(featureFlagsProvider);
      for (final f in sensitive) {
        expect(flags[f], isFalse, reason: f.name);
      }
      expect(flags.portalCards, isTrue);
    });

    test('prod: only a build-time allow lets one be turned on', () {
      final allow = parseProdAllow(' voiceClone ,nonsense,drGokulaVoice');
      expect(allow, {Flag.voiceClone, Flag.drGokulaVoice});
      final flags = resolveFeatureFlags(
        Flavor.prod,
        remote: allRemote('true'),
        prodAllow: allow,
      );
      expect(flags.voiceClone, isTrue);
      expect(flags.drGokulaVoice, isTrue);
      expect(flags.avatarFromPhoto, isFalse);
      expect(flags.lovedOneVoice, isFalse);
      expect(flags.photorealStreaming, isFalse);
    });

    test('the allow alone turns nothing on', () {
      final flags = resolveFeatureFlags(
        Flavor.prod,
        prodAllow: Flag.values.toSet(),
      );
      expect(flags.toString(), const FeatureFlags().toString());
    });

    test('normal builds carry no allow', () {
      expect(prodAllowFlagsDefine, isEmpty);
      expect(parseProdAllow(prodAllowFlagsDefine), isEmpty);
    });
  });

  test('minimum fetch interval per flavour', () {
    expect(minimumFetchIntervalFor(Flavor.dev), const Duration(minutes: 5));
    expect(minimumFetchIntervalFor(Flavor.staging), const Duration(hours: 1));
    expect(minimumFetchIntervalFor(Flavor.prod), const Duration(hours: 12));
  });

  test('the console template lists every flag, with in-app defaults', () {
    final file = File('../../firebase/remoteconfig.template.json');
    final template =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final params = template['parameters'] as Map<String, dynamic>;
    expect(params.keys.toSet(), Flag.values.map((f) => f.remoteKey).toSet());
    for (final p in params.values.cast<Map<String, dynamic>>()) {
      expect(p['valueType'], 'BOOLEAN');
      expect(p['defaultValue'], {'useInAppDefault': true});
    }
    expect(template['conditions'], isEmpty);
  });
}
