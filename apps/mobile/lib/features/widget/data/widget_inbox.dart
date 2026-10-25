import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/config/flavor.dart';
import 'widget_publisher.dart';

/// What a widget button asks the app to do (T-AVT-08g-b).
enum WidgetLink {
  checkIn,
  step,
  makeSmaller,
  done,
  reflect,
  home,
  // My Daily Routine (T-GOL-03e).
  routine,
  routineDone,
}

/// `livewell://checkin`, `livewell://step` (`?smaller=1`, `?done=1`),
/// `livewell://reflection`, `livewell://home`, `livewell://routine`
/// (`?done=1&r=<routine payload>`); anything else is ignored.
WidgetLink? parseWidgetLink(Uri? uri) {
  if (uri == null || uri.scheme != 'livewell') return null;
  return switch (uri.host) {
    'routine' when uri.queryParameters['done'] == '1' => WidgetLink.routineDone,
    'routine' => WidgetLink.routine,
    'checkin' => WidgetLink.checkIn,
    'step' when uri.queryParameters['done'] == '1' => WidgetLink.done,
    'step' when uri.queryParameters['smaller'] == '1' => WidgetLink.makeSmaller,
    'step' => WidgetLink.step,
    'reflection' => WidgetLink.reflect,
    'home' => WidgetLink.home,
    _ => null,
  };
}

/// What the widget hands back to the app: the link that opened it, and a
/// Done tapped on the widget itself (iOS 17+, Android 12+), which the app
/// applies once, the next time it runs.
abstract class WidgetInbox {
  /// The link the app was opened with from the widget, once; then null.
  Future<WidgetLink?> launchLink();

  /// Links tapped while the app runs.
  Stream<WidgetLink> get links;

  /// The local date (yyyy-MM-dd) Done was tapped on the widget, once; then
  /// null.
  Future<String?> takeDone();

  /// The routine item of the last [WidgetLink.routineDone] (its routine
  /// payload), once; then null.
  String? takeRoutinePayload();
}

/// The routine payload a routine Done link carries, or null.
String? routinePayloadOf(Uri? uri) =>
    uri != null && uri.host == 'routine' ? uri.queryParameters['r'] : null;

class HomeWidgetInbox implements WidgetInbox {
  HomeWidgetInbox(this.appGroupId);

  final String appGroupId;

  /// Written by the widget's Done (iOS App Intent, Android action).
  static const doneKey = 'lw_done_date';
  bool _launchRead = false;
  String? _routinePayload;

  WidgetLink? _read(Uri? uri) {
    final link = parseWidgetLink(uri);
    if (link == WidgetLink.routineDone) _routinePayload = routinePayloadOf(uri);
    return link;
  }

  @override
  String? takeRoutinePayload() {
    final p = _routinePayload;
    _routinePayload = null;
    return p;
  }

  @override
  Future<WidgetLink?> launchLink() async {
    if (_launchRead) return null;
    _launchRead = true;
    try {
      return _read(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<WidgetLink> get links => HomeWidget.widgetClicked
      .map(_read)
      .where((l) => l != null)
      .cast<WidgetLink>()
      .handleError((Object _) {});

  @override
  Future<String?> takeDone() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      final date = await HomeWidget.getWidgetData<String>(doneKey);
      if (date != null) await HomeWidget.saveWidgetData<String>(doneKey, null);
      return date;
    } catch (_) {
      return null;
    }
  }
}

final widgetInboxProvider = Provider<WidgetInbox>(
  (ref) => HomeWidgetInbox(appGroupFor(ref.watch(flavorProvider))),
);
