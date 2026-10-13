import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/splash/application/splash_handoff.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/splash/domain/splash_timing.dart';
import 'package:livewell/features/splash/presentation/splash_screen.dart';
import 'package:livewell/features/welcome/presentation/welcome_screen.dart';

import '../support/frames.dart';

Widget app(Future<StartDestination> Function() startup) => ProviderScope(
  overrides: [
    flavorProvider.overrideWithValue(Flavor.prod),
    splashHandoffProvider.overrideWithValue(SplashHandoff.instant),
    appStartupProvider.overrideWith((ref) => startup()),
  ],
  child: const LiveWellApp(),
);

double wordmarkOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.image(const AssetImage('assets/brand/wordmark.png')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  group('SplashTiming (D-13, NFR-01)', () {
    const t = SplashTiming.normal;

    test('signed-in users reach Home in 1.2 s or less', () {
      expect(
        t.total(StartDestination.home),
        lessThanOrEqualTo(const Duration(milliseconds: 1200)),
      );
    });

    test('new users see about 2 s (1.5 to 2.5 s) before Welcome', () {
      final total = t.total(StartDestination.welcome);
      expect(total, greaterThanOrEqualTo(const Duration(milliseconds: 1500)));
      expect(total, lessThanOrEqualTo(const Duration(milliseconds: 2500)));
    });

    test('reduce-motion has no reveal animation, only holds and a fade', () {
      expect(SplashTiming.reducedMotion.reveal, Duration.zero);
      expect(
        SplashTiming.of(reduceMotion: true),
        same(SplashTiming.reducedMotion),
      );
    });
  });

  testWidgets(
    'first frame matches the native splash: mark only, words hidden',
    (tester) async {
      await tester.pumpWidget(app(() async => StartDestination.home));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(wordmarkOpacity(tester), 0);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0B3A4E));
    },
  );

  testWidgets('signed-in user goes to Home after reveal + hold', (
    tester,
  ) async {
    const t = SplashTiming.normal;
    await tester.pumpWidget(app(() async => StartDestination.home));
    await pumpFrames(
      tester,
      t.reveal + t.holdHome - const Duration(milliseconds: 50),
    );
    expect(find.byType(HomeScreen), findsNothing);
    await pumpFrames(tester, const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('new user goes to Welcome after the longer hold', (tester) async {
    const t = SplashTiming.normal;
    await tester.pumpWidget(app(() async => StartDestination.welcome));
    await pumpFrames(
      tester,
      t.reveal + t.holdHome + const Duration(milliseconds: 100),
    );
    expect(find.byType(WelcomeScreen), findsNothing);
    await pumpFrames(tester, t.holdWelcome);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('waits for slow startup instead of guessing', (tester) async {
    final startup = Completer<StartDestination>();
    await tester.pumpWidget(app(() => startup.future));
    await pumpFrames(tester, const Duration(seconds: 3));
    expect(find.byType(SplashScreen), findsOneWidget);
    startup.complete(StartDestination.home);
    await tester.pump();
    await pumpFrames(tester, SplashTiming.normal.holdHome);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('startup failure shows a calm retry, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(app(() async => throw StateError('offline')));
    await pumpFrames(tester, const Duration(seconds: 2));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('reduce-motion: still logo from the first frame, then a fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app(() async => StartDestination.home));
    await tester.pump();
    expect(wordmarkOpacity(tester), 1);
    await pumpFrames(tester, SplashTiming.reducedMotion.holdHome);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
