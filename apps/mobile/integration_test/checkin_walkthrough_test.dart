import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';

/// Walkthrough of the daily check-in on a real device (T-DLY-02 evidence):
/// the dev app in preview mode (nothing saved), answered at a relaxed,
/// human-like pace. Prints CHECKIN_SECONDS for the 30-second target.
/// Clear the app's data first so the check-in hasn't been asked today:
///   adb shell pm clear net.conciergeconnectedcare.livewell.dev
///   flutter test integration_test/checkin_walkthrough_test.dart --flavor dev -d DEVICE
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('daily check-in, start to Home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
        child: const LiveWellApp(),
      ),
    );

    Future<void> waitFor(Finder f, {int seconds = 30}) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (f.evaluate().isNotEmpty) return;
      }
      fail('timed out waiting for $f');
    }

    // A person's pace between taps.
    Future<void> pause() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tap(Finder f) async {
      await tester.tap(f);
      await pause();
    }

    final preview = find.text('Preview the app (dev build only)');
    await waitFor(preview);
    // ignore: avoid_print
    print('WALKTHROUGH_START');
    await pause();
    await tap(preview);

    await waitFor(find.byType(CheckInSheet));
    final watch = Stopwatch()..start();
    await pause();
    await tap(find.byKey(const Key('checkin-option-0-4'))); // mood: Good
    await tap(find.byKey(const Key('checkin-option-1-3'))); // energy: Okay
    await tap(find.byKey(const Key('checkin-option-2-4'))); // sleep: Well
    await tap(find.byKey(const Key('checkin-option-3-2'))); // stress: A little
    await tap(find.byKey(const Key('checkin-option-4-10'))); // 10 minutes
    await tester.enterText(
      find.byKey(const Key('checkin-barrier')),
      'Long meeting day',
    );
    await pause();
    await tap(find.text('Done'));
    await waitFor(find.byKey(const Key('checkin-response')));
    watch.stop();

    final seconds = watch.elapsedMilliseconds / 1000;
    // ignore: avoid_print
    print('CHECKIN_SECONDS ${seconds.toStringAsFixed(1)}');
    expect(seconds, lessThan(30));
    expect(
      find.text("Love that energy. Let's use it well today."),
      findsOneWidget,
    );
    await pause();
    await pause();
  });
}
