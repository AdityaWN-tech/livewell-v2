import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/avatar/domain/characters.dart';
import 'package:livewell/features/studio/presentation/studio_screen.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/auth/presentation/sign_in_screen.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/profile/data/appearance.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';
import 'package:livewell/features/welcome/presentation/welcome_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../starter_plan/starter_plan_test.dart' show plan;

const uid = 'u1';

Harness signedIn({
  Flavor flavor = Flavor.prod,
  List<String> providers = const ['password'],
}) {
  final h = Harness(
    flavor: flavor,
    auth: FakeAuthService(
      signedIn: AuthUser(
        uid: uid,
        email: 'priya@example.com',
        providers: providers,
      ),
    ),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  h.profiles.names[uid] = 'Priya Shah';
  return h;
}

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profile-button')));
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirm-action')));
  await tester.pumpAndSettle();
}

void main() {
  group('placement (Option A)', () {
    testWidgets('the profile picture is at the top-right of every tab', (
      tester,
    ) async {
      await signedIn().boot(tester);
      for (final tab in ['Home', 'Plan', 'Track', 'Learn', 'Care']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('profile-button')), findsOneWidget);
        expect(find.byTooltip('Settings'), findsNothing, reason: tab);
      }
      // Still the 5 spec tabs, no 6th.
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(5),
      );
    });

    testWidgets('header: initial, name, email, sign-in methods', (
      tester,
    ) async {
      await signedIn(providers: ['password', 'google.com']).boot(tester);
      await openProfile(tester);
      expect(find.text('Priya'), findsWidgets);
      expect(find.text('priya@example.com'), findsOneWidget);
      expect(find.byKey(const Key('method-password')), findsOneWidget);
      expect(find.byKey(const Key('method-google.com')), findsOneWidget);
      expect(find.byKey(const Key('method-apple.com')), findsNothing);
    });
  });

  group('account', () {
    testWidgets('change and remove the profile picture', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-photo');
      await tapText(tester, 'Choose from gallery');
      expect(h.photo.path, isNotNull);
      await tapKey(tester, 'profile-photo');
      await tapText(tester, 'Remove picture');
      expect(h.photo.path, isNull);
    });

    testWidgets('edit name', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-edit-name');
      await tester.enterText(find.byKey(const Key('profile-text')), 'Pri');
      await tapText(tester, 'Save');
      expect(h.profiles.settings[uid]!['display_name'], 'Pri');
    });

    testWidgets('link Google, then unlink it; the last method stays', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-link-google');
      expect(h.auth.signedIn!.providers, contains('google.com'));
      await tapKey(tester, 'profile-link-google');
      expect(h.auth.signedIn!.providers, ['password']);
      // Removing the only method is refused.
      h.auth.signedIn = const AuthUser(uid: uid, providers: ['apple.com']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openProfile(tester);
      await tapKey(tester, 'profile-link-apple');
      expect(
        find.text(
          'This is your only way to sign in, so it can\u2019t be removed.',
        ),
        findsOneWidget,
      );
      expect(h.auth.signedIn!.providers, ['apple.com']);
    });

    for (final key in ['profile-logout', 'profile-switch']) {
      testWidgets('$key: clears this phone and stops reminders, then sign-in', (
        tester,
      ) async {
        final h = signedIn();
        h.photo.path = 'C:/fake/profile.jpg';
        h.reminders.scheduled = [
          ScheduledTouchpoint(
            id: 1,
            when: DateTime(2026, 10, 15, 7),
            kind: TouchpointKind.greeting,
          ),
        ];
        await h.boot(tester);
        await openProfile(tester);
        await tapKey(tester, key);
        await confirm(tester);
        expect(h.auth.signedIn, isNull);
        expect(h.reminders.scheduled, isEmpty);
        expect(h.reminders.cancels, 1);
        expect(h.photo.path, isNull);
        expect(h.localData.clears, 1);
        expect(h.localData.pending, isTrue, reason: 'cache cleared next start');
        expect(find.byType(SignInScreen), findsOneWidget);
      });
    }
  });

  group('my coach', () {
    testWidgets('coach name: letters only, saved, shown on Home', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-coach-name');
      await tester.enterText(find.byKey(const Key('profile-text')), '1234');
      await tapText(tester, 'Save');
      expect(find.text('Use 1 to 20 letters.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('profile-text')), 'Maya');
      await tapText(tester, 'Save');
      expect(h.profiles.settings[uid]!['coach_name'], 'Maya');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
    });

    testWidgets('change avatar and voice open their screens and save', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      // Both open the Avatar & Voice Studio, on their own tab (T-UI-02h).
      await tapKey(tester, 'profile-avatar');
      expect(find.byType(StudioScreen), findsOneWidget);
      await tapKey(tester, 'avatar-character-curly');
      await tapKey(tester, 'studio-save-avatar');
      // The character, on the background already chosen (its own tab).
      expect(CoachCharacters.indexOf(h.avatars.saved!), 3);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'profile-voice');
      await tapKey(tester, 'voice-lw-deep');
      await tapKey(tester, 'studio-save-voice');
      expect(h.voices.chosen!.voiceId, 'lw-deep');
    });
  });

  group('appearance', () {
    testWidgets('dark theme applies at once and persists after restart', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-theme');
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(h.appearance.saved.theme, ThemeMode.dark);
      expect(h.profiles.settings[uid]!['appearance'], {
        'theme': 'dark',
        'text_scale': 1.0,
      });
      // Restart: the phone copy is read before anything else.
      await h.boot(tester);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });

    testWidgets('text size scales the whole app', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-text-size');
      await tester.tap(find.text('Largest'));
      await tester.pumpAndSettle();
      expect(h.appearance.saved.textScale, 1.3);
      final ctx = tester.element(find.byType(ProfileScreen));
      expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(13, 0.01));
    });

    test('appearance map round-trips; bad values fall back', () {
      const a = Appearance(theme: ThemeMode.light, textScale: 1.15);
      expect(Appearance.fromMap(a.toMap()).theme, ThemeMode.light);
      expect(Appearance.fromMap(a.toMap()).textScale, 1.15);
      expect(Appearance.fromMap({'text_scale': 9}).textScale, 1.0);
    });
  });

  group('daily plan settings', () {
    testWidgets('turning off a reminder reschedules without it', (
      tester,
    ) async {
      final h = signedIn();
      await h.consents.record(ConsentType.notifications, granted: true);
      await h.plans.save(plan(), const TouchpointTimes());
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-touchpoint-nudge');
      expect(h.profiles.settings[uid]!['notification_categories'], {
        'greeting': true,
        'nudge': false,
        'reflection': true,
      });
      expect(
        h.reminders.scheduled.where((s) => s.kind == TouchpointKind.nudge),
        isEmpty,
      );
      expect(h.reminders.scheduled, isNotEmpty);
    });
  });

  group('privacy & data (FR-SET-02/03)', () {
    for (final (key, call) in [
      ('profile-delete-avatar', 'avatar'),
      ('profile-delete-voice', 'voice'),
    ]) {
      testWidgets('$key: confirm, then the server deletes it', (tester) async {
        final h = signedIn();
        await h.boot(tester);
        await openProfile(tester);
        await tapKey(tester, key);
        await tapText(tester, 'Cancel');
        expect(h.deletions.calls, isEmpty, reason: 'needs confirmation');
        await tapKey(tester, key);
        await tester.tap(find.byKey(const Key('confirm-action')));
        await tester.pumpAndSettle();
        expect(h.deletions.calls, [call]);
        expect(find.text('Deleted.'), findsOneWidget);
      });
    }

    testWidgets('delete account: confirm, server deletes, phone cleared', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-delete-account');
      expect(find.textContaining('can\u2019t be undone'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(h.deletions.calls, ['account']);
      expect(h.auth.signedIn, isNull);
      expect(h.localData.clears, 1);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('server not reachable: says so, nothing else happens', (
      tester,
    ) async {
      final h = signedIn();
      h.deletions.fail = true;
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-delete-account');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'We couldn\u2019t delete that right now. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(h.auth.signedIn, isNotNull);
      expect(h.localData.clears, 0);
    });

    testWidgets('export and memory say "Coming soon"', (tester) async {
      await signedIn().boot(tester);
      await openProfile(tester);
      for (final k in ['profile-export', 'profile-memory']) {
        await tester.scrollUntilVisible(
          find.byKey(Key(k)),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.widget<ListTile>(find.byKey(Key(k))).enabled, isFalse);
      }
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets('profile (${dark ? 'dark' : 'light'})', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await signedIn().boot(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await openProfile(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });
}
