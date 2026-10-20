import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/journey/new_user_journey_test.dart' as journey;

/// The T-ONB-03 end-to-end journey on a real device or emulator, slowed
/// down so it can be screen-recorded (T-ONB-03g). Uses the same fakes as
/// the widget test: nothing touches Firebase.
///
///   adb shell screenrecord /sdcard/journey.mp4   (in another terminal)
///   flutter test integration_test/new_user_journey_test.dart
///       --flavor dev -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  journey.journeyPause = const Duration(milliseconds: 900);

  testWidgets('new user: fresh install to Home, Profile, dark, log out', (
    tester,
  ) async {
    final h = await journey.runJourney(tester);
    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();
    await journey.pauseForViewer();
    await journey.tapKey(tester, 'profile-theme');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await journey.pauseForViewer();
    await journey.tapKey(tester, 'profile-logout');
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    await journey.pauseForViewer();
    expect(h.auth.signedIn, isNull);
  });
}
