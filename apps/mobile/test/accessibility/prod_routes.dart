import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/routing/router.dart';
import 'package:livewell/features/account/application/account_setup.dart'
    show avatarPath, checkinPath, focusPath, planPath, voicePath, whyPath;
import 'package:livewell/features/dev/application/preview_samples.dart';
import 'package:livewell/features/notifications/presentation/notifications_screen.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../support/app_harness.dart';

/// T-REL-01: every route registered in the prod flavour, and how to reach
/// it. The router test below fails if a prod route is added without being
/// listed here, so the accessibility sweep can't silently miss a screen.
class AuditRoute {
  const AuditRoute(this.path, {this.signedIn = true, this.label});
  final String path;
  final bool signedIn;
  final String? label;
  String get name => label ?? path;
}

final learnItemId = PreviewSamples.lessons.first.id;

final prodRoutes = <AuditRoute>[
  const AuditRoute('/welcome', signedIn: false),
  const AuditRoute('/onboarding/about', signedIn: false),
  const AuditRoute('/onboarding/age', signedIn: false),
  const AuditRoute('/onboarding/under-18', signedIn: false),
  const AuditRoute('/onboarding/legal', signedIn: false),
  const AuditRoute(
    '/onboarding/legal/terms',
    signedIn: false,
    label: '/onboarding/legal/:doc',
  ),
  const AuditRoute('/sign-in', signedIn: false),
  const AuditRoute('/sign-in/phone', signedIn: false),
  const AuditRoute('/sign-in/email', signedIn: false),
  const AuditRoute(avatarPath),
  const AuditRoute(voicePath),
  const AuditRoute(whyPath),
  const AuditRoute(checkinPath),
  const AuditRoute(focusPath),
  const AuditRoute(planPath),
  const AuditRoute('/home'),
  const AuditRoute('/plan'),
  const AuditRoute('/plan/framework'),
  const AuditRoute('/plan/routine'),
  const AuditRoute('/track'),
  const AuditRoute('/track/weekly'),
  const AuditRoute('/learn'),
  const AuditRoute('/learn/library'),
  const AuditRoute('/learn/search'),
  AuditRoute('/learn/item/$learnItemId', label: '/learn/item/:id'),
  const AuditRoute('/learn/breathe'),
  const AuditRoute('/care'),
  const AuditRoute('/moment/morning', label: '/moment/:name'),
  const AuditRoute(NotificationsScreen.path),
  const AuditRoute('/help'),
  const AuditRoute('/profile'),
  const AuditRoute('/profile/phone'),
  // Moment times, quiet hours, playback and the widget (T-DLY-03e, D-79).
  const AuditRoute('/profile/daily-plan'),
  const AuditRoute('/settings'),
  const AuditRoute('/settings/consents'),
];

/// Boots the prod app (signed in or out) and opens [route].
Future<Harness> openRoute(WidgetTester tester, AuditRoute route) async {
  final h = route.signedIn ? signedIn(name: 'Robert Hall') : Harness();
  // Real-looking content so lists and cards are on screen.
  h.learn.lessons = PreviewSamples.lessons;
  // Help now needs a known region (never guessed, D-03).
  h.profiles.regions['u1'] = 'US';
  await h.boot(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LiveWellApp)),
  );
  container.read(routerProvider).push(route.path);
  await tester.pumpAndSettle();
  return h;
}
