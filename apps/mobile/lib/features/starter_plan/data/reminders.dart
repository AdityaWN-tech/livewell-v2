import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/touchpoints.dart';

/// What a reminder says, in the coach's voice. Generic on purpose: nothing
/// personal or health-related on the lock screen (AGENTS.md), so no name,
/// Why, mood or step text. Tapping it opens the Avatar Moment (T-DLY-03c),
/// which says the rest.
class ReminderTexts {
  const ReminderTexts({
    required this.greetingTitle,
    required this.greetingBody,
    required this.nudgeTitle,
    required this.nudgeBody,
    required this.reflectionTitle,
    required this.reflectionBody,
    required this.weeklyTitle,
    required this.weeklyBody,
    required this.channelName,
  });

  final String greetingTitle;
  final String greetingBody;
  final String nudgeTitle;
  final String nudgeBody;
  final String reflectionTitle;
  final String reflectionBody;
  final String weeklyTitle;
  final String weeklyBody;
  final String channelName;

  (String, String) of(TouchpointKind k) => switch (k) {
    TouchpointKind.greeting => (greetingTitle, greetingBody),
    TouchpointKind.nudge => (nudgeTitle, nudgeBody),
    TouchpointKind.reflection => (reflectionTitle, reflectionBody),
    TouchpointKind.weekly => (weeklyTitle, weeklyBody),
  };
}

/// Local notifications for the plan's touchpoints.
abstract class Reminders {
  /// Asks the OS for permission (Android 13+, iOS). True when allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [items]. [faces] are the
  /// coach's face for each kind (PNG files), shown beside the text where
  /// the lock screen can't show it.
  Future<void> replaceAll(
    List<ScheduledTouchpoint> items,
    ReminderTexts t, {
    Map<TouchpointKind, String> faces = const {},
  });

  Future<void> cancelAll();

  /// Removes reminder [id] from the tray (it was opened another way).
  Future<void> dismiss(int id);

  /// The payload (a [TouchpointKind] name) of each reminder tapped while
  /// the app runs.
  Stream<String> get taps;

  /// The payload of the reminder that started the app, once; then null.
  Future<String?> launchPayload();

  /// The device's IANA time zone, e.g. "Asia/Kolkata".
  Future<String> timeZone();
}

class LocalReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;
  bool _launchRead = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await timeZone()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null) _taps.add(payload);
      },
    );
    _ready = true;
  }

  @override
  Future<String> timeZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Taps arrive once the plugin is set up ([launchPayload] does that).
  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    if (_launchRead) return null;
    _launchRead = true;
    await _init();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp != true) return null;
    return launch?.notificationResponse?.payload;
  }

  @override
  Future<void> replaceAll(
    List<ScheduledTouchpoint> items,
    ReminderTexts t, {
    Map<TouchpointKind, String> faces = const {},
  }) async {
    await _init();
    await _plugin.cancelAll();
    NotificationDetails details(String? face) => NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_plan',
        t.channelName,
        importance: Importance.defaultImportance,
        // Even the generic text stays hidden on a locked screen, and the
        // coach's face with it.
        visibility: NotificationVisibility.private,
        largeIcon: face == null ? null : FilePathAndroidBitmap(face),
      ),
      // No face on iOS: an attachment can show on the lock screen, and the
      // avatar may be drawn from the person's selfie (AGENTS.md).
      iOS: const DarwinNotificationDetails(),
    );
    for (final i in items) {
      final (title, body) = t.of(i.kind);
      await _plugin.zonedSchedule(
        id: i.id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(i.when, tz.local),
        notificationDetails: details(faces[i.kind]),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: i.kind.name,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> dismiss(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}

final remindersProvider = Provider<Reminders>((ref) => LocalReminders());

/// Remembers the time zone the reminders were scheduled in, to reschedule
/// after travel (a trivial UI flag; spec 10.4 allows SharedPreferences).
abstract class ReminderZoneStore {
  Future<String?> load();
  Future<void> save(String zone);
}

class SharedPrefsReminderZoneStore implements ReminderZoneStore {
  static const _key = 'reminders_time_zone';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String zone) async =>
      (await SharedPreferences.getInstance()).setString(_key, zone);
}

final reminderZoneStoreProvider = Provider<ReminderZoneStore>(
  (ref) => SharedPrefsReminderZoneStore(),
);
