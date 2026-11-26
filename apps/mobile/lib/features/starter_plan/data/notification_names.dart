import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Show task names in notifications" (D-111): off by default. When on, a
/// step or routine reminder names its task, but only while the phone is
/// unlocked: reminders stay private on the lock screen
/// (NotificationVisibility.private; iOS previews follow the phone's
/// setting). Kept on this phone only.
class NotificationNames extends AsyncNotifier<bool> {
  static const key = 'notification_task_names';

  @override
  Future<bool> build() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool on) async {
    state = AsyncData(on);
    try {
      await (await SharedPreferences.getInstance()).setBool(key, on);
    } catch (_) {}
  }
}

final notificationNamesProvider =
    AsyncNotifierProvider<NotificationNames, bool>(NotificationNames.new);
