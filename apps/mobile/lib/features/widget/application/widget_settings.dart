import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile > Daily plan > "Hide details on lock screen" (T-AVT-08g-e,
/// T-TCH-02 TCH-e). **On by default**: the lock-screen widget says "Your
/// next step is ready" instead of the step's name. Kept on this phone only,
/// like the widget itself. Anything unreadable counts as on.
class WidgetHideDetailsSetting extends AsyncNotifier<bool> {
  static const key = 'lw_widget_hide_details';

  @override
  Future<bool> build() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> set(bool hide) async {
    state = AsyncData(hide);
    try {
      await (await SharedPreferences.getInstance()).setBool(key, hide);
    } catch (_) {
      // Not saved: it goes back to on (hidden) at the next start.
    }
  }
}

final widgetHideDetailsProvider =
    AsyncNotifierProvider<WidgetHideDetailsSetting, bool>(
      WidgetHideDetailsSetting.new,
    );
