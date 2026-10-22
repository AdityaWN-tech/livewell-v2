import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';
import 'package:livewell/features/starter_plan/presentation/plan_preview_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';
const today = '2026-10-14';

/// Dev build (pending templates allowed), signed in, at the plan step.
Harness atPlan({
  List<String> focus = const ['move_more'],
  bool? limited,
  CheckIn? checkIn,
  Flavor flavor = Flavor.dev,
}) {
  final h = Harness(
    flavor: flavor,
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
  );
  h.profiles.existing[uid] = ProfileStep.plan;
  h.profiles.focus[uid] = (choices: focus, driver: 'x', limited: limited);
  if (checkIn != null) h.checkIns.days[today] = checkIn;
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('7 day cards, 3 touchpoint times, supporting habits', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await atPlan(
      checkIn: const CheckIn(
        date: today,
        mood: 4,
        timeAvailable: 10,
        gentleDay: false,
      ),
    ).boot(tester);
    expect(find.byType(PlanPreviewScreen), findsOneWidget);
    expect(find.text('Your 7 days'), findsOneWidget);
    expect(find.text('Walk for 10 minutes after lunch'), findsOneWidget);
    expect(
      find.text('Short on time? Walk for 5 minutes after lunch'),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel('Morning greeting at 7:00 AM. Tap to change.'),
      findsOneWidget,
    );
    expect(find.text('Also this week'), findsOneWidget);
    for (var d = 1; d <= 7; d++) {
      await tester.scrollUntilVisible(
        find.byKey(Key('plan-day-$d')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    handle.dispose();
  });

  testWidgets('Start, allow reminders: consent, schedule, Home shows step', (
    tester,
  ) async {
    final h = atPlan();
    await h.boot(tester);
    await tapKey(tester, 'plan-start');
    expect(find.text('Get gentle reminders?'), findsOneWidget);
    await tapText(tester, 'Allow reminders');
    final consent = h.consents.records.single;
    expect(consent.type, ConsentType.notifications);
    expect(consent.granted, isTrue);
    expect(h.reminders.permissionAsks, 1);
    expect(h.plans.days, hasLength(7));
    expect(h.reminders.scheduled, isNotEmpty);
    // Lock-screen safe: generic texts only.
    expect(h.reminders.texts!.nudgeBody, 'Your coach has a message for you.');
    expect(h.profiles.existing[uid], ProfileStep.assessment);
    expect(find.byType(HomeScreen), findsOneWidget);
    // Home's step now comes from the plan (5 min: the check-in was skipped).
    expect(find.text('Walk for 5 minutes after lunch'), findsOneWidget);
    expect(find.text('After lunch'), findsOneWidget);
  });

  testWidgets('"Not now": the plan still starts, nothing is scheduled', (
    tester,
  ) async {
    final h = atPlan();
    await h.boot(tester);
    await tapKey(tester, 'plan-start');
    await tapText(tester, 'Not now');
    expect(h.consents.records.single.granted, isFalse);
    expect(h.reminders.permissionAsks, 0);
    expect(h.plans.days, hasLength(7));
    expect(h.reminders.scheduled, isEmpty);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('reminders asked once: an earlier answer is kept', (
    tester,
  ) async {
    final h = atPlan();
    await h.consents.record(ConsentType.notifications, granted: true);
    await h.boot(tester);
    await tapKey(tester, 'plan-start');
    expect(find.text('Get gentle reminders?'), findsNothing);
    expect(h.reminders.scheduled, isNotEmpty);
  });

  testWidgets('a time in quiet hours is refused; another is saved', (
    tester,
  ) async {
    final h = atPlan();
    await h.boot(tester);
    await tapKey(tester, 'plan-time-reflection');
    // Switch the picker to text input and type 23:00.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), '00');
    await tapText(tester, 'PM');
    await tapText(tester, 'OK');
    expect(find.textContaining('during quiet hours'), findsOneWidget);

    await tapKey(tester, 'plan-time-reflection');
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '9');
    await tester.enterText(find.byType(TextField).at(1), '15');
    await tapText(tester, 'PM');
    await tapText(tester, 'OK');
    await tapKey(tester, 'plan-start');
    await tapText(tester, 'Not now');
    expect(h.plans.times.evening, const ClockTime(21, 15));
  });

  testWidgets('gentle day: day 1 is a 2-minute step', (tester) async {
    final h = atPlan(
      checkIn: const CheckIn(
        date: today,
        mood: 1,
        timeAvailable: 30,
        gentleDay: true,
      ),
    );
    await h.boot(tester);
    expect(find.text('Walk for 2 minutes after lunch'), findsOneWidget);
    expect(find.text('A gentle start today.'), findsOneWidget);
  });

  testWidgets('activity limited: no walking anywhere in the plan', (
    tester,
  ) async {
    final h = atPlan(limited: true);
    await h.boot(tester);
    await tapKey(tester, 'plan-start');
    await tapText(tester, 'Not now');
    for (final d in h.plans.days.values) {
      expect(d.title.toLowerCase(), isNot(contains('walk')), reason: d.date);
      expect(d.title.toLowerCase(), isNot(contains('stretch')), reason: d.date);
    }
  });

  testWidgets('prod build: pending templates are not used', (tester) async {
    final h = atPlan(flavor: Flavor.prod);
    await h.boot(tester);
    expect(find.byKey(const Key('plan-not-ready')), findsOneWidget);
    expect(find.byKey(const Key('plan-start')), findsNothing);
    await tapText(tester, 'Continue');
    expect(h.plans.days, isEmpty);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('save error says so and stays', (tester) async {
    final h = atPlan();
    h.plans.fail = true;
    await h.boot(tester);
    await tapKey(tester, 'plan-start');
    await tapText(tester, 'Not now');
    expect(
      find.text('We couldn’t save your plan. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(PlanPreviewScreen), findsOneWidget);
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets('plan preview (${dark ? 'dark' : 'light'})', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await atPlan().boot(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
