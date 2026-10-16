import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/routing/router.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/dev/application/preview_mode.dart';
import 'package:livewell/features/dev/presentation/design_gallery.dart';
import 'package:livewell/features/dev/presentation/illustration_gallery.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

/// T-FND-04 follow-up: developer tools only in the dev flavour, never on
/// Home, never routable in staging/prod (AGENTS.md, Developer-only UI).

/// Signed in with a finished profile, so the app opens on Home.
Harness signedIn(Flavor flavor) {
  final h = Harness(
    flavor: flavor,
    auth: FakeAuthService(signedIn: const AuthUser(uid: 'u1')),
  );
  h.profiles.existing['u1'] = ProfileStep.assessment;
  return h;
}

/// Profile (T-ONB-03f) is the settings home; scrolls to its end so the
/// lazily built Developer section, if any, exists.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profile'));
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);
  await tester.scrollUntilVisible(
    find.byKey(const Key('profile-help-now')),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.fling(find.byType(ListView).first, const Offset(0, -3000), 3000);
  await tester.pumpAndSettle();
}

void main() {
  for (final flavor in Flavor.values) {
    testWidgets('Home has no "Design tokens" button (${flavor.name})', (
      tester,
    ) async {
      await signedIn(flavor).boot(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Design tokens'), findsNothing);
    });
  }

  testWidgets('dev: Profile > Developer has Design tokens, and it opens', (
    tester,
  ) async {
    await signedIn(Flavor.dev).boot(tester);
    await openSettings(tester);
    expect(find.text('Developer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dev-design-tokens')));
    await tester.pumpAndSettle();
    expect(find.byType(DesignGallery), findsOneWidget);
  });

  testWidgets('dev: Profile > Developer has Illustrations, and it opens', (
    tester,
  ) async {
    await signedIn(Flavor.dev).boot(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const Key('dev-illustrations')));
    await tester.pumpAndSettle();
    expect(find.byType(IllustrationGallery), findsOneWidget);
  });

  for (final flavor in [Flavor.staging, Flavor.prod]) {
    testWidgets('${flavor.name}: Profile has no Developer section', (
      tester,
    ) async {
      await signedIn(flavor).boot(tester);
      await openSettings(tester);
      expect(find.text('Developer'), findsNothing);
      expect(find.text('Design tokens'), findsNothing);
      expect(find.byKey(const Key('dev-illustrations')), findsNothing);
    });

    test('${flavor.name}: the illustrations route is not registered', () {
      final container = ProviderContainer(
        overrides: [flavorProvider.overrideWithValue(flavor)],
      );
      addTearDown(container.dispose);
      final match = container
          .read(routerProvider)
          .configuration
          .findMatch(Uri.parse(IllustrationGallery.path));
      expect(match.matches, isEmpty);
    });

    test('${flavor.name}: the design-tokens route is not registered', () {
      final container = ProviderContainer(
        overrides: [flavorProvider.overrideWithValue(flavor)],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      final match = router.configuration.findMatch(Uri.parse('/dev/tokens'));
      expect(match.matches, isEmpty);
    });

    testWidgets('${flavor.name}: a deep link to /dev/tokens does not open it', (
      tester,
    ) async {
      await signedIn(flavor).boot(tester);
      GoRouter.of(tester.element(find.byType(HomeScreen))).go('/dev/tokens');
      await tester.pumpAndSettle();
      expect(find.byType(DesignGallery), findsNothing);
    });

    test('${flavor.name}: preview mode cannot be switched on', () {
      final container = ProviderContainer(
        overrides: [flavorProvider.overrideWithValue(flavor)],
      );
      addTearDown(container.dispose);
      container.read(previewModeProvider.notifier).enable();
      expect(container.read(previewModeProvider), isFalse);
    });
  }

  test('dev: the design-tokens route is registered', () {
    final container = ProviderContainer(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
    );
    addTearDown(container.dispose);
    final match = container
        .read(routerProvider)
        .configuration
        .findMatch(Uri.parse('/dev/tokens'));
    expect(match.matches, isNotEmpty);
  });
}
