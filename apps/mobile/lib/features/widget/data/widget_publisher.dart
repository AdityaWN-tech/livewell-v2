import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/config/flavor.dart';
import '../domain/widget_snapshot.dart';

/// Hands the snapshot to the native home-screen widgets.
abstract class WidgetPublisher {
  Future<void> publish(WidgetSnapshot snapshot);
}

/// Each flavour's App Group (D-40), shared by the app and its widget.
String appGroupFor(Flavor f) => switch (f) {
  Flavor.dev => 'group.net.conciergeconnectedcare.livewell.dev',
  Flavor.staging => 'group.net.conciergeconnectedcare.livewell.stg',
  Flavor.prod => 'group.net.conciergeconnectedcare.livewell',
};

/// `home_widget`: the iOS App Group's shared defaults, Android's shared
/// preferences. The native widgets read [key] (iOS: WidgetKit, Android:
/// Glance; added in the next PRs).
class HomeWidgetPublisher implements WidgetPublisher {
  HomeWidgetPublisher(this.appGroupId);

  final String appGroupId;

  static const key = 'lw_snapshot';
  static const iOSName = 'LiveWellWidget';
  static const androidName = 'LiveWellWidgetReceiver';

  /// The face files last copied for the iOS widget (path → size).
  final _copied = <String, int>{};

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      if (Platform.isIOS) await _copyFaces(snapshot.avatarThumbs);
      await HomeWidget.saveWidgetData<String>(
        key,
        jsonEncode(snapshot.toJson()),
      );
      await HomeWidget.updateWidget(iOSName: iOSName, androidName: androidName);
    } catch (_) {
      // No widget on this device (or not added yet): nothing to update.
    }
  }

  /// The iOS widget can't read the app's own files, so each face goes
  /// into the App Group's shared defaults (`lw_face_<expression>`, a small
  /// PNG as base64), only when it changed. Android's widget runs in the
  /// app and reads the paths directly.
  Future<void> _copyFaces(Map<String, String> faces) async {
    for (final MapEntry(key: expression, value: path) in faces.entries) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final size = file.lengthSync();
      final id = '$expression:$path';
      if (_copied[id] == size) continue;
      await HomeWidget.saveWidgetData<String>(
        'lw_face_$expression',
        base64Encode(await file.readAsBytes()),
      );
      _copied[id] = size;
    }
  }
}

final widgetPublisherProvider = Provider<WidgetPublisher>(
  (ref) => HomeWidgetPublisher(appGroupFor(ref.watch(flavorProvider))),
);
