@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/travel/domain/places.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../support/travel_fakes.dart';
import 'travel_screen_test.dart' show londonTrip, openTravel, scrollToKey;

/// Travel Mode (T-TRV-01) golden images: planning a trip, and a trip on
/// with nearby listings (labelled), light and dark. Regenerate after an
/// intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  const size = Size(1080, 2400);
  const dpr = 2.625;
  for (final (state, dark) in [('start', false), ('on', false), ('on', true)]) {
    final name = 'travel_${state}_${dark ? 'dark' : 'light'}';
    testWidgets(name, (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final h = signedIn(flavor: Flavor.dev);
      h.reminders.zone = 'America/New_York';
      if (state == 'on') {
        await h.trips.save(londonTrip);
        h.places = FakePlacesSource(
          places: [
            Place(
              name: 'Riverside Park',
              address: '1 River Road',
              mapsUri: Uri.parse('https://maps.example/1'),
            ),
            Place(
              name: 'Hill Garden',
              address: '20 Hill Street',
              mapsUri: Uri.parse('https://maps.example/2'),
            ),
          ],
        );
      }
      await h.boot(tester);
      await openTravel(tester);
      if (state == 'on') {
        await scrollToKey(tester, 'travel-nearby-find');
        await tester.tap(find.byKey(const Key('travel-nearby-find')));
        await tester.pumpAndSettle();
        await scrollToKey(tester, 'travel-pillar-eat_well', delta: -400);
      }
      // Tall enough that the whole screen is in the image.
      tester.view
        ..physicalSize = Size(size.width, size.height * 2.6)
        ..devicePixelRatio = dpr;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}
