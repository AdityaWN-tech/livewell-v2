import '../../checkin/domain/checkin.dart' show localDateKey;

/// A trip in Travel Mode (FR-TRV-01, D-86): users/{uid}/trips/{start}.
/// Dates are local calendar days (yyyy-mm-dd), first and last day
/// included. While a trip is on, the plan's daily step is a travel
/// microhabit and the streak is protected: a trip day without a habit done
/// never breaks the streak or uses the week's rest day.
class Trip {
  const Trip({
    required this.start,
    required this.end,
    required this.timeZone,
    required this.homeTimeZone,
  });

  /// First day (also the document id: one trip per start day).
  final String start;

  /// Last day.
  final String end;

  /// The destination's IANA time zone, e.g. "Europe/London".
  final String timeZone;

  /// The phone's time zone when the trip was planned (home), for the
  /// jet-lag tip.
  final String homeTimeZone;

  String get id => start;

  /// Longest trip Travel Mode covers (the rules check it too).
  static const maxDays = 60;

  bool activeOn(String date) =>
      start.compareTo(date) <= 0 && date.compareTo(end) <= 0;

  bool upcomingOn(String date) => start.compareTo(date) > 0;

  /// 0 on the first day.
  int dayOf(String date) => _days(start, date);

  /// Number of days, first and last included.
  int get lengthDays => _days(start, end) + 1;

  /// Every day of the trip, up to and including [until].
  Iterable<String> datesUntil(String until) sync* {
    final first = DateTime.parse(start);
    for (var i = 0; ; i++) {
      final d = localDateKey(DateTime(first.year, first.month, first.day + i));
      if (d.compareTo(end) > 0 || d.compareTo(until) > 0) return;
      yield d;
    }
  }

  /// Why [start]..[end] can't be saved, or null when it can. [today] is
  /// the local date: a trip can't end in the past.
  static TripProblem? check(String start, String end, String today) {
    if (end.compareTo(start) < 0) return TripProblem.endBeforeStart;
    if (end.compareTo(today) < 0) return TripProblem.inThePast;
    if (_days(start, end) + 1 > maxDays) return TripProblem.tooLong;
    return null;
  }

  factory Trip.fromData(Map<String, dynamic> d) => Trip(
    start: d['start'] as String,
    end: d['end'] as String,
    timeZone: d['tz'] as String,
    homeTimeZone: d['home_tz'] as String,
  );

  Map<String, Object> toData() => {
    'start': start,
    'end': end,
    'tz': timeZone,
    'home_tz': homeTimeZone,
  };

  Trip copyWith({String? end}) => Trip(
    start: start,
    end: end ?? this.end,
    timeZone: timeZone,
    homeTimeZone: homeTimeZone,
  );

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.start == start &&
      other.end == end &&
      other.timeZone == timeZone &&
      other.homeTimeZone == homeTimeZone;

  @override
  int get hashCode => Object.hash(start, end, timeZone, homeTimeZone);
}

enum TripProblem { endBeforeStart, inThePast, tooLong }

int _days(String from, String to) {
  final a = DateTime.utc(
    int.parse(from.substring(0, 4)),
    int.parse(from.substring(5, 7)),
    int.parse(from.substring(8, 10)),
  );
  final b = DateTime.utc(
    int.parse(to.substring(0, 4)),
    int.parse(to.substring(5, 7)),
    int.parse(to.substring(8, 10)),
  );
  return b.difference(a).inDays;
}

/// The trip on [date], else null.
Trip? activeTrip(Iterable<Trip> trips, String date) =>
    trips.where((t) => t.activeOn(date)).firstOrNull;

/// The next trip that hasn't started on [date], else null.
Trip? nextTrip(Iterable<Trip> trips, String date) {
  final later = [
    for (final t in trips)
      if (t.upcomingOn(date)) t,
  ]..sort((a, b) => a.start.compareTo(b.start));
  return later.firstOrNull;
}

/// Days the streak protects (FR-TRV-01): every trip day up to [today].
Set<String> protectedDates(Iterable<Trip> trips, String today) => {
  for (final t in trips) ...t.datesUntil(today),
};

/// Whether a new trip [start]..[end] overlaps one of [trips] (one trip at
/// a time).
bool overlaps(Iterable<Trip> trips, String start, String end) => trips.any(
  (t) => !(end.compareTo(t.start) < 0 || start.compareTo(t.end) > 0),
);
