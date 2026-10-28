import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/components/illustrated.dart';
import 'package:livewell/core/design/components/lw_components.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart';
import 'package:livewell/features/learn/presentation/learn_search_screen.dart';
import 'package:livewell/features/notifications/presentation/notifications_screen.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';
import 'package:livewell/features/welcome/presentation/welcome_screen.dart';

import '../home/home_screen_test.dart' show bootPreview;
import '../support/app_harness.dart';
import '../support/fakes.dart';

/// T-UI-02i: the bell and search on Home, today's reminders, the Welcome
/// tour, Profile's single "Coming soon", titles that wrap, and the small
/// motions (none with reduced motion).

const uid = 'u1';

Harness signedIn() {
  final h = Harness(
    auth: FakeAuthService(
      signedIn: const AuthUser(
        uid: uid,
        email: 'a.very.long.email.address.for.testing@example-company.com',
      ),
    ),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  h.profiles.names[uid] = 'Priya Shah';
  h.profiles.whys[uid] = 'To play with my grandkids';
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// The page title is never cut off: no ellipsis, nothing over its lines.
void expectTitleWhole(WidgetTester tester, String title) {
  final p = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byType(LwPageTitle), matching: find.text(title)),
  );
  expect(p.didExceedMaxLines, isFalse, reason: title);
}

void main() {
  group('Home: search and the bell', () {
    testWidgets('search opens the lesson search', (tester) async {
      await signedIn().boot(tester);
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();
      expect(find.byType(LearnSearchScreen), findsOneWidget);
    });

    testWidgets('the bell opens today\'s reminders: times, on or off, quiet '
        'hours, and nothing personal', (tester) async {
      final h = signedIn();
      h.profiles.settings[uid] = {
        ProfileSettings.notificationCategories: {
          'greeting': true,
          'nudge': false,
          'reflection': true,
        },
      };
      await h.boot(tester);
      await tester.tap(find.byKey(const Key('home-bell')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Today’s reminders'), findsOneWidget);
      expect(find.text('7:00 AM'), findsOneWidget);
      expect(find.text('1:00 PM'), findsOneWidget);
      expect(find.text('8:30 PM'), findsOneWidget);
      String state(String k) =>
          tester.widget<Text>(find.byKey(Key('notification-$k-state'))).data!;
      expect(state('greeting'), 'On');
      expect(state('nudge'), 'Off');
      expect(state('reflection'), 'On');
      expect(find.text('Quiet hours: 10:00 PM to 7:00 AM'), findsOneWidget);
      // Generic names only (AGENTS.md: nothing personal in reminders).
      expect(find.textContaining('Priya'), findsNothing);
      expect(find.textContaining('grandkids'), findsNothing);
      await tester.tap(find.byKey(const Key('notifications-edit')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  group('Welcome tour', () {
    testWidgets('4 tips, arrows go round, each one read out', (tester) async {
      final handle = tester.ensureSemantics();
      await Harness().boot(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byKey(const Key('tour-step')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^One small step a day\. .* Tip 1 of 4\.$'),
        ),
        findsOneWidget,
      );
      for (final id in ['checkin', 'reminders', 'coach', 'step']) {
        await tester.tap(find.byKey(const Key('tour-next')));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('tour-$id')), findsOneWidget, reason: id);
      }
      await tester.tap(find.byKey(const Key('tour-prev')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tour-coach')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('swiping moves between tips', (tester) async {
      await Harness().boot(tester);
      await tester.fling(
        find.byKey(const Key('tour-step')),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tour-checkin')), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('iPhone SE, text $scale: scrolls, buttons reachable', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await Harness().boot(tester);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('I already have an account'),
          200,
        );
        expect(find.text('Get started'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Profile', () {
    testWidgets('the phone row says "Add a phone number" once (phone bug)', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await tester.tap(find.byKey(const Key('profile-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-link-phone')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final row = find.byKey(const Key('profile-link-phone'));
      expect(
        find.descendant(of: row, matching: find.text('Add a phone number')),
        findsOneWidget,
      );
      // Step 4c: it works now, so no "Coming soon".
      expect(
        find.descendant(of: row, matching: find.textContaining('oming soon')),
        findsNothing,
      );
    });
  });

  group('titles wrap instead of being cut off', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('iPhone SE, text $scale: Profile (email on one line) and '
          "today's reminders", (tester) async {
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await signedIn().boot(tester);
        Future<void> visit(String path, String title) async {
          final router = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          expect(router, isNotNull);
          await tester.pumpAndSettle();
          expectTitleWhole(tester, title);
          expect(tester.takeException(), isNull, reason: path);
        }

        await tester.tap(find.byKey(const Key('profile-button')));
        await tester.pumpAndSettle();
        await visit('/profile', 'Profile');
        // The email stays on one line with "..." (phone bug).
        final email = tester.renderObject<RenderParagraph>(
          find.byKey(const Key('profile-email')),
        );
        expect(email.maxLines, 1);
        expect(email.text.toPlainText(), contains('@example-company.com'));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('home-bell')));
        await tester.pumpAndSettle();
        expectTitleWhole(tester, 'Today’s reminders');
      });
    }
  });

  group('small motions', () {
    testWidgets('the coach bounces once and comes to rest', (tester) async {
      await bootPreview(tester);
      final motion = find.ancestor(
        of: find.byKey(const Key('coach-avatar-waving')),
        matching: find.byType(LwOnceMotion),
      );
      expect(motion, findsOneWidget);
      expect(
        find.descendant(
          of: motion,
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsOneWidget,
      );
      // pumpAndSettle returned: it never loops.
    });

    testWidgets('reduced motion: no animation at all', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await bootPreview(tester);
      final motion = find.ancestor(
        of: find.byKey(const Key('coach-avatar-waving')),
        matching: find.byType(LwOnceMotion),
      );
      expect(
        find.descendant(
          of: motion,
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsNothing,
      );
    });

    testWidgets('Done: the coach celebrates', (tester) async {
      await bootPreview(tester);
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step-done')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('coach-avatar-celebrating')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nice work! Today’s step is done.'), findsOneWidget);
      expect(
        tester
            .widget<CoachAvatar>(
              find.ancestor(
                of: find.byKey(const Key('coach-avatar-celebrating')),
                matching: find.byType(CoachAvatar),
              ),
            )
            .expression,
        AvatarExpression.celebrating,
      );
    });
  });
}
