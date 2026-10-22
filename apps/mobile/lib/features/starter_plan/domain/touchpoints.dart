/// The 3 daily touchpoints (T-ONB-03e) and the rules every scheduled
/// notification follows (FR-DLY-04, FR-TCH-01). Pure, so it can be tested.
library;

/// A wall-clock time of day, in the person's local time zone.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  /// "07:00".
  String get key =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ClockTime? parse(String? s) {
    final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(s ?? '');
    return m == null
        ? null
        : ClockTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  @override
  int compareTo(ClockTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.minutes == minutes;

  @override
  int get hashCode => minutes;
}

enum TouchpointKind {
  /// Morning greeting: hello, the Why, today's step, an affirmation.
  greeting,

  /// Midday nudge tied to the habit's anchor. Counts toward the nudge cap.
  nudge,

  /// Evening reflection: what went well, what got in the way.
  reflection,

  /// Weekly review, Sunday mornings (T-DLY-03c, FR-DLY-06).
  weekly,
}

class TouchpointTimes {
  const TouchpointTimes({
    this.morning = const ClockTime(7, 0),
    this.midday = const ClockTime(13, 0),
    this.evening = const ClockTime(20, 30),
  });

  final ClockTime morning;
  final ClockTime midday;
  final ClockTime evening;

  /// The weekly review's time; Sundays only. TODO(T-DLY-03e): a setting.
  static const weeklyReview = ClockTime(8, 0);

  ClockTime of(TouchpointKind k) => switch (k) {
    TouchpointKind.greeting => morning,
    TouchpointKind.nudge => midday,
    TouchpointKind.reflection => evening,
    TouchpointKind.weekly => weeklyReview,
  };

  TouchpointTimes copyWith(TouchpointKind k, ClockTime t) => TouchpointTimes(
    morning: k == TouchpointKind.greeting ? t : morning,
    midday: k == TouchpointKind.nudge ? t : midday,
    evening: k == TouchpointKind.reflection ? t : evening,
  );

  Map<String, String> toMap() => {
    'morning': morning.key,
    'midday': midday.key,
    'evening': evening.key,
  };

  static TouchpointTimes fromMap(Map<String, dynamic>? m) {
    const d = TouchpointTimes();
    return TouchpointTimes(
      morning: ClockTime.parse(m?['morning'] as String?) ?? d.morning,
      midday: ClockTime.parse(m?['midday'] as String?) ?? d.midday,
      evening: ClockTime.parse(m?['evening'] as String?) ?? d.evening,
    );
  }
}

/// No notifications between [start] and [end] (may cross midnight).
class QuietHours {
  static QuietHours fromMap(Map<String, dynamic>? m) {
    const d = QuietHours();
    return QuietHours(
      start: ClockTime.parse(m?['start'] as String?) ?? d.start,
      end: ClockTime.parse(m?['end'] as String?) ?? d.end,
    );
  }

  Map<String, String> toMap() => {'start': start.key, 'end': end.key};

  const QuietHours({
    this.start = const ClockTime(22, 0),
    this.end = const ClockTime(7, 0),
  });

  final ClockTime start;
  final ClockTime end;

  bool contains(ClockTime t) => start.minutes <= end.minutes
      ? t.minutes >= start.minutes && t.minutes < end.minutes
      : t.minutes >= start.minutes || t.minutes < end.minutes;
}

/// FR-TCH-01: at most 4 notifications a day; FR-DLY-04: at most 3 nudges.
abstract final class NotificationCaps {
  static const perDay = 4;
  static const nudgesPerDay = 3;
}

class ScheduledTouchpoint {
  const ScheduledTouchpoint({
    required this.id,
    required this.when,
    required this.kind,
  });

  /// Stable per date and kind, so rescheduling replaces, never duplicates.
  final int id;

  /// Local wall-clock time; scheduled in the device's time zone, so a time
  /// zone change keeps "7:00 in the morning" (rescheduled on change).
  final DateTime when;
  final TouchpointKind kind;
}

abstract final class TouchpointScheduler {
  static int idFor(DateTime day, TouchpointKind k) =>
      (day.year % 100) * 1000000 + day.month * 10000 + day.day * 100 + k.index;

  /// What to schedule for the plan's [days], from [now]. Skips times that
  /// have passed, fall in quiet hours, or go over the daily caps. With no
  /// notification consent nothing is scheduled; the plan still works in-app.
  static List<ScheduledTouchpoint> build({
    required List<DateTime> days,
    required TouchpointTimes times,
    required QuietHours quiet,
    required bool consent,
    required DateTime now,
    Set<TouchpointKind> enabled = const {...TouchpointKind.values},
  }) {
    if (!consent) return const [];
    final out = <ScheduledTouchpoint>[];
    for (final day in days) {
      var total = 0, nudges = 0;
      for (final k in TouchpointKind.values) {
        // Each category can be turned off (FR-TCH-01).
        if (!enabled.contains(k)) continue;
        if (k == TouchpointKind.weekly && day.weekday != DateTime.sunday) {
          continue;
        }
        final t = times.of(k);
        final when = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (!when.isAfter(now) || quiet.contains(t)) continue;
        if (total >= NotificationCaps.perDay) continue;
        if (k == TouchpointKind.nudge &&
            nudges >= NotificationCaps.nudgesPerDay) {
          continue;
        }
        out.add(ScheduledTouchpoint(id: idFor(day, k), when: when, kind: k));
        total++;
        if (k == TouchpointKind.nudge) nudges++;
      }
    }
    return out;
  }
}

/// Which touchpoints may notify (Profile > Daily plan). All on by default.
Set<TouchpointKind> enabledFromMap(Map<String, dynamic>? m) => {
  for (final k in TouchpointKind.values)
    if (m?[k.name] != false) k,
};

Map<String, bool> enabledToMap(Set<TouchpointKind> s) => {
  for (final k in TouchpointKind.values) k.name: s.contains(k),
};
