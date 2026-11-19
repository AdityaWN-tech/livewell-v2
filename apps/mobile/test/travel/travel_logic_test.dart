import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livewell/features/track/domain/streak.dart';
import 'package:livewell/features/track/domain/track_models.dart';
import 'package:livewell/features/travel/data/places_source.dart';
import 'package:livewell/features/travel/data/time_zones.dart';
import 'package:livewell/features/travel/domain/places.dart';
import 'package:livewell/features/travel/domain/travel_content.dart';
import 'package:livewell/features/travel/domain/trip.dart';

const trip = Trip(
  start: '2026-10-10',
  end: '2026-10-16',
  timeZone: 'Europe/London',
  homeTimeZone: 'America/New_York',
);

TravelContent content() =>
    TravelContent.parse(File('assets/travel/travel.json').readAsStringSync());

void main() {
  group('Travel content (FR-TRV-02)', () {
    test('the app bundles an exact copy of content/travel', () {
      expect(
        File('assets/travel/travel.json').readAsStringSync(),
        File('../../content/travel/travel.json').readAsStringSync(),
      );
    });

    test('four pillars in order, at least 2 items each', () {
      final c = content();
      expect([for (final p in c.pillars) p.id], TravelContent.pillarIds);
      expect(
        [for (final p in c.pillars) p.title],
        ['Eat Well', 'Move Well', 'Sleep and Recover', 'Breathe and Reset'],
      );
      for (final p in c.pillars) {
        expect(p.items.length, greaterThanOrEqualTo(2), reason: p.id);
      }
    });

    test('has hotel-room routines and jet-lag tips', () {
      final c = content();
      final items = [for (final p in c.pillars) ...p.items];
      expect(
        items.where((i) => i.title.toLowerCase().contains('hotel-room')),
        isNotEmpty,
      );
      expect(
        items.where((i) => i.title.toLowerCase().contains('jet lag')),
        hasLength(greaterThanOrEqualTo(2)),
      );
      for (final d in JetLagDirection.values) {
        expect(c.tipFor(d), isNotNull, reason: d.name);
      }
    });

    test('ids are unique; every microhabit belongs to a pillar', () {
      final c = content();
      final ids = [
        for (final p in c.pillars) ...[for (final i in p.items) i.id],
        for (final h in c.microhabits) h.id,
        for (final j in c.jetLag) j.id,
      ];
      expect(ids.toSet().length, ids.length);
      for (final h in c.microhabits) {
        expect(c.pillar(h.pillar), isNotNull, reason: h.id);
      }
    });

    test('nothing v2 doesn\'t allow: no medication, supplements, fasting, '
        'calorie or weight-loss talk, alcohol or placeholders', () {
      final c = content();
      final texts = [
        c.stepLabel,
        for (final p in c.pillars) ...[
          p.title,
          p.intro,
          for (final i in p.items) ...[i.title, i.body],
        ],
        for (final j in c.jetLag) ...[j.title, j.body],
        for (final h in c.microhabits) ...[h.title, h.reason, ?h.smallerTitle],
      ];
      final banned = RegExp(
        r'medic|supplement|melatonin|\bpills?\b|sleeping aid|\bfast(ing)?\b|'
        r'calorie|weight|\bdiet\b|keto|detox|alcohol|wine|beer|\bcure|'
        r'\bmust\b|\bshould\b',
        caseSensitive: false,
      );
      for (final t in texts) {
        expect(banned.hasMatch(t), isFalse, reason: t);
        expect(t.contains('{'), isFalse, reason: t);
      }
    });

    test('pending content: dev only; prod waits for approval', () {
      final c = content();
      expect(c.approved, isFalse);
      expect(c.usable(isDev: true), isTrue);
      expect(c.usable(isDev: false), isFalse);
    });

    test('one microhabit per trip day, in turn; no movement when activity '
        'is limited (FR-GOL-03)', () {
      final c = content();
      expect(
        c.stepFor(tripDay: 0, activityLimited: false)!.id,
        c.microhabits.first.id,
      );
      expect(
        c.stepFor(tripDay: 1, activityLimited: false)!.id,
        c.microhabits[1].id,
      );
      expect(
        c.stepFor(tripDay: c.microhabits.length, activityLimited: false)!.id,
        c.microhabits.first.id,
      );
      for (var d = 0; d < 20; d++) {
        expect(c.stepFor(tripDay: d, activityLimited: true)!.movement, isFalse);
      }
    });
  });

  group('Trips (FR-TRV-01)', () {
    test('active from the first to the last day', () {
      expect(trip.activeOn('2026-10-09'), isFalse);
      expect(trip.activeOn('2026-10-10'), isTrue);
      expect(trip.activeOn('2026-10-16'), isTrue);
      expect(trip.activeOn('2026-10-17'), isFalse);
      expect(trip.upcomingOn('2026-10-09'), isTrue);
      expect(trip.dayOf('2026-10-14'), 4);
      expect(trip.lengthDays, 7);
    });

    test('checks: end before start, in the past, longer than 60 days', () {
      expect(
        Trip.check('2026-10-20', '2026-10-19', '2026-10-14'),
        TripProblem.endBeforeStart,
      );
      expect(
        Trip.check('2026-10-01', '2026-10-13', '2026-10-14'),
        TripProblem.inThePast,
      );
      expect(Trip.check('2026-10-14', '2026-12-12', '2026-10-14'), isNull);
      expect(
        Trip.check('2026-10-14', '2026-12-13', '2026-10-14'),
        TripProblem.tooLong,
      );
      expect(Trip.check('2026-10-14', '2026-10-14', '2026-10-14'), isNull);
    });

    test('protected days: every trip day so far, across past trips', () {
      const old = Trip(
        start: '2026-09-28',
        end: '2026-09-29',
        timeZone: 'Asia/Kolkata',
        homeTimeZone: 'America/New_York',
      );
      expect(protectedDates([trip, old], '2026-10-12'), {
        '2026-09-28',
        '2026-09-29',
        '2026-10-10',
        '2026-10-11',
        '2026-10-12',
      });
    });

    test('current, next and overlap', () {
      const later = Trip(
        start: '2026-11-01',
        end: '2026-11-03',
        timeZone: 'Asia/Kolkata',
        homeTimeZone: 'America/New_York',
      );
      expect(activeTrip([trip, later], '2026-10-14'), trip);
      expect(nextTrip([trip, later], '2026-10-14'), later);
      expect(activeTrip([trip, later], '2026-10-20'), isNull);
      expect(overlaps([trip], '2026-10-16', '2026-10-18'), isTrue);
      expect(overlaps([trip], '2026-10-17', '2026-10-18'), isFalse);
      expect(overlaps([trip], '2026-10-01', '2026-10-09'), isFalse);
    });

    test('saved fields: dates and time zones only', () {
      expect(trip.toData(), {
        'start': '2026-10-10',
        'end': '2026-10-16',
        'tz': 'Europe/London',
        'home_tz': 'America/New_York',
      });
      expect(Trip.fromData(trip.toData()), trip);
    });
  });

  group('Time zones and jet lag', () {
    final zones = TimeZones();
    final at = DateTime.utc(2026, 1, 15);

    test('offsets from the bundled database', () {
      expect(
        zones.offset('Asia/Kolkata', at),
        const Duration(hours: 5, minutes: 30),
      );
      expect(zones.offset('America/New_York', at), const Duration(hours: -5));
      expect(zones.offset('Not/AZone', at), isNull);
      expect(zones.all, contains('Europe/London'));
      expect(TimeZones.label('America/Los_Angeles'), 'Los Angeles (America)');
    });

    test('direction: east, west or a small change', () {
      Duration h(num hours) => Duration(minutes: (hours * 60).round());
      expect(JetLag.direction(h(-5), h(5.5)), JetLagDirection.east);
      expect(JetLag.direction(h(5.5), h(-5)), JetLagDirection.west);
      expect(JetLag.direction(h(-5), h(-7)), JetLagDirection.small);
      expect(JetLag.direction(h(-5), h(-8)), JetLagDirection.west);
    });
  });

  group('Streak protected while travelling (FR-TRV-01)', () {
    final now = DateTime(2026, 10, 14, 9); // a Wednesday

    test('missed trip days never break it or use the rest day', () {
      // Done Mon 5 to Thu 8; Fri 9 to Tue 13 missed while away.
      final done = {'2026-10-05', '2026-10-06', '2026-10-07', '2026-10-08'};
      final without = streakFrom(done, now)!;
      expect(without.length, 0);
      final away = {
        '2026-10-09',
        '2026-10-10',
        '2026-10-11',
        '2026-10-12',
        '2026-10-13',
      };
      final s = streakFrom(done, now, protectedDates: away)!;
      expect(s.length, 4);
      expect(s.week, [
        StreakDay.travel,
        StreakDay.travel,
        StreakDay.today,
        StreakDay.upcoming,
        StreakDay.upcoming,
        StreakDay.upcoming,
        StreakDay.upcoming,
      ]);
    });

    test('a step done on a trip day still counts', () {
      final s = streakFrom(
        {'2026-10-12', '2026-10-13'},
        now,
        protectedDates: {'2026-10-12', '2026-10-13'},
      )!;
      expect(s.length, 2);
      expect(s.week.take(2), [StreakDay.done, StreakDay.done]);
    });

    test('the week\'s rest day is still there after the trip', () {
      // Away Mon 12; missed Tue 13 is the week's rest day, not a restart.
      final s = streakFrom(
        {'2026-10-11'},
        now,
        protectedDates: {'2026-10-12'},
      )!;
      expect(s.length, 1);
      expect(s.week[1], StreakDay.rest);
    });
  });

  group('Google Places adapter (FR-TRV-03)', () {
    const body = '''
{"places": [
  {"displayName": {"text": "Riverside Park", "languageCode": "en"},
   "formattedAddress": "1 River Rd", "googleMapsUri": "https://maps.google.com/?cid=1"},
  {"displayName": {"text": "  "}},
  {"displayName": {"text": "Green Grocer"}, "googleMapsUri": "javascript:alert(1)"}
]}''';

    test(
      'asks for parks near the location with the cheapest field mask',
      () async {
        late http.Request sent;
        final source = GooglePlacesSource(
          MockClient((r) async {
            sent = r;
            return http.Response(body, 200);
          }),
          'test-key',
        );
        final places = await source.search(
          PlaceCategory.park,
          const LatLng(51.5, -0.12),
        );
        expect(sent.url, GooglePlacesSource.endpoint);
        expect(sent.headers['X-Goog-Api-Key'], 'test-key');
        expect(sent.headers['X-Goog-FieldMask'], GooglePlacesSource.fieldMask);
        final json = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(json['includedTypes'], ['park']);
        expect(json['locationRestriction']['circle']['center'], {
          'latitude': 51.5,
          'longitude': -0.12,
        });
        expect(source.provider, 'Google Maps');
        // Blank names are dropped; only https links are kept.
        expect(
          [for (final p in places) p.name],
          ['Riverside Park', 'Green Grocer'],
        );
        expect(places.first.address, '1 River Rd');
        expect(
          places.first.mapsUri,
          Uri.parse('https://maps.google.com/?cid=1'),
        );
        expect(places.last.mapsUri, isNull);
      },
    );

    test('grocery and plant-forward types', () {
      expect(
        GooglePlacesSource.types[PlaceCategory.grocery],
        contains('grocery_store'),
      );
      expect(
        GooglePlacesSource.types[PlaceCategory.plantForward],
        containsAll(['vegetarian_restaurant', 'vegan_restaurant']),
      );
    });

    test('an error status throws; an empty answer is no places', () async {
      final failing = GooglePlacesSource(
        MockClient((_) async => http.Response('{"error": {}}', 403)),
        'k',
      );
      expect(
        () => failing.search(PlaceCategory.park, const LatLng(0, 0)),
        throwsA(isA<NearbySearchException>()),
      );
      expect(GooglePlacesSource.parse('{}'), isEmpty);
    });

    test('no key in the repo: the default build has no provider', () {
      expect(placesApiKey, isEmpty);
    });

    test('the maps-app fallback is a plain search, no key, no location', () {
      final uri = mapsSearchUri('parks near me');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query'], 'parks near me');
      expect(uri.queryParameters.keys, isNot(contains('key')));
    });
  });
}
