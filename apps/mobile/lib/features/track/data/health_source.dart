import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../domain/health_summary.dart';

/// Reads steps and sleep from Apple Health (iOS) or Health Connect
/// (Android) on the phone (Step 4f, D-59). Read only; nothing it reads is
/// saved to the server.
abstract class HealthSource {
  Future<HealthAvailability> availability();

  /// Shows the system's permission screen. True when the person allowed
  /// it (iOS never says, so true there once the screen was shown).
  Future<bool> requestAccess();

  /// This week, Monday to Sunday, up to [now].
  Future<HealthSummary> week(DateTime now);

  /// Opens the store page for Health Connect.
  Future<void> install();
}

class DeviceHealthSource implements HealthSource {
  final _health = Health();
  Future<void>? _ready;

  static final _sleep = defaultTargetPlatform == TargetPlatform.iOS
      ? HealthDataType.SLEEP_ASLEEP
      : HealthDataType.SLEEP_SESSION;
  static List<HealthDataType> get _types => [HealthDataType.STEPS, _sleep];

  Future<void> _configure() => _ready ??= _health.configure();

  @override
  Future<HealthAvailability> availability() async {
    if (kIsWeb) return HealthAvailability.unavailable;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return HealthAvailability.available;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return HealthAvailability.unavailable;
    }
    try {
      await _configure();
      return switch (await _health.getHealthConnectSdkStatus()) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthAvailability.needsInstall,
        _ => HealthAvailability.unavailable,
      };
    } catch (_) {
      return HealthAvailability.unavailable;
    }
  }

  @override
  Future<bool> requestAccess() async {
    await _configure();
    final types = _types;
    return _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ],
    );
  }

  @override
  Future<HealthSummary> week(DateTime now) async {
    await _configure();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final steps = <int>[];
    for (var i = 0; i < 7; i++) {
      final start = DateTime(monday.year, monday.month, monday.day + i);
      if (start.isAfter(now)) {
        steps.add(0);
        continue;
      }
      final end = DateTime(start.year, start.month, start.day + 1);
      steps.add(
        await _health.getTotalStepsInInterval(
              start,
              end.isAfter(now) ? now : end,
            ) ??
            0,
      );
    }
    final points = await _health.getHealthDataFromTypes(
      types: [_sleep],
      startTime: now.subtract(const Duration(days: 7)),
      endTime: now,
    );
    return HealthSummary(
      stepsWeek: steps,
      sleepMinutesAverage: averageSleepMinutes([
        for (final p in points) (p.dateFrom, p.dateTo),
      ]),
    );
  }

  @override
  Future<void> install() => _health.installHealthConnect();
}

final healthSourceProvider = Provider<HealthSource>(
  (ref) => DeviceHealthSource(),
);
