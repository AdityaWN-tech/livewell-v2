import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/domain/moment_builder.dart';
import 'package:livewell/features/moments/domain/moment_templates.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../checkin/checkin_flow_test.dart' show answerAll, barrier, uid;
import '../home/home_screen_test.dart' show previewLabel;
import '../support/app_harness.dart';
import '../support/fakes.dart';
import 'moment_home_test.dart' show heroFace;
import 'moment_reminders_test.dart' show playing, settle;
import 'moment_screen_test.dart' show face, finish;
import 'moment_scripts_test.dart' show builder, full, walk;

/// T-AVT-08f: the first hello, the check-in reaction, streak milestones,
/// and the coach staying calm after a safety response.

/// Signed in, past onboarding, the check-in not yet asked today.
Harness fresh({Flavor flavor = Flavor.dev}) {
  final h = Harness(
    flavor: flavor,
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
    checkInPrompt: FakeCheckInPromptStore(),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  return h;
}

/// The first-open check-in with [mood], and an ordinary (or [note]) answer
/// to "Anything that could make today hard?".
Future<void> checkIn(
  WidgetTester tester, {
  required int mood,
  int stress = 2,
  String note = 'Busy day',
}) async {
  expect(find.byType(CheckInSheet), findsOneWidget);
  await answerAll(tester, mood: mood, stress: stress);
  await barrier(tester, note);
  await settle(tester);
}

void main() {
  group('the scripts', () {
    MomentContext withCoach() => MomentContext(
      now: DateTime(2026, 10, 14, 9),
      firstName: 'Priya',
      coachName: 'Sam',
      why: 'Energy to travel with my family.',
      step: walk,
    );

    test('first hello: the names, the Why and one small step; waves, then '
        'smiles', () {
      final msg = builder().build(Moment.firstHello, withCoach())!;
      expect(msg.text, startsWith("Hi Priya, I'm Sam, your Live Well coach."));
      expect(msg.text, contains('one small step: 10-min walk after lunch'));
      expect(msg.emotion, CoachEmotion.waving);
      expect(msg.thenEmotion, CoachEmotion.happy);
      // Typed by the person: never in a cloned voice (FR-VOC-05).
      expect(msg.containsUserText, isTrue);
      expect(MomentPlaceholders.userText, contains('coach_name'));
    });

    test('first hello without any personal data still says hello', () {
      final msg = builder().build(
        Moment.firstHello,
        MomentContext(now: DateTime(2026, 10, 14, 9)),
      )!;
      expect(msg.text, contains("I'm your Live Well coach."));
      expect(msg.text, contains('one small step at a time'));
    });

    test('the check-in reaction fits the mood; never the answers', () {
      expect(
        MomentBuilder.afterCheckIn(gentleDay: false, mood: 5),
        Moment.checkInGood,
      );
      expect(
        MomentBuilder.afterCheckIn(gentleDay: false, mood: 4),
        Moment.checkInGood,
      );
      expect(
        MomentBuilder.afterCheckIn(gentleDay: false, mood: 3),
        Moment.checkInOkay,
      );
      expect(
        MomentBuilder.afterCheckIn(gentleDay: true, mood: 4),
        Moment.gentle,
      );
      final good = builder().build(Moment.checkInGood, full())!;
      // With the step known, the line that names it.
      expect(good.text, contains('Great to hear you feel good, Priya.'));
      expect(good.emotion, CoachEmotion.happy);
      final okay = builder().build(Moment.checkInOkay, full())!;
      expect(okay.text, contains('Thanks for checking in'));
    });

    test('streak milestones on 7, 14 and 30 days; Done otherwise', () {
      for (final days in [7, 14, 30]) {
        expect(
          MomentBuilder.afterDone(streakDays: days),
          Moment.streakMilestone,
        );
        final msg = builder().build(
          Moment.streakMilestone,
          MomentContext(now: DateTime(2026, 10, 14), streakDays: days),
        )!;
        expect(msg.text, contains('$days days in a row'));
        expect(msg.emotion, CoachEmotion.celebrating);
      }
      for (final days in [null, 1, 6, 8, 9, 13, 29, 31]) {
        expect(MomentBuilder.afterDone(streakDays: days), Moment.stepDone);
      }
    });

    test('nothing new is said on a safety hold', () {
      for (final m in [
        Moment.firstHello,
        Moment.checkInGood,
        Moment.checkInOkay,
        Moment.streakMilestone,
      ]) {
        final c = MomentContext(
          now: DateTime(2026, 10, 14, 9),
          firstName: 'Priya',
          streakDays: 7,
          safetyHold: true,
        );
        expect(builder().build(m, c), isNull, reason: '$m');
      }
    });
  });

  group('the first hello', () {
    Future<Harness> arrive(WidgetTester tester, {required bool due}) async {
      final h = Harness(flavor: Flavor.dev);
      h.firstHello.due = due;
      await h.boot(tester);
      await tester.scrollUntilVisible(find.text(previewLabel), 200);
      await tester.tap(find.text(previewLabel));
      await settle(tester);
      return h;
    }

    testWidgets('right after onboarding the coach says hello once: waving, '
        'then happy', (tester) async {
      final h = await arrive(tester, due: true);
      expect(playing(tester), Moment.firstHello);
      expect(h.firstHello.due, isFalse, reason: 'only once');
      final (msg, _) = h.speaker.spoken.single;
      expect(msg.messageId, startsWith('first_hello.'));
      await finish(tester, h);
      expect(face(tester), AvatarExpression.happy);
    });

    testWidgets('not again, and not for people who were already set up', (
      tester,
    ) async {
      await arrive(tester, due: false);
      expect(playing(tester), isNull);
    });
  });

  group('the coach reacts to the check-in', () {
    for (final (label, mood, stress, moment) in [
      ('a good mood', 5, 2, Moment.checkInGood),
      ('an okay mood', 3, 2, Moment.checkInOkay),
      ('a low mood: the gentle moment', 1, 2, Moment.gentle),
      ('high stress: the gentle moment', 4, 5, Moment.gentle),
    ]) {
      testWidgets(label, (tester) async {
        final h = fresh();
        await h.boot(tester);
        await checkIn(tester, mood: mood, stress: stress);
        expect(playing(tester), moment);
        expect(h.speaker.spoken.single.$1.moment, moment);
      });
    }

    testWidgets('after a safety response: no reaction, and the coach on '
        'Home is calm', (tester) async {
      final h = fresh();
      await h.boot(tester);
      await answerAll(tester, mood: 5);
      await barrier(tester, 'I have crushing chest pain');
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      await tapText(tester, 'Go back');
      expect(playing(tester), isNull);
      expect(h.speaker.spoken, isEmpty);
      expect(heroFace(AvatarExpression.calm), findsOneWidget);
    });

    testWidgets('prod before clinical review: no reaction', (tester) async {
      final h = fresh(flavor: Flavor.prod);
      await h.boot(tester);
      await checkIn(tester, mood: 5);
      expect(playing(tester), isNull);
    });
  });
}
