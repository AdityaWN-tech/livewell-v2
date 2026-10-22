import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/splash/application/splash_handoff.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/firebase/firebase_options.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart'
    show avatarIdleMotionProvider;

import 'support/frames.dart';

void main() {
  for (final flavor in Flavor.values) {
    testWidgets('${flavor.name} boots to Home and shows its banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flavorProvider.overrideWithValue(flavor),
            // The coach breathes forever; screens couldn't settle.
            avatarIdleMotionProvider.overrideWithValue(false),
            splashHandoffProvider.overrideWithValue(SplashHandoff.instant),
            appStartupProvider.overrideWith(
              (ref) async => StartDestination.home,
            ),
          ],
          child: const LiveWellApp(),
        ),
      );
      await pumpFrames(tester, const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      final banner = find.byWidgetPredicate(
        (w) => w is Banner && w.message == flavor.label,
      );
      expect(banner, flavor.label == null ? findsNothing : findsOneWidget);
      // Home never shows developer tools (AGENTS.md, Developer-only UI).
      expect(find.text('Design tokens'), findsNothing);
    });
  }

  test('only dev has a Firebase project yet', () {
    expect(Flavor.dev.firebaseProjectId, 'my-livewell');
    expect(Flavor.staging.firebaseProjectId, isNull);
    expect(Flavor.prod.firebaseProjectId, isNull);
  });

  test('Firebase options exist for dev only', () {
    expect(firebaseOptionsFor(Flavor.dev)?.projectId, 'my-livewell');
    expect(firebaseOptionsFor(Flavor.staging), isNull);
    expect(firebaseOptionsFor(Flavor.prod), isNull);
  });
}
