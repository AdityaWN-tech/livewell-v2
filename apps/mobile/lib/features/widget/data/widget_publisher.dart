import 'dart:convert';

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

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>(
        key,
        jsonEncode(snapshot.toJson()),
      );
      await HomeWidget.updateWidget(iOSName: iOSName, androidName: androidName);
    } catch (_) {
      // No widget on this device (or not added yet): nothing to update.
    }
  }
}

final widgetPublisherProvider = Provider<WidgetPublisher>(
  (ref) => HomeWidgetPublisher(appGroupFor(ref.watch(flavorProvider))),
);
