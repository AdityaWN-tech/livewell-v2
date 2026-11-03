import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/core/time/clock.dart';
import 'package:livewell/features/care/presentation/care_screen.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/learn/presentation/learn_screen.dart';
import 'package:livewell/features/plan/presentation/plan_screen.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';
import 'package:livewell/features/splash/application/splash_handoff.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';

import '../support/frames.dart';

Future<void> bootToShell(
  WidgetTester tester, {
  Flavor flavor = Flavor.prod,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        flavorProvider.overrideWithValue(flavor),
        splashHandoffProvider.overrideWithValue(SplashHandoff.instant),
        appStartupProvider.overrideWith((ref) async => StartDestination.home),
        // A fixed morning, so the time-of-day greeting never changes the
        // golden images.
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 14, 8, 30)),
      ],
      child: const LiveWellApp(),
    ),
  );
  await pumpFrames(tester, const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shell has exactly the 5 spec tabs in order (14.2)', (
    tester,
  ) async {
    await bootToShell(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.map((d) => (d as NavigationDestination).label), [
      'Home',
      'Plan',
      'Track',
      'Learn',
      'Care',
    ]);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('every tab screen is reachable', (tester) async {
    await bootToShell(tester);
    final screens = {
      'Plan': PlanScreen,
      'Track': TrackScreen,
      'Learn': LearnScreen,
      'Care': CareScreen,
      'Home': HomeScreen,
    };
    for (final MapEntry(key: label, value: type) in screens.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(type), findsOneWidget, reason: '$label tab');
    }
  });

  testWidgets('tab targets meet the 48 dp minimum (NFR-06)', (tester) async {
    await bootToShell(tester);
    final tabs = find.byType(NavigationDestination);
    expect(tabs, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      final size = tester.getSize(tabs.at(i));
      expect(size.height, greaterThanOrEqualTo(48), reason: 'tab $i height');
      expect(size.width, greaterThanOrEqualTo(48), reason: 'tab $i width');
    }
  });

  testWidgets('Profile opens from every tab', (tester) async {
    await bootToShell(tester);
    for (final label in ['Home', 'Plan', 'Track', 'Learn', 'Care']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget, reason: label);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
