import 'package:firebase_core/firebase_core.dart';

/// Firebase web config for the console, from `--dart-define`s, so no
/// environment is baked into the code (dev, staging, prod; spec 10.3).
/// These are client identifiers, not secrets; access is decided by the
/// Core API and the Firestore rules. See apps/admin/README.md.
///
/// `LW_USE_EMULATORS=true` runs against the local Auth and Functions
/// emulators with the demo project (no real data).
abstract final class FirebaseEnv {
  static const useEmulators = bool.fromEnvironment('LW_USE_EMULATORS');

  static const _apiKey = String.fromEnvironment('LW_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('LW_FIREBASE_APP_ID');
  static const _projectId = String.fromEnvironment('LW_FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('LW_FIREBASE_SENDER_ID');
  static const _authDomain = String.fromEnvironment('LW_FIREBASE_AUTH_DOMAIN');

  /// Cloud Functions region of the Core API.
  static const functionsRegion = String.fromEnvironment(
    'LW_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  /// Null when the build has no config (the console then says so).
  static FirebaseOptions? get options {
    if (useEmulators) {
      return const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:000000000000:web:0000000000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-livewell',
        authDomain: 'demo-livewell.firebaseapp.com',
      );
    }
    if (_apiKey.isEmpty || _appId.isEmpty || _projectId.isEmpty) return null;
    return const FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      projectId: _projectId,
      messagingSenderId: _senderId,
      authDomain: _authDomain == '' ? null : _authDomain,
    );
  }
}
