@Tags(['walkthrough'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'new_user_journey_test.dart' as journey;

/// Saves a frame after every step of the new-user journey, for the T-ONB-03
/// walkthrough video (docs/evidence/onb-03-journey.mp4). Not part of the
/// normal run; make the frames and the video with:
///   flutter test --update-goldens --run-skipped --tags walkthrough test/journey
///   (then tool/make_journey_video.py)
void main() {
  testWidgets('journey frames', (tester) async {
    var n = 0;
    journey.journeyOnStep = (tester, step) async {
      n++;
      // Let images (logos) finish decoding before the frame.
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('frames/${n.toString().padLeft(3, '0')}_$step.png'),
      );
    };
    addTearDown(() => journey.journeyOnStep = null);
    final h = await journey.runJourney(tester);
    await journey.tapKey(tester, 'profile-button');
    await journey.tapKey(tester, 'profile-theme');
    await journey.tapLabel(tester, 'Dark');
    await journey.tapKey(tester, 'profile-logout');
    await journey.tapKey(tester, 'confirm-action');
    expect(h.auth.signedIn, isNull);
  });
}
