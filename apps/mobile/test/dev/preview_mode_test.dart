import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/startup/app_startup.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/splash/application/splash_handoff.dart';

import '../support/frames.dart';

Future<void> bootToWelcome(WidgetTester tester, Flavor flavor) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        flavorProvider.overrideWithValue(flavor),
        splashHandoffProvider.overrideWithValue(SplashHandoff.instant),
        appStartupProvider.overrideWith(
          (ref) async => StartDestination.welcome,
        ),
      ],
      child: const LiveWellApp(),
    ),
  );
  await pumpFrames(tester, const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  const label = 'Preview the app (dev build only)';

  testWidgets('dev build: preview skips sign-in and opens the tabs', (
    tester,
  ) async {
    await bootToWelcome(tester, Flavor.dev);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  for (final flavor in [Flavor.staging, Flavor.prod]) {
    testWidgets('${flavor.name} build has no preview button', (tester) async {
      await bootToWelcome(tester, flavor);
      expect(find.text(label), findsNothing);
    });
  }
}
