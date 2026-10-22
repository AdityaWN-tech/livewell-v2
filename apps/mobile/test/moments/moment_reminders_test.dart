import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart'
    show defaultCoach;
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/application/moment_launcher.dart';
import 'package:livewell/features/moments/data/coach_faces.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';

import 'package:livewell/core/config/flavor.dart';

import '../home/home_screen_test.dart'
    show bootPreview, previewLabel, signedIn, today;
import '../support/app_harness.dart';

/// T-DLY-03c: reminders open the avatar's moments; the morning card.

/// Lets the moment open without settling (the coach keeps talking).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Moment? playing(WidgetTester tester) {
  final screens = tester.widgetList<MomentScreen>(find.byType(MomentScreen));
  return screens.isEmpty ? null : screens.single.moment;
}

Future<void> close(WidgetTester tester, Harness h) async {
  h.speaker.finish();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('moment-close')));
  await tester.pumpAndSettle();
}

final card = find.byKey(const Key('home-moment-card'));

/// The dev preview at [now], with the morning moment last played [seen].
Future<Harness> previewAt(
  WidgetTester tester, {
  DateTime? now,
  String? seen,
  PlanDay? yesterday,
}) async {
  final h = Harness(flavor: Flavor.dev, now: now);
  h.momentSeen.date = seen;
  if (yesterday != null) h.plans.days[yesterday.date] = yesterday;
  await h.boot(tester);
  await tester.scrollUntilVisible(find.text(previewLabel), 200);
  await tester.tap(find.text(previewLabel));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  test('each reminder has its moment and face', () {
    expect(
      {for (final k in TouchpointKind.values) k: momentFor(k)},
      {
        TouchpointKind.greeting: Moment.morning,
        TouchpointKind.nudge: Moment.stepReminder,
        TouchpointKind.reflection: Moment.evening,
        TouchpointKind.weekly: Moment.weeklyReview,
      },
    );
    expect(faceFor(TouchpointKind.greeting), AvatarExpression.waving);
    expect(faceFor(TouchpointKind.reflection), AvatarExpression.listening);
  });

  testWidgets("the coach's face draws as a PNG for the notification", (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => FileCoachFaces.png(defaultCoach, AvatarExpression.waving),
    );
    // The PNG signature.
    expect(bytes!.take(4), [0x89, 0x50, 0x4E, 0x47]);
    expect(bytes.length, greaterThan(1000));
  });

  for (final (kind, moment) in [
    (TouchpointKind.greeting, Moment.morning),
    (TouchpointKind.nudge, Moment.stepReminder),
    (TouchpointKind.reflection, Moment.evening),
    (TouchpointKind.weekly, Moment.weeklyReview),
  ]) {
    testWidgets('tapping the ${kind.name} reminder opens ${moment.file}, '
        'which speaks', (tester) async {
      final h = await bootPreview(tester);
      h.reminders.tap(kind);
      await settle(tester);
      expect(playing(tester), moment);
      expect(h.speaker.spoken.single.$1.moment, moment);
      await close(tester, h);
    });
  }

  testWidgets('after a plan day with no check-in, the morning reminder opens '
      '"missed day"', (tester) async {
    final h = await previewAt(
      tester,
      yesterday: const PlanDay(
        date: '2026-10-13',
        dayNumber: 1,
        focus: FocusArea.moveMore,
        title: '10-min walk after lunch',
        reason: '',
        anchor: 'after lunch',
        minutes: 10,
        smallerTitle: null,
        smallerMinutes: null,
        gentle: false,
      ),
    );
    h.reminders.tap(TouchpointKind.greeting);
    await settle(tester);
    expect(playing(tester), Moment.missedDay);
    await close(tester, h);
  });

  testWidgets('a reminder that started the app opens its moment', (
    tester,
  ) async {
    final h = signedIn();
    h.reminders.launch = TouchpointKind.reflection.name;
    await h.boot(tester);
    await settle(tester);
    expect(playing(tester), Moment.evening);
    // Prod: the scripts await review, so nothing is said yet.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment-none')), findsOneWidget);
    expect(h.speaker.spoken, isEmpty);
    // Only once: back on Home it doesn't open again.
    await tester.tap(find.byKey(const Key('moment-close')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(playing(tester), isNull);
  });

  testWidgets('an unknown reminder (an older app version) does nothing', (
    tester,
  ) async {
    final h = await bootPreview(tester);
    h.reminders.tapPayload('briefing');
    await settle(tester);
    expect(playing(tester), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  group('the morning card on Home', () {
    testWidgets('after the morning time it plays the moment; then it goes '
        "and today's reminder leaves the tray", (tester) async {
      final h = await bootPreview(tester);
      expect(card, findsOneWidget);
      expect(find.text('Your coach has a message'), findsOneWidget);
      await tester.tap(card);
      await settle(tester);
      expect(playing(tester), Moment.morning);
      await close(tester, h);
      expect(card, findsNothing);
      expect(h.momentSeen.date, today);
      expect(h.reminders.dismissed, [
        TouchpointScheduler.idFor(
          DateTime(2026, 10, 14),
          TouchpointKind.greeting,
        ),
      ]);
    });

    testWidgets('already played today: no card', (tester) async {
      await previewAt(tester, seen: today);
      expect(card, findsNothing);
    });

    for (final (label, now) in [
      ('before the morning time', DateTime(2026, 10, 14, 6, 30)),
      ('in the afternoon', DateTime(2026, 10, 14, 14)),
    ]) {
      testWidgets('$label: no card', (tester) async {
        await previewAt(tester, now: now);
        expect(card, findsNothing);
      });
    }

    testWidgets('prod: no approved script yet, so no card', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });
  });
}
