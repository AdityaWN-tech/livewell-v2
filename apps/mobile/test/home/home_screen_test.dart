import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/home/domain/home_models.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';
const today = '2026-10-14';
const previewLabel = 'Preview the app (dev build only)';

/// Signed in and past onboarding; check-in already asked today.
Harness signedIn({
  Flavor flavor = Flavor.prod,
  FeatureFlags flags = const FeatureFlags(),
  String? name,
  DateTime? createdAt,
  String? why,
}) {
  final h = Harness(
    flavor: flavor,
    flags: flags,
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  if (name != null) h.profiles.names[uid] = name;
  if (createdAt != null) h.profiles.createdAts[uid] = createdAt;
  if (why != null) h.profiles.whys[uid] = why;
  return h;
}

/// Dev build, "Preview the app": the only place sample data appears.
Future<Harness> bootPreview(WidgetTester tester, {CheckIn? checkIn}) async {
  final h = Harness(flavor: Flavor.dev);
  if (checkIn != null) h.checkIns.days[today] = checkIn;
  await h.boot(tester);
  await tester.tap(find.text(previewLabel));
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  return h;
}

Finder inHome(Finder f) =>
    find.descendant(of: find.byType(HomeScreen), matching: f);

/// FR-DLY-03: at most 1 primary and 2 secondary actions on Home.
void expectActionLimit() {
  final primary = inHome(find.byType(FilledButton)).evaluate().length;
  final secondary =
      inHome(find.byType(TextButton)).evaluate().length +
      inHome(find.byType(OutlinedButton)).evaluate().length +
      inHome(find.byKey(const Key('home-checkin-card'))).evaluate().length;
  expect(primary, lessThanOrEqualTo(1), reason: 'primary actions');
  expect(secondary, lessThanOrEqualTo(2), reason: 'secondary actions');
}

void main() {
  group('dayNumber', () {
    test('day 1 on the day the account was made, counted by calendar day', () {
      final created = DateTime(2026, 10, 6, 23, 50);
      expect(dayNumber(created, DateTime(2026, 10, 6, 23, 59)), 1);
      expect(dayNumber(created, DateTime(2026, 10, 7, 0, 5)), 2);
      expect(dayNumber(created, DateTime(2026, 10, 14, 8, 30)), 9);
    });

    test('a daylight-saving change does not skip or repeat a day', () {
      // US clocks go back on 2026-11-01.
      expect(dayNumber(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 3);
    });
  });

  group('real account (prod): only real data', () {
    testWidgets('empty state: greeting, before-check-in step, check-in row', (
      tester,
    ) async {
      await signedIn(name: 'Robert Hall').boot(tester);
      expect(find.text('LIVE WELL'), findsOneWidget);
      expect(find.text('Hi, Robert'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);
      expect(
        find.text(
          'Check in first. Then a small step picked for you will appear here.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-checkin-card')), findsOneWidget);
      expect(
        find.text(
          'Your progress will show here once you start your first habit.',
        ),
        findsOneWidget,
      );
      // No plan yet: no Done / Make it smaller, and no sample data.
      expect(find.byKey(const Key('step-done')), findsNothing);
      expect(find.byKey(const Key('step-smaller')), findsNothing);
      expect(find.textContaining('Priya'), findsNothing);
      expect(find.textContaining('walk after lunch'), findsNothing);
      expect(find.byKey(const Key('home-day')), findsNothing);
      expectActionLimit();
    });

    testWidgets('no name: a friendly greeting without one', (tester) async {
      await signedIn().boot(tester);
      expect(find.text('Hi there'), findsOneWidget);
    });

    testWidgets('Day N comes from when the account was created', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await signedIn(createdAt: DateTime(2026, 10, 6, 9)).boot(tester);
      expect(find.text('Day 9'), findsOneWidget);
      expect(find.bySemanticsLabel('Day 9 of your journey'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the Why is shown in a compact card', (tester) async {
      await signedIn(why: 'To play with my grandkids').boot(tester);
      expect(find.text('YOUR WHY'), findsOneWidget);
      expect(find.text('To play with my grandkids'), findsOneWidget);
    });

    testWidgets('checked in today: the row becomes a summary', (tester) async {
      final h = signedIn();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 4,
        timeAvailable: 10,
        gentleDay: false,
      );
      await h.boot(tester);
      expect(find.byKey(const Key('home-checkin-card')), findsNothing);
      expect(find.byKey(const Key('home-checkin-summary')), findsOneWidget);
      expect(find.text('Checked in today · Mood: Good'), findsOneWidget);
      expect(
        find.text('A step that fits in 10 minutes will appear here.'),
        findsOneWidget,
      );
      expectActionLimit();
    });

    testWidgets('gentle day without a plan: the gentle placeholder', (
      tester,
    ) async {
      final h = signedIn();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 1,
        gentleDay: true,
      );
      await h.boot(tester);
      expect(
        find.text(
          'A small, gentle step will appear here. Go easy on yourself today.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the quick check-in row opens the check-in', (tester) async {
      await signedIn().boot(tester);
      await tester.tap(find.byKey(const Key('home-checkin-card')));
      await tester.pumpAndSettle();
      expect(find.text('Hi, how are you feeling today?'), findsOneWidget);
    });

    testWidgets('briefing is hidden while its flag is off', (tester) async {
      await signedIn().boot(tester);
      expect(find.byKey(const Key('home-briefing')), findsNothing);
    });

    testWidgets('briefing flag on: a "coming soon" button, not playable', (
      tester,
    ) async {
      await signedIn(flags: const FeatureFlags(briefings: true)).boot(tester);
      final button = find.byKey(const Key('home-briefing'));
      expect(button, findsOneWidget);
      expect(find.text('Briefing coming soon'), findsOneWidget);
      final widget = tester.widget<ButtonStyleButton>(button);
      expect(widget.onPressed, isNull);
    });
  });

  group('dev preview: sample data', () {
    testWidgets('shows the full design with sample data', (tester) async {
      final handle = tester.ensureSemantics();
      await bootPreview(tester);
      expect(find.text('Day 9'), findsOneWidget);
      expect(find.text('Hi, Priya'), findsOneWidget);
      expect(find.text('10-min walk after lunch'), findsOneWidget);
      expect(find.text('Driver 3 · Movement'), findsOneWidget);
      expect(find.byKey(const Key('step-done')), findsOneWidget);
      expect(find.text('Make it 5 min'), findsOneWidget);
      expect(find.text('Phase 1 of 3'), findsOneWidget);
      expect(find.text('7 / 9 habits kept'), findsOneWidget);
      expect(find.bySemanticsLabel('7 of 9 habits kept'), findsOneWidget);
      expectActionLimit();
      handle.dispose();
    });

    testWidgets('"Make it 5 min" swaps in the smaller step', (tester) async {
      await bootPreview(tester);
      await tester.tap(find.byKey(const Key('step-smaller')));
      await tester.pumpAndSettle();
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      expect(find.byKey(const Key('step-smaller')), findsNothing);
    });

    testWidgets('Done shows a kind confirmation', (tester) async {
      await bootPreview(tester);
      await tester.tap(find.byKey(const Key('step-done')));
      await tester.pumpAndSettle();
      expect(find.text('Done for today. Nice work.'), findsOneWidget);
      expect(find.byKey(const Key('step-done')), findsNothing);
    });

    testWidgets('gentle day: smaller step, gentle message, no "make smaller"', (
      tester,
    ) async {
      await bootPreview(
        tester,
        checkIn: const CheckIn(date: today, mood: 1, gentleDay: true),
      );
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      expect(find.text('A gentle day. Go easy on yourself.'), findsOneWidget);
      expect(find.byKey(const Key('step-smaller')), findsNothing);
      expectActionLimit();
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets(
        'labels, tap targets and contrast (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final handle = tester.ensureSemantics();
          await bootPreview(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(
            find.bySemanticsLabel('Quick check-in. Takes about 30 seconds.'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Make it a 5-minute step'),
            findsOneWidget,
          );
          handle.dispose();
        },
      );
    }

    for (final dark in [false, true]) {
      testWidgets(
        'status bar icons are readable (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await signedIn().boot(tester);
          final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
                )
                .first,
          );
          expect(
            region.value.statusBarIconBrightness,
            dark ? Brightness.light : Brightness.dark,
          );
        },
      );
    }

    testWidgets('quick check-in row has one clear label', (tester) async {
      final handle = tester.ensureSemantics();
      await signedIn().boot(tester);
      expect(
        find.bySemanticsLabel('Quick check-in. Takes about 30 seconds.'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
