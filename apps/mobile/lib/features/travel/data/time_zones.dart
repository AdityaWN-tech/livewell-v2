import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// IANA time zones for a trip (FR-TRV-01), from the time-zone database
/// bundled with the app (works offline).
class TimeZones {
  TimeZones() {
    // Only when nobody loaded it yet: loading resets tz.local, which the
    // reminders set (starter_plan/data/reminders.dart).
    if (tz.timeZoneDatabase.locations.isEmpty) tzdata.initializeTimeZones();
  }

  /// Common choices first: the two markets (D-03), then big travel hubs.
  static const common = [
    'Asia/Kolkata',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Phoenix',
    'America/Los_Angeles',
    'America/Anchorage',
    'Pacific/Honolulu',
    'Europe/London',
    'Europe/Paris',
    'Asia/Dubai',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  /// Every zone name, sorted (for the search).
  List<String> get all {
    final names = [
      for (final n in tz.timeZoneDatabase.locations.keys)
        if (n.contains('/') && !n.startsWith('Etc/')) n,
    ]..sort();
    return names;
  }

  bool isKnown(String name) => tz.timeZoneDatabase.locations.containsKey(name);

  /// The zone's offset from UTC at [at], or null for an unknown name.
  Duration? offset(String name, DateTime at) {
    if (!isKnown(name)) return null;
    final zone = tz
        .getLocation(name)
        .timeZone(at.toUtc().millisecondsSinceEpoch);
    return zone.offset;
  }

  /// "London (Europe)", for a zone name such as "Europe/London".
  static String label(String name) {
    final parts = name.split('/');
    final city = parts.last.replaceAll('_', ' ');
    if (parts.length == 1) return city;
    return '$city (${parts.first.replaceAll('_', ' ')})';
  }
}

final timeZonesProvider = Provider<TimeZones>((ref) => TimeZones());
