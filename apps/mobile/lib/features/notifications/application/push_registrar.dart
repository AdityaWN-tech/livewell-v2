import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/application/coach_job_watcher.dart' show CoachNoticeTexts;
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../starter_plan/data/reminders.dart';
import '../data/device_registry.dart';
import '../data/push_messaging.dart';
import '../domain/push.dart';

/// The app's own words for a push shown while it is open: the same generic
/// lines as the local reminders and the coach notice (nothing personal or
/// health-related on the lock screen, AGENTS.md).
class PushTexts {
  const PushTexts({required this.reminders, required this.coach});

  final ReminderTexts reminders;
  final CoachNoticeTexts coach;

  /// (title, body, Android channel name).
  (String, String, String) of(PushCategory c) {
    final k = c.touchpoint;
    if (k != null) {
      final (title, body) = reminders.of(k);
      return (title, body, reminders.channelName);
    }
    return c == PushCategory.coachNotMade
        ? (coach.notMadeTitle, coach.notMadeBody, coach.channelName)
        : (coach.readyTitle, coach.readyBody, coach.channelName);
  }
}

/// Registers this phone for server pushes (T-TCH-01, D-77), only while
/// someone is signed in, the notifications consent is on and the OS lets
/// the app notify. It never asks for the OS permission: the plan's reminder
/// dialog does that. Turning the consent off removes the device and drops
/// its token at once; so does logging out ([unregister]). Deleting the
/// account removes every device on the server (recursive delete).
class PushRegistrar {
  PushRegistrar(this._ref);

  final Ref _ref;

  /// The id of a push shown while the app is open (one at a time).
  static const foregroundNoticeId = 7200;

  /// Writes and deletes wait at most this long: offline, Firestore queues
  /// them, and logging out must not hang on that.
  static const writeTimeout = Duration(seconds: 5);

  final _taps = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  PushTexts? _texts;
  bool _started = false;

  /// Who this phone is registered for, as far as this session knows.
  String? _registeredFor;
  String? _token;
  bool _cleared = false;

  /// Payloads of pushes tapped while the app runs (same format as the
  /// local reminders' taps).
  Stream<String> get taps => _taps.stream;

  PushMessaging get _push => _ref.read(pushMessagingProvider);

  /// Starts following the consent, the token and incoming pushes. Safe to
  /// call again (Home calls it on every start).
  Future<void> start(PushTexts texts) async {
    _texts = texts;
    if (_started) return sync();
    _started = true;
    try {
      _subs
        ..add(
          _ref
              .read(consentRepositoryProvider)
              .watchRecords()
              .listen((_) => sync(), onError: (Object _) {}),
        )
        ..add(_push.tokenRefresh.listen(_onNewToken, onError: (Object _) {}))
        ..add(_push.foreground.listen(_showOpen, onError: (Object _) {}))
        ..add(
          _push.opened.listen(
            (m) => _taps.add(m.tapPayload),
            onError: (Object _) {},
          ),
        );
    } catch (_) {
      // No Firebase Messaging on this device: local reminders still work.
    }
    await sync();
  }

  /// The payload of the push whose tap started the app, once.
  Future<String?> launchPayload() async {
    try {
      return (await _push.launchMessage())?.tapPayload;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _consent() async => isGranted(
    currentConsents(
      await _ref.read(consentRepositoryProvider).watchRecords().first,
    ),
    ConsentType.notifications,
  );

  Future<void> _queue = Future.value();

  /// Registers or removes this device to match the consent and the OS
  /// permission, one run at a time. Best effort: a failure leaves things
  /// for the next start.
  Future<void> sync() => _queue = _queue.then((_) => _sync());

  Future<void> _sync() async {
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      if (!await _consent() || !await _push.permitted()) {
        await _remove(uid);
        return;
      }
      final token = await _push.token();
      if (token == null) return;
      await _save(uid, token);
    } catch (_) {
      // Offline, no Play services, APNs not ready: tried again next start.
    }
  }

  Future<void> _onNewToken(String token) async {
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      if (!await _consent()) return;
      await _save(uid, token);
    } catch (_) {}
  }

  Future<void> _save(String uid, String token) async {
    if (_registeredFor == uid && _token == token) return;
    final id = await _ref.read(pushInstallIdStoreProvider).get();
    final zone = await _ref.read(remindersProvider).timeZone();
    await _ref
        .read(deviceRegistryProvider)
        .save(
          uid,
          id,
          DeviceRecord(token: token, platform: _push.platform, timeZone: zone),
        )
        .timeout(writeTimeout);
    _registeredFor = uid;
    _token = token;
    _cleared = false;
  }

  /// Removes the device and drops its token (also when it was registered
  /// by an earlier session: once per session without the consent).
  Future<void> _remove(String uid) async {
    if (_cleared && _registeredFor == null) return;
    _registeredFor = null;
    _token = null;
    _cleared = true;
    try {
      await _push.deleteToken();
    } catch (_) {}
    final id = await _ref.read(pushInstallIdStoreProvider).get();
    await _ref
        .read(deviceRegistryProvider)
        .remove(uid, id)
        .timeout(writeTimeout);
  }

  /// Log out (and after deleting the account): call while still signed
  /// in. The token is dropped even when the delete can't reach the server,
  /// so the server finds it invalid and removes the device itself.
  Future<void> unregister() async {
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    // Not awaited: a stream's cancel can wait on its source (a live
    // Firestore query), and logging out must not.
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _started = false;
    _cleared = false;
    if (uid == null) return;
    try {
      _registeredFor = uid; // make sure _remove runs
      await _remove(uid);
    } catch (_) {
      // Offline or already deleted with the account.
    }
  }

  /// A push while the app is open: the OS shows nothing, so the app shows
  /// its own generic words for the category (never the push's text), and
  /// only with the consent.
  Future<void> _showOpen(PushMessage m) async {
    final texts = _texts;
    if (texts == null) return;
    try {
      if (!await _consent()) return;
      final (title, body, channel) = texts.of(m.category);
      await _ref
          .read(remindersProvider)
          .showNow(
            id: foregroundNoticeId,
            title: title,
            body: body,
            channelName: channel,
            payload: m.tapPayload,
          );
    } catch (_) {}
  }
}

final pushRegistrarProvider = Provider<PushRegistrar>(PushRegistrar.new);
