import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/travel/data/device_location.dart';
import 'package:livewell/features/travel/domain/places.dart';
import 'package:livewell/features/travel/domain/trip.dart';
import 'package:livewell/features/travel/presentation/travel_screen.dart';

import '../home/home_screen_test.dart' show signedIn, today;
import '../plan/plan_screen_test.dart' show openPlan, scrollTo, withStarterPlan;
import '../support/travel_fakes.dart';

/// A trip from today for a week, New York to London (5 hours ahead).
const londonTrip = Trip(
  start: today,
  end: '2026-10-20',
  timeZone: 'Europe/London',
  homeTimeZone: 'America/New_York',
);

const hotelRoutine = 'Do the 10-minute hotel-room routine';

Future<void> openTravel(WidgetTester tester) async {
  await openPlan(tester);
  await scrollTo(tester, find.byKey(const Key('plan-travel')));
  await tester.tap(find.byKey(const Key('plan-travel')));
  await tester.pumpAndSettle();
  expect(find.byType(TravelScreen), findsOneWidget);
}

Finder inTravel(Finder f) =>
    find.descendant(of: find.byType(TravelScreen), matching: f);

Future<void> scrollToKey(
  WidgetTester tester,
  String key, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    delta,
    scrollable: inTravel(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FR-TRV-01: Travel Mode toggle with trip dates and time zone', () {
    testWidgets('Plan opens Travel Mode; dates and zone start a trip', (
      tester,
    ) async {
      final h = signedIn(flavor: Flavor.dev);
      h.reminders.zone = 'America/New_York';
      await h.boot(tester);
      await openTravel(tester);

      // One primary action, off until dates are chosen.
      expect(inTravel(find.byType(FilledButton)), findsOneWidget);
      final start = find.byKey(const Key('travel-start'));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);

      // Time zone: this phone's by default; pick London from the search.
      expect(find.text('New York (America)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('travel-zone')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('travel-zone-search')),
        'london',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('travel-zone-Europe/London')));
      await tester.pumpAndSettle();
      expect(find.text('London (Europe)'), findsOneWidget);

      // Dates: the 14th to the 16th (the picker opens on a later month).
      await tester.tap(find.byKey(const Key('travel-dates')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('14').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('16').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

      await tester.tap(start);
      await tester.pumpAndSettle();
      final saved = h.trips.trips.single;
      expect(saved.start, endsWith('-14'));
      expect(saved.end, endsWith('-16'));
      expect(saved.lengthDays, 3);
      expect(saved.timeZone, 'Europe/London');
      expect(saved.homeTimeZone, 'America/New_York');
      expect(find.text('Travel Mode is set. Safe travels!'), findsOneWidget);
      if (saved.start == today) {
        expect(find.byKey(const Key('travel-on')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('travel-next')), findsOneWidget);
      }
      // Ahead in time: the east jet-lag tip.
      expect(find.byKey(const Key('travel-jet-lag')), findsOneWidget);
      expect(find.text("You're travelling ahead in time"), findsOneWidget);
    });

    testWidgets('the plan switches to travel microhabits (dev content)', (
      tester,
    ) async {
      final h = signedIn(flavor: Flavor.dev);
      await h.trips.save(londonTrip);
      await h.boot(tester);
      // Home's step is the travel microhabit for the trip's first day.
      await tester.scrollUntilVisible(find.text(hotelRoutine).first, 200);
      expect(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.text(hotelRoutine),
        ),
        findsWidgets,
      );
      await openPlan(tester);
      await scrollTo(tester, find.text(hotelRoutine));
      expect(find.text(hotelRoutine), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('plan-travel')));
      expect(find.text('On until Oct 20'), findsOneWidget);
    });

    testWidgets('End Travel Mode keeps the days so far protected', (
      tester,
    ) async {
      final h = signedIn(flavor: Flavor.dev);
      await h.trips.save(
        const Trip(
          start: '2026-10-11',
          end: '2026-10-20',
          timeZone: 'Europe/London',
          homeTimeZone: 'America/New_York',
        ),
      );
      await h.boot(tester);
      await openTravel(tester);
      await tester.tap(find.byKey(const Key('travel-end')));
      await tester.pumpAndSettle();
      expect(h.trips.trips.single.end, '2026-10-13');
      expect(find.text('Travel Mode is off. Welcome back!'), findsOneWidget);
      expect(find.byKey(const Key('travel-form')), findsOneWidget);
    });

    testWidgets('a planned trip can be cancelled', (tester) async {
      final h = signedIn(flavor: Flavor.dev);
      await h.trips.save(
        const Trip(
          start: '2026-11-01',
          end: '2026-11-05',
          timeZone: 'Asia/Kolkata',
          homeTimeZone: 'America/New_York',
        ),
      );
      await h.boot(tester);
      await openTravel(tester);
      expect(find.byKey(const Key('travel-next')), findsOneWidget);
      await tester.tap(find.byKey(const Key('travel-cancel')));
      await tester.pumpAndSettle();
      expect(h.trips.trips, isEmpty);
    });
  });

  group('FR-TRV-02: travel pillars', () {
    testWidgets('four pillars with hotel-room routines and jet-lag tips', (
      tester,
    ) async {
      final h = signedIn(flavor: Flavor.dev);
      await h.boot(tester);
      await openTravel(tester);
      for (final id in [
        'eat_well',
        'move_well',
        'sleep_recover',
        'breathe_reset',
      ]) {
        await scrollToKey(tester, 'travel-pillar-$id');
        expect(find.byKey(Key('travel-pillar-$id')), findsOneWidget);
      }
      await scrollToKey(tester, 'travel-item-move_hotel_room', delta: -200);
      await tester.tap(find.byKey(const Key('travel-item-move_hotel_room')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('travel-item-sheet-move_hotel_room')),
        findsOneWidget,
      );
      // Not limited: no clinician note.
      expect(find.byKey(const Key('travel-item-clinician')), findsNothing);
    });

    testWidgets('prod waits for clinical approval: no pending content, and '
        "the plan's own step stays", (tester) async {
      final h = withStarterPlan();
      await h.trips.save(londonTrip);
      await h.boot(tester);
      await tester.scrollUntilVisible(
        find.text('10-min walk after lunch').first,
        200,
      );
      expect(find.text(hotelRoutine), findsNothing);
      await openTravel(tester);
      expect(find.byKey(const Key('travel-content-pending')), findsOneWidget);
      expect(find.byKey(const Key('travel-pillar-eat_well')), findsNothing);
      // The trip itself still works (streak protection, routine shrink).
      expect(find.byKey(const Key('travel-on')), findsOneWidget);
    });
  });

  group('FR-TRV-03: nearby places, labelled, with location permission', () {
    testWidgets('no maps provider in this build: a labelled maps-app search, '
        'no location asked', (tester) async {
      final h = signedIn(flavor: Flavor.dev);
      await h.boot(tester);
      await openTravel(tester);
      await scrollToKey(tester, 'travel-maps-search');
      expect(find.byKey(const Key('travel-nearby-find')), findsNothing);
      expect(
        find.text(
          "Opens your maps app. Results come from the map provider and aren't "
          'endorsed by Live Well.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('travel-category-grocery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('travel-maps-search')));
      await tester.pumpAndSettle();
      expect(
        h.mapsOpened.single.queryParameters['query'],
        'grocery stores near me',
      );
      expect(h.location.asked, 0);
    });

    testWidgets('listings show their source and "not endorsed"', (
      tester,
    ) async {
      final source = FakePlacesSource(
        places: [
          Place(
            name: 'Riverside Park',
            address: '1 River Rd',
            mapsUri: Uri.parse('https://maps.example/riverside'),
          ),
          const Place(name: 'Hill Garden'),
        ],
      );
      final h = signedIn(flavor: Flavor.dev)..places = source;
      await h.boot(tester);
      await openTravel(tester);
      await scrollToKey(tester, 'travel-nearby-find');
      expect(find.byKey(const Key('travel-maps-search')), findsNothing);
      await tester.tap(find.byKey(const Key('travel-nearby-find')));
      await tester.pumpAndSettle();
      expect(h.location.asked, 1);
      expect(source.searches, [PlaceCategory.park]);
      await scrollToKey(tester, 'travel-listings');
      expect(
        find.text(
          'Map-provider listings from Fake Maps, not endorsed by Live Well. '
          'Not medical or dietary advice.',
        ),
        findsOneWidget,
      );
      // Every listing carries its source tag.
      expect(find.text('Fake Maps listing'), findsNWidgets(2));
      expect(find.text('Riverside Park'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Riverside Park, Fake Maps listing, not endorsed by Live Well. '
          'Opens it in maps.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Riverside Park'));
      await tester.pumpAndSettle();
      expect(h.mapsOpened, [Uri.parse('https://maps.example/riverside')]);
    });

    testWidgets('location denied: no search, a calm note', (tester) async {
      final source = FakePlacesSource();
      final h = signedIn(flavor: Flavor.dev)..places = source;
      h.location.outcome = const LocationDenied(permanently: false);
      await h.boot(tester);
      await openTravel(tester);
      await scrollToKey(tester, 'travel-nearby-find');
      await tester.tap(find.byKey(const Key('travel-nearby-find')));
      await tester.pumpAndSettle();
      await scrollToKey(tester, 'travel-nearby-denied');
      expect(source.searches, isEmpty);
      expect(find.byKey(const Key('travel-listings')), findsNothing);
    });

    testWidgets('denied for good: offers Settings', (tester) async {
      final h = signedIn(flavor: Flavor.dev)..places = FakePlacesSource();
      h.location.outcome = const LocationDenied(permanently: true);
      await h.boot(tester);
      await openTravel(tester);
      await scrollToKey(tester, 'travel-nearby-find');
      await tester.tap(find.byKey(const Key('travel-nearby-find')));
      await tester.pumpAndSettle();
      await scrollToKey(tester, 'travel-nearby-denied-forever');
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('provider down: a calm note, nothing else', (tester) async {
      final h = signedIn(flavor: Flavor.dev)
        ..places = FakePlacesSource(fail: true);
      await h.boot(tester);
      await openTravel(tester);
      await scrollToKey(tester, 'travel-nearby-find');
      await tester.tap(find.byKey(const Key('travel-nearby-find')));
      await tester.pumpAndSettle();
      await scrollToKey(tester, 'travel-nearby-failed');
      expect(find.byKey(const Key('travel-listings')), findsNothing);
    });
  });
}
