import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flavor.dart';

/// Where the raw feature-flag values come from (T-FND-11, D-73).
abstract class RemoteFlagSource {
  /// Values activated on an earlier launch (cached on this phone), so a
  /// flag set in the console applies from the start of the next launch.
  Future<Map<String, String>> cached();

  /// Fetches the latest values (at most once per minimum fetch interval)
  /// and activates them; returns what is then in effect.
  Future<Map<String, String>> fetchAndActivate();
}

/// How long fetched values are reused before asking the server again.
/// Short in dev so a console change shows up on the next start; longer in
/// staging and prod (Remote Config throttles frequent fetches).
Duration minimumFetchIntervalFor(Flavor flavor) => switch (flavor) {
  Flavor.dev => const Duration(minutes: 5),
  Flavor.staging => const Duration(hours: 1),
  Flavor.prod => const Duration(hours: 12),
};

/// Firebase Remote Config. Only values set in the console (source remote)
/// are returned; the in-app defaults live in Dart (`defaultFlagsFor`), so
/// they are the same with or without Firebase.
class FirebaseRemoteFlagSource implements RemoteFlagSource {
  FirebaseRemoteFlagSource(this._config, this._flavor);

  final FirebaseRemoteConfig _config;
  final Flavor _flavor;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: minimumFetchIntervalFor(_flavor),
      ),
    );
    await _config.ensureInitialized();
    _ready = true;
  }

  Map<String, String> _remoteValues() => {
    for (final e in _config.getAll().entries)
      if (e.value.source == ValueSource.valueRemote) e.key: e.value.asString(),
  };

  @override
  Future<Map<String, String>> cached() async {
    await _init();
    return _remoteValues();
  }

  @override
  Future<Map<String, String>> fetchAndActivate() async {
    await _init();
    await _config.fetchAndActivate();
    return _remoteValues();
  }
}

/// The Remote Config source, or null when Firebase isn't set up (tests, a
/// flavour without a Firebase project): then the build's defaults apply.
final remoteFlagSourceProvider = Provider<RemoteFlagSource?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseRemoteFlagSource(
    FirebaseRemoteConfig.instance,
    ref.watch(flavorProvider),
  );
});

/// Raw Remote Config values (parameter name to string) set in the console.
/// Empty until [RemoteFlagValues.load] runs, and whenever anything fails.
class RemoteFlagValues extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  /// Applies the cached values, then fetches new ones. Never throws: any
  /// failure keeps what is already in effect (or the defaults).
  Future<void> load() async {
    final RemoteFlagSource? source;
    try {
      source = ref.read(remoteFlagSourceProvider);
    } catch (_) {
      return; // Firebase not reachable: the defaults apply.
    }
    if (source == null) return;
    try {
      _set(await source.cached());
    } catch (_) {
      // No cache yet or Remote Config unavailable: keep the defaults.
    }
    try {
      _set(await source.fetchAndActivate());
    } catch (_) {
      // Offline or throttled: the cached values stay.
    }
  }

  void _set(Map<String, String> values) {
    if (ref.mounted) state = Map.unmodifiable(values);
  }
}

final remoteFlagValuesProvider =
    NotifierProvider<RemoteFlagValues, Map<String, String>>(
      RemoteFlagValues.new,
    );
