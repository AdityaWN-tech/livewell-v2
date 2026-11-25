import 'dart:io' show Platform;
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/push.dart';

/// Firebase Cloud Messaging, behind an interface so tests use a fake
/// (T-TCH-01). It never asks for the OS permission itself: the plan's
/// reminder dialog does that (plan_preview_screen), and push only follows.
abstract class PushMessaging {
  /// The OS lets this app notify (granted earlier; never asks).
  Future<bool> permitted();

  /// Turns token generation on (after the notifications consent) and
  /// returns this install's token, or null when there is none yet (iOS
  /// before APNs answered, no Play services, offline).
  Future<String?> token();

  /// New tokens (FCM rotates them).
  Stream<String> get tokenRefresh;

  /// Drops this install's token, so nothing sent to it arrives, and stops
  /// making new ones until [token] is called again.
  Future<void> deleteToken();

  /// Pushes that arrive while the app is open (the OS shows nothing then).
  Stream<PushMessage> get foreground;

  /// Pushes tapped while the app was in the background.
  Stream<PushMessage> get opened;

  /// The push whose tap started the app, once; then null.
  Future<PushMessage?> launchMessage();

  /// 'android' or 'ios'.
  String get platform;
}

class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;
  bool _launchRead = false;

  static Stream<PushMessage> _ours(Stream<RemoteMessage> s) => s
      .map((m) => PushMessage.fromData(m.data))
      .where((m) => m != null)
      .cast<PushMessage>();

  @override
  Future<bool> permitted() async {
    final s = await _fm.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    await _fm.setAutoInitEnabled(true);
    return _fm.getToken();
  }

  @override
  Stream<String> get tokenRefresh => _fm.onTokenRefresh;

  @override
  Future<void> deleteToken() async {
    await _fm.setAutoInitEnabled(false);
    await _fm.deleteToken();
  }

  @override
  Stream<PushMessage> get foreground => _ours(FirebaseMessaging.onMessage);

  @override
  Stream<PushMessage> get opened => _ours(FirebaseMessaging.onMessageOpenedApp);

  @override
  Future<PushMessage?> launchMessage() async {
    if (_launchRead) return null;
    _launchRead = true;
    final m = await _fm.getInitialMessage();
    return m == null ? null : PushMessage.fromData(m.data);
  }

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';
}

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging(),
);

/// A random ID for this install (the device document's ID). Not derived
/// from the hardware or the account, and not personal; stays on the phone.
abstract class PushInstallIdStore {
  Future<String> get();
}

class SharedPrefsPushInstallIdStore implements PushInstallIdStore {
  static const _key = 'push_install_id';

  @override
  Future<String> get() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_key);
    if (saved != null) return saved;
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    final id = String.fromCharCodes(
      List.generate(20, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
    );
    await p.setString(_key, id);
    return id;
  }
}

final pushInstallIdStoreProvider = Provider<PushInstallIdStore>(
  (ref) => SharedPrefsPushInstallIdStore(),
);
