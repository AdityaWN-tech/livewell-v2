import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';
const today = '2026-10-14';

/// Signed in, past onboarding, not yet asked today.
Harness fresh({String? region, String? name}) {
  final h = Harness(
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
    checkInPrompt: FakeCheckInPromptStore(),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  if (region != null) h.profiles.regions[uid] = region;
  return h;
}

Finder option(int step, int value) =>
    find.byKey(Key('checkin-option-$step-$value'));

Future<void> pick(WidgetTester tester, int step, int value) async {
  await tester.tap(option(step, value));
  await tester.pumpAndSettle();
}

/// Mood, energy, sleep, stress, time; ends on the "make today hard" step.
Future<void> answerAll(
  WidgetTester tester, {
  int mood = 4,
  int energy = 3,
  int sleep = 4,
  int stress = 2,
  int minutes = 10,
}) async {
  await pick(tester, 0, mood);
  await pick(tester, 1, energy);
  await pick(tester, 2, sleep);
  await pick(tester, 3, stress);
  await pick(tester, 4, minutes);
}

Future<void> barrier(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('checkin-barrier')), text);
  await tester.pump();
  await tapText(tester, 'Done');
}

void main() {
  testWidgets('first open of the day asks mood first, before anything else', (
    tester,
  ) async {
    final h = fresh();
    await h.boot(tester);
    expect(find.byType(CheckInSheet), findsOneWidget);
    expect(find.text('Hi, how are you feeling today?'), findsOneWidget);
    for (final label in ['Very low', 'Low', 'Okay', 'Good', 'Great']) {
      expect(find.text(label), findsOneWidget, reason: 'faces have text');
    }
    expect(find.text('Skip for now'), findsNothing, reason: 'mood required');
    expect(h.checkInPrompt.lastAsked, today);
  });

  testWidgets('greets by first name when known', (tester) async {
    final h = fresh();
    h.profiles.existing.remove(uid);
    h.profiles.created[uid] = const NewProfile(
      displayName: 'Priya Sharma',
      onboardingStep: ProfileStep.assessment,
    );
    await h.boot(tester);
    expect(find.text('Hi Priya, how are you feeling today?'), findsOneWidget);
  });

  testWidgets('full check-in: every step, saved once, Home updated', (
    tester,
  ) async {
    final h = fresh();
    await h.boot(tester);
    await pick(tester, 0, 4);
    expect(find.text('How is your energy?'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await pick(tester, 1, 3);
    expect(find.text('How did you sleep last night?'), findsOneWidget);
    await pick(tester, 2, 4);
    expect(find.text('How stressed do you feel?'), findsOneWidget);
    await pick(tester, 3, 2);
    expect(find.text('How much time do you have today?'), findsOneWidget);
    await pick(tester, 4, 10);
    expect(find.text('Anything that could make today hard?'), findsOneWidget);
    await barrier(tester, 'Long meeting day');

    expect(find.byType(CheckInSheet), findsNothing);
    final saved = h.checkIns.days[today]!;
    expect(
      [
        saved.mood,
        saved.energy,
        saved.sleep,
        saved.stress,
        saved.timeAvailable,
      ],
      [4, 3, 4, 2, 10],
    );
    expect(saved.barrierText, 'Long meeting day');
    expect(saved.gentleDay, isFalse);
    expect(h.checkIns.saves, 1);

    expect(
      find.text("Love that energy. Let's use it well today."),
      findsOneWidget,
    );
    expect(
      find.text('A step that fits in 10 minutes will appear here.'),
      findsOneWidget,
    );
    expect(find.text('Your day starts here'), findsNothing);
  });

  testWidgets(
    '"Skip question" skips one; "Skip for now" saves what was answered',
    (tester) async {
      final h = fresh();
      await h.boot(tester);
      await pick(tester, 0, 3);
      await tapText(tester, 'Skip question'); // energy
      await pick(tester, 2, 4); // sleep
      await tapText(tester, 'Skip for now');
      final saved = h.checkIns.days[today]!;
      expect(saved.mood, 3);
      expect(saved.energy, isNull);
      expect(saved.sleep, 4);
      expect(saved.stress, isNull);
      expect(saved.timeAvailable, isNull);
      expect(
        find.text('A small step picked for you will appear here.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'closing the sheet: not asked again today, a Check in card instead',
    (tester) async {
      final h = fresh();
      await h.boot(tester);
      await tester.tapAt(const Offset(20, 20)); // tap outside the sheet
      await tester.pumpAndSettle();
      expect(find.byType(CheckInSheet), findsNothing);
      expect(find.byKey(const Key('home-checkin-card')), findsOneWidget);
      expect(h.checkIns.days, isEmpty);

      // Reopen the app the same day: not asked again.
      await h.boot(tester);
      expect(find.byType(CheckInSheet), findsNothing);

      // The card still opens it on demand.
      await tester.tap(find.byKey(const Key('home-checkin-card')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckInSheet), findsOneWidget);
    },
  );

  testWidgets('a new day asks again', (tester) async {
    final h = fresh()..checkInPrompt.lastAsked = '2026-10-13';
    await h.boot(tester);
    expect(find.byType(CheckInSheet), findsOneWidget);
  });

  testWidgets('already checked in today: not asked, result shown', (
    tester,
  ) async {
    final h = fresh();
    h.checkIns.days[today] = const CheckIn(
      date: today,
      mood: 3,
      gentleDay: false,
    );
    await h.boot(tester);
    expect(find.byType(CheckInSheet), findsNothing);
    expect(
      find.text('Thanks for checking in. One small step is plenty today.'),
      findsOneWidget,
    );
  });

  group('Home after check-in, by mood', () {
    for (final (mood, line) in [
      (1, "Thanks for telling me. Let's keep today gentle."),
      (3, 'Thanks for checking in. One small step is plenty today.'),
      (5, "Love that energy. Let's use it well today."),
    ]) {
      testWidgets('mood $mood', (tester) async {
        final h = fresh();
        await h.boot(tester);
        await pick(tester, 0, mood);
        await tapText(tester, 'Skip for now');
        expect(find.text(line), findsOneWidget);
        expect(h.checkIns.days[today]!.gentleDay, mood <= 2);
      });
    }

    testWidgets('high stress makes a gentle day even with a great mood', (
      tester,
    ) async {
      final h = fresh();
      await h.boot(tester);
      await answerAll(tester, mood: 5, stress: 4);
      await tapText(tester, 'Done');
      expect(h.checkIns.days[today]!.gentleDay, isTrue);
      expect(
        find.text("Thanks for telling me. Let's keep today gentle."),
        findsOneWidget,
      );
      expect(
        find.text(
          'A small, gentle step will appear here. Go easy on yourself today.',
        ),
        findsOneWidget,
      );
    });
  });

  group('safety in "Anything that could make today hard?"', () {
    for (final (text, region, card, number) in [
      (
        "I don't want to be alive anymore",
        'US',
        "You don't have to face this alone",
        'Call 988 Suicide & Crisis Lifeline: 988',
      ),
      (
        'Main marna chahta hoon',
        'IN',
        "You don't have to face this alone",
        'Call Tele-MANAS: 14416',
      ),
      (
        'khudkushi ke baare mein soch raha hoon',
        'IN',
        "You don't have to face this alone",
        'Call Tele-MANAS: 14416',
      ),
      (
        'I have crushing chest pain',
        'IN',
        'This could be an emergency',
        'Call 112',
      ),
      ('I can\'t breathe', 'US', 'This could be an emergency', 'Call 911'),
    ]) {
      testWidgets('"$text" ($region)', (tester) async {
        final h = fresh(region: region);
        await h.boot(tester);
        await answerAll(tester, mood: 4);
        await barrier(tester, text);

        expect(find.byType(SafetyInterruptScreen), findsOneWidget);
        expect(find.text(card), findsOneWidget);
        await tapText(tester, number);
        expect(h.phone.calls, isNotEmpty);

        await tapText(tester, 'Go back');
        final saved = h.checkIns.days[today]!;
        expect(saved.barrierText, isNull, reason: 'red-flag text not kept');
        expect(saved.gentleDay, isTrue, reason: 'no portal card today');
        expect(saved.mood, 4);
      });
    }

    testWidgets('medication: a note, then Continue keeps the text', (
      tester,
    ) async {
      final h = fresh();
      await h.boot(tester);
      await answerAll(tester);
      await barrier(tester, 'Should I stop my metformin?');
      expect(find.byType(SafetyNoticeSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SafetyNoticeSheet),
          matching: find.text('Continue'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        h.checkIns.days[today]!.barrierText,
        'Should I stop my metformin?',
      );
    });

    testWidgets('an ordinary note saves with no safety screen', (tester) async {
      final h = fresh();
      await h.boot(tester);
      await answerAll(tester);
      await barrier(tester, 'Back-to-back meetings');
      expect(find.byType(SafetyInterruptScreen), findsNothing);
      expect(find.byType(SafetyNoticeSheet), findsNothing);
    });
  });

  testWidgets(
    'voice note asks for the microphone consent, then fills the box',
    (tester) async {
      final h = fresh();
      await h.boot(tester);
      await answerAll(tester);
      await tapText(tester, 'Speak instead');
      await tapText(tester, 'Allow');
      expect(h.consents.records.single.type, ConsentType.microphone);
      h.dictation.say('School pickup and a long drive');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('checkin-barrier')),
      );
      expect(field.controller!.text, 'School pickup and a long drive');
    },
  );

  testWidgets('analytics: only checkin_completed with counts and duration', (
    tester,
  ) async {
    final h = fresh();
    await h.boot(tester);
    await answerAll(tester, mood: 1);
    await barrier(tester, 'Feeling low');
    expect(h.analytics.events, hasLength(1));
    final e = h.analytics.events.single;
    expect(e.keys.toSet(), {'name', 'surface', 'duration_s', 'steps_answered'});
    expect(e['name'], 'checkin_completed');
    expect(e['surface'], 'app');
    expect(e['steps_answered'], 6);
  });

  testWidgets('no analytics when the check-in is closed unanswered', (
    tester,
  ) async {
    final h = fresh();
    await h.boot(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(h.analytics.events, isEmpty);
  });

  group('accessibility (NFR-06)', () {
    testWidgets(
      'every answer is at least 48 dp and has a screen-reader label',
      (tester) async {
        final h = fresh();
        await h.boot(tester);
        for (var step = 0; step < 5; step++) {
          final values = step == 4 ? timeOptions : [1, 2, 3, 4, 5];
          for (final v in values) {
            final size = tester.getSize(option(step, v));
            expect(size.height, greaterThanOrEqualTo(48));
            expect(size.width, greaterThanOrEqualTo(48));
          }
          await pick(tester, step, values.first);
        }
      },
    );

    testWidgets('time options read as minutes to screen readers', (
      tester,
    ) async {
      final h = fresh();
      await h.boot(tester);
      for (var step = 0; step < 4; step++) {
        await pick(tester, step, 3);
      }
      expect(find.bySemanticsLabel('10 minutes'), findsOneWidget);
    });

    testWidgets('large text (200%): every step renders without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = fresh();
      await h.boot(tester);
      for (var step = 0; step < 5; step++) {
        expect(tester.takeException(), isNull, reason: 'step $step');
        await pick(tester, step, step == 4 ? 5 : 3);
      }
      expect(find.byKey(const Key('checkin-barrier')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode: the sheet uses the dark theme', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final h = fresh();
      await h.boot(tester);
      final context = tester.element(find.byType(CheckInSheet));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(find.text('Great'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
