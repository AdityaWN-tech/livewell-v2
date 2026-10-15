import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/focus/presentation/activity_check_screen.dart';
import 'package:livewell/features/focus/presentation/focus_screen.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/safety/presentation/help_now_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';
const today = '2026-10-14';

Harness at(String step) {
  final h = Harness(
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
    // Not asked yet today.
    checkInPrompt: FakeCheckInPromptStore(),
  );
  h.profiles.existing[uid] = step;
  return h;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('focus to driver map', () {
    final content = File('../../content/plan/focus_to_driver.json');
    final asset = File('assets/plan/focus_to_driver.json');

    test('the app copy matches content/plan', () {
      expect(asset.readAsStringSync(), content.readAsStringSync());
    });

    test('every choice has a driver; marked pending clinical review', () {
      final raw = jsonDecode(content.readAsStringSync()) as Map;
      expect(raw['review_status'], 'pending');
      final map = FocusMap.parse(content.readAsStringSync());
      for (final f in FocusArea.values) {
        expect(map.driverOf(f), isNotEmpty);
      }
      expect(map.needsActivityCheck([FocusArea.moveMore]), isTrue);
      expect(map.needsActivityCheck([FocusArea.sleepBetter]), isFalse);
      expect(
        map.needsActivityCheck([FocusArea.sleepBetter, FocusArea.moreEnergy]),
        isTrue,
      );
    });

    test('steps resume at the right screen (FR-ONB-06)', () {
      expect(routeForProfileStep(ProfileStep.checkin), checkinPath);
      expect(routeForProfileStep(ProfileStep.focus), focusPath);
    });
  });

  group('first check-in', () {
    testWidgets('opens the mood-first check-in; saving it moves to focus', (
      tester,
    ) async {
      final h = at(ProfileStep.checkin);
      await h.boot(tester);
      expect(find.byType(CheckInSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin-option-0-4')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Skip for now');
      expect(h.checkIns.days[today]!.mood, 4);
      expect(h.checkInPrompt.lastAsked, today, reason: 'Home won\'t re-ask');
      expect(h.profiles.existing[uid], ProfileStep.focus);
      expect(find.byType(FocusScreen), findsOneWidget);
    });

    testWidgets('can be skipped without checking in', (tester) async {
      final h = at(ProfileStep.checkin);
      await h.boot(tester);
      await tester.tapAt(const Offset(20, 20)); // close the sheet
      await tester.pumpAndSettle();
      expect(h.checkIns.days, isEmpty);
      expect(find.byType(FocusScreen), findsOneWidget);
    });

    testWidgets('already checked in today: straight on to focus', (
      tester,
    ) async {
      final h = at(ProfileStep.checkin);
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 3,
        gentleDay: false,
      );
      await h.boot(tester);
      expect(find.byType(CheckInSheet), findsNothing);
      expect(find.byType(FocusScreen), findsOneWidget);
    });
  });

  group('what would you like to work on', () {
    testWidgets('pick one (no movement): saved, no activity check, Home', (
      tester,
    ) async {
      final h = at(ProfileStep.focus);
      await h.boot(tester);
      expect(find.text('What would you like to work on this week?'), findsOne);
      final cont = tester.widget<FilledButton>(
        find.byKey(const Key('focus-continue')),
      );
      expect(cont.onPressed, isNull, reason: 'pick at least one');
      await tapKey(tester, 'focus-sleep_better');
      await tapKey(tester, 'focus-continue');
      expect(find.byType(ActivityCheckScreen), findsNothing);
      final saved = h.profiles.focus[uid]!;
      expect(saved.choices, ['sleep_better']);
      expect(saved.driver, 'sleep');
      expect(saved.limited, isNull, reason: 'not asked');
      expect(h.profiles.existing[uid], ProfileStep.assessment);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('two at most, in the order picked; tap again to remove', (
      tester,
    ) async {
      final h = at(ProfileStep.focus);
      final handle = tester.ensureSemantics();
      await h.boot(tester);
      await tapKey(tester, 'focus-less_stress');
      await tapKey(tester, 'focus-eat_better');
      expect(
        find.bySemanticsLabel('Feel less stressed, first choice'),
        findsOne,
      );
      expect(find.bySemanticsLabel('Eat better, second choice'), findsOne);
      await tapKey(tester, 'focus-sleep_better');
      expect(
        find.text('You’ve picked two. Tap one to remove it first.'),
        findsOneWidget,
      );
      await tapKey(tester, 'focus-less_stress');
      await tapKey(tester, 'focus-sleep_better');
      await tapKey(tester, 'focus-continue');
      expect(h.profiles.focus[uid]!.choices, ['eat_better', 'sleep_better']);
      expect(h.profiles.focus[uid]!.driver, 'nutrition');
      handle.dispose();
    });

    testWidgets('movement + "No": saved as not limited', (tester) async {
      final h = at(ProfileStep.focus);
      await h.boot(tester);
      await tapKey(tester, 'focus-move_more');
      await tapKey(tester, 'focus-continue');
      expect(find.byType(ActivityCheckScreen), findsOneWidget);
      expect(
        find.text(
          'Do you have chest pain, fainting or severe breathlessness, or has '
          'a doctor or nurse told you to limit your activity?',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'activity-no');
      final saved = h.profiles.focus[uid]!;
      expect(saved.driver, 'movement');
      expect(saved.limited, isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('movement + "Yes": clinician guidance, help now, no exercise', (
      tester,
    ) async {
      final h = at(ProfileStep.focus);
      await h.boot(tester);
      await tapKey(tester, 'focus-more_energy');
      await tapKey(tester, 'focus-continue');
      await tapKey(tester, 'activity-yes');
      expect(find.byType(ActivityLimitedScreen), findsOneWidget);
      expect(find.text('Talk to your clinician first'), findsOneWidget);
      await tapKey(tester, 'activity-help-now');
      expect(find.byType(HelpNowScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'activity-continue');
      expect(h.profiles.focus[uid]!.limited, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('back from the activity check: nothing saved, still here', (
      tester,
    ) async {
      final h = at(ProfileStep.focus);
      await h.boot(tester);
      await tapKey(tester, 'focus-healthy_routine');
      await tapKey(tester, 'focus-continue');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(FocusScreen), findsOneWidget);
      expect(h.profiles.focus, isEmpty);
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets('focus and activity check (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await at(ProfileStep.focus).boot(tester);
        await tapKey(tester, 'focus-move_more');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tapKey(tester, 'focus-continue');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}

/// Shorter spelling for single matches.
final findsOne = findsOneWidget;
