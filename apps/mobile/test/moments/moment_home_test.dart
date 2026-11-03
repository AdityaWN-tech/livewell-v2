import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/home/application/home_data.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/application/coach_state.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/presentation/celebration.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn, today;
import '../support/app_harness.dart';
import 'moment_reminders_test.dart' show close, playing, previewAt, settle;

/// T-DLY-03d: the coach on Home follows the day, celebrates Done, reacts
/// to the check-in, and the moments' buttons lead somewhere.

ProviderContainer scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

Finder heroFace(AvatarExpression e) => find.descendant(
  of: find.byKey(const Key('home-coach')),
  matching: find.byKey(Key('coach-avatar-${e.name}')),
);

final play = find.byKey(const Key('home-moment-play'));
final celebration = find.byKey(const Key('celebration'));

/// Plays the hero's moment and lets the coach finish.
Future<void> playHero(WidgetTester tester, Harness h) async {
  await tester.tap(play);
  await settle(tester);
  h.speaker.finish();
  await tester.pumpAndSettle();
}

/// Taps a moment's button, scrolling to it first.
Future<void> choose(WidgetTester tester, MomentAction a) async {
  final button = find.byKey(Key('moment-action-${a.name}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens today's step and taps Done.
Future<void> tapDone(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('step-open')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('step-open')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('step-done')),
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byKey(const Key('step-done')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('the coach on Home follows the day', () {
    for (final (label, hour, moment, face, bubble) in [
      (
        'morning',
        8,
        Moment.morning,
        AvatarExpression.waving,
        "Hi, Priya! Let's make today a good day.",
      ),
      (
        'after the step reminder',
        14,
        Moment.stepReminder,
        AvatarExpression.happy,
        'Ready for your small step, Priya?',
      ),
      (
        'evening',
        21,
        Moment.evening,
        AvatarExpression.listening,
        'How did today go, Priya?',
      ),
    ]) {
      testWidgets('$label: ${moment.file}, its face and short line; play '
          'says the whole message', (tester) async {
        final h = await previewAt(
          tester,
          now: DateTime(2026, 10, 14, hour, 30),
        );
        expect(heroFace(face), findsOneWidget);
        expect(find.text(bubble), findsOneWidget);
        await tester.tap(play);
        await settle(tester);
        expect(playing(tester), moment);
        expect(h.speaker.spoken.single.$1.moment, moment);
        await close(tester, h);
      });
    }

    testWidgets('a gentle day: the calm coach and the gentle moment', (
      tester,
    ) async {
      await bootPreview(
        tester,
        checkIn: const CheckIn(date: today, mood: 1, gentleDay: true),
      );
      expect(heroFace(AvatarExpression.calm), findsOneWidget);
      await tester.tap(play);
      await settle(tester);
      expect(playing(tester), Moment.gentle);
    });

    testWidgets('prod: nothing approved to say, so no play button', (
      tester,
    ) async {
      await signedIn().boot(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-coach')), findsOneWidget);
      expect(play, findsNothing);
    });
  });

  group('Done celebration', () {
    testWidgets('the coach celebrates and says the Done line (the '
        "preview's 14 days in a row: the milestone line), then closes; Home "
        'shows the step-done moment', (tester) async {
      final h = await bootPreview(tester);
      await tapDone(tester);
      expect(celebration, findsOneWidget);
      expect(find.byKey(const Key('celebration-avatar')), findsOneWidget);
      final said = h.speaker.spoken.single.$1;
      expect(said.moment, Moment.streakMilestone);
      expect(said.messageId, startsWith('streak_milestone.'));
      expect(said.text, contains('14 days in a row'));
      // About 3 seconds, and it waits for the voice to finish.
      await tester.pump(Celebration.length);
      expect(celebration, findsOneWidget);
      h.speaker.finish();
      await tester.pumpAndSettle();
      expect(celebration, findsNothing);
      expect(heroFace(AvatarExpression.celebrating), findsOneWidget);
      expect(find.text('Nice work! Today’s step is done.'), findsOneWidget);
    });

    testWidgets('a tap skips it and stops the voice', (tester) async {
      final h = await bootPreview(tester);
      await tapDone(tester);
      await tester.tap(celebration);
      await tester.pumpAndSettle();
      expect(celebration, findsNothing);
      expect(h.speaker.stops, greaterThanOrEqualTo(1));
    });

    testWidgets('muted in a moment: the celebration is silent', (tester) async {
      final h = await bootPreview(tester);
      await tester.tap(play);
      await settle(tester);
      await tester.tap(find.byKey(const Key('moment-mute')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moment-close')));
      await tester.pumpAndSettle();
      await tapDone(tester);
      expect(celebration, findsOneWidget);
      expect(h.speaker.spoken, hasLength(1), reason: 'only the first moment');
      await tester.pump(Celebration.length);
      await tester.pumpAndSettle();
      expect(celebration, findsNothing);
    });

    testWidgets('reduced motion: still leaves, still closes', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final h = await bootPreview(tester);
      await tapDone(tester);
      expect(celebration, findsOneWidget);
      h.speaker.finish();
      await tester.pump(Celebration.length);
      await tester.pumpAndSettle();
      expect(celebration, findsNothing);
    });

    testWidgets('prod: "You did it!" without a voice', (tester) async {
      final h = signedIn();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 4,
        gentleDay: false,
      );
      h.plans.days[today] = const PlanDay(
        date: today,
        dayNumber: 1,
        focus: FocusArea.moveMore,
        title: '10-min walk after lunch',
        reason: 'A short walk helps.',
        anchor: 'after lunch',
        minutes: 10,
        smallerTitle: '5-min walk after lunch',
        smallerMinutes: 5,
        gentle: false,
      );
      await h.boot(tester);
      await tester.pumpAndSettle();
      await tapDone(tester);
      expect(find.text('You did it!'), findsOneWidget);
      expect(h.speaker.spoken, isEmpty);
      await tester.pump(Celebration.length);
      await tester.pumpAndSettle();
      expect(celebration, findsNothing);
    });
  });

  group('the coach reacts to the check-in', () {
    for (final (label, checkIn, face) in [
      (
        'a good day',
        const CheckIn(date: today, mood: 5, gentleDay: false),
        AvatarExpression.celebrating,
      ),
      (
        'a steady day',
        const CheckIn(date: today, mood: 3, gentleDay: false),
        AvatarExpression.happy,
      ),
      (
        'a gentle day',
        const CheckIn(date: today, mood: 1, gentleDay: true),
        AvatarExpression.calm,
      ),
    ]) {
      testWidgets('$label: ${face.name}', (tester) async {
        await bootPreview(tester, checkIn: checkIn);
        final reaction = find.byKey(Key('checkin-reaction-${face.name}'));
        await tester.scrollUntilVisible(reaction, 200);
        expect(reaction, findsOneWidget);
        expect(find.byKey(const Key('checkin-response')), findsOneWidget);
      });
    }
  });

  group("the moment's buttons", () {
    testWidgets('Check in opens the check-in', (tester) async {
      final h = await bootPreview(tester);
      await playHero(tester, h);
      await choose(tester, MomentAction.checkIn);
      await tester.pumpAndSettle();
      expect(find.byType(CheckInSheet), findsOneWidget);
    });

    testWidgets('Make it smaller makes the step smaller', (tester) async {
      final h = await bootPreview(tester);
      await playHero(tester, h);
      await choose(tester, MomentAction.makeSmaller);
      await tester.pumpAndSettle();
      expect(scope(tester).read(stepProgressProvider).smaller, isTrue);
    });

    testWidgets('Done (from the step reminder) celebrates', (tester) async {
      final h = await previewAt(tester, now: DateTime(2026, 10, 14, 14));
      await playHero(tester, h);
      await choose(tester, MomentAction.done);
      expect(celebration, findsOneWidget);
      expect(scope(tester).read(stepProgressProvider).done, isTrue);
      await tester.tap(celebration);
      await tester.pumpAndSettle();
    });

    testWidgets('See my week goes to Track', (tester) async {
      final h = await bootPreview(tester);
      h.reminders.tap(TouchpointKind.weekly);
      await settle(tester);
      h.speaker.finish();
      await tester.pumpAndSettle();
      await choose(tester, MomentAction.seeWeek);
      await tester.pumpAndSettle();
      expect(find.byType(TrackScreen), findsOneWidget);
    });

    testWidgets('Close just closes', (tester) async {
      final h = await previewAt(tester, now: DateTime(2026, 10, 14, 21));
      await playHero(tester, h);
      expect(find.byType(MomentScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('moment-close')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(CheckInSheet), findsNothing);
    });
  });

  testWidgets('after a red flag today the coach stays quiet: no play, no '
      'morning card, no moment, a silent celebration', (tester) async {
    final h = await bootPreview(tester);
    scope(tester).read(safetyHoldStoreProvider.notifier).holdToday();
    await tester.pumpAndSettle();
    expect(play, findsNothing);
    expect(find.byKey(const Key('home-moment-card')), findsNothing);
    h.reminders.tap(TouchpointKind.greeting);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment-none')), findsOneWidget);
    await tester.tap(find.byKey(const Key('moment-close')));
    await tester.pumpAndSettle();
    await tapDone(tester);
    expect(find.text('You did it!'), findsOneWidget);
    expect(h.speaker.spoken, isEmpty);
    await tester.tap(celebration);
    await tester.pumpAndSettle();
  });
}
