import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/moments/application/coach_state.dart';
import 'package:livewell/features/moments/application/moment_playback.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';
import 'package:livewell/features/starter_plan/presentation/daily_plan_screen.dart';
import 'package:livewell/features/voice/domain/voice.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import 'starter_plan_test.dart' show plan;

/// T-DLY-03e: Profile > Daily plan.

const uid = 'u1';

/// The first plan day, 06:00: today's moments are all still ahead.
final planDay = DateTime(2026, 10, 15, 6);

Harness signedIn({
  Flavor flavor = Flavor.prod,
  Map<String, Object>? settings,
  String? why,
}) {
  final h = Harness(
    flavor: flavor,
    now: planDay,
    // Today's check-in was offered already: no sheet over Home.
    checkInPrompt: FakeCheckInPromptStore('2026-10-15'),
    auth: FakeAuthService(
      signedIn: const AuthUser(uid: uid, providers: ['password']),
    ),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  h.profiles.names[uid] = 'Priya Shah';
  if (why != null) h.profiles.whys[uid] = why;
  if (settings != null) h.profiles.settings[uid] = {...settings};
  return h;
}

Future<Harness> openDailyPlan(
  WidgetTester tester, {
  Flavor flavor = Flavor.prod,
  Map<String, Object>? settings,
  String? why,
}) async {
  final h = signedIn(flavor: flavor, settings: settings, why: why);
  await h.consents.record(ConsentType.notifications, granted: true);
  await h.plans.save(plan(), const TouchpointTimes());
  await h.boot(tester);
  await tester.tap(find.byKey(const Key('profile-button')));
  await tester.pumpAndSettle();
  await tap(tester, 'profile-daily-plan');
  expect(find.byType(DailyPlanScreen), findsOneWidget);
  return h;
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Types [hour]:[minute] (AM) into the time picker and confirms.
Future<void> pickTime(WidgetTester tester, int hour, int minute) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Iterable<ScheduledTouchpoint> scheduled(Harness h, TouchpointKind k) =>
    h.reminders.scheduled.where((s) => s.kind == k);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

void main() {
  group('moment times and reminders', () {
    testWidgets('turning off a reminder reschedules without it', (
      tester,
    ) async {
      final h = await openDailyPlan(tester);
      await tap(tester, 'plan-touchpoint-nudge');
      expect(h.profiles.settings[uid]!['notification_categories'], {
        'greeting': true,
        'nudge': false,
        'reflection': true,
        'weekly': true,
      });
      expect(scheduled(h, TouchpointKind.nudge), isEmpty);
      expect(h.reminders.scheduled, isNotEmpty);
      // Off: no "Not today" for it.
      expect(find.byKey(const Key('plan-not-today-nudge')), findsNothing);
    });

    testWidgets('changing a time saves it and reschedules at the new time', (
      tester,
    ) async {
      final h = await openDailyPlan(tester);
      await tap(tester, 'plan-time-greeting');
      await pickTime(tester, 8, 15);
      expect(h.plans.times.morning, const ClockTime(8, 15));
      final mornings = scheduled(h, TouchpointKind.greeting).toList();
      expect(mornings, isNotEmpty);
      for (final s in mornings) {
        expect((s.when.hour, s.when.minute), (8, 15));
      }
      expect(find.text('8:15 AM'), findsOneWidget);
    });

    testWidgets('a time inside quiet hours is refused with a clear message', (
      tester,
    ) async {
      final h = await openDailyPlan(tester);
      final before = List.of(h.reminders.scheduled);
      await tap(tester, 'plan-time-greeting');
      await pickTime(tester, 6, 30);
      expect(find.textContaining('quiet hours'), findsOneWidget);
      // Not saved, nothing rescheduled.
      expect(h.plans.times.morning, const ClockTime(7, 0));
      expect(h.reminders.scheduled.length, before.length);
      for (final s in scheduled(h, TouchpointKind.greeting)) {
        expect((s.when.hour, s.when.minute), (7, 0));
      }
    });

    testWidgets('quiet hours moved over a moment: it says no reminder is '
        'sent, and none is', (tester) async {
      final h = await openDailyPlan(
        tester,
        settings: {
          ProfileSettings.quietHours: const QuietHours(
            start: ClockTime(20, 0),
            end: ClockTime(7, 0),
          ).toMap(),
        },
      );
      await tap(tester, 'plan-quiet-end');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan-in-quiet-reflection')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(scheduled(h, TouchpointKind.reflection), isEmpty);
    });

    testWidgets('"Not today" drops only today\'s reminder; it is back '
        'tomorrow', (tester) async {
      final h = await openDailyPlan(tester);
      await tap(tester, 'plan-not-today-greeting');
      expect(h.profiles.settings[uid]![ProfileSettings.notToday], {
        'date': '2026-10-15',
        'kinds': ['greeting'],
      });
      final mornings = scheduled(h, TouchpointKind.greeting);
      expect(mornings.any((s) => sameDay(s.when, planDay)), isFalse);
      expect(
        mornings.any(
          (s) => sameDay(s.when, planDay.add(const Duration(days: 1))),
        ),
        isTrue,
      );
      // The other moments today are untouched.
      expect(
        scheduled(
          h,
          TouchpointKind.reflection,
        ).any((s) => sameDay(s.when, planDay)),
        isTrue,
      );
      // And back on.
      await tap(tester, 'plan-not-today-greeting');
      expect(
        scheduled(
          h,
          TouchpointKind.greeting,
        ).any((s) => sameDay(s.when, planDay)),
        isTrue,
      );
    });
  });

  test('NotToday only applies to its own day', () {
    final day = DateTime(2026, 10, 15);
    final n = const NotToday(
      date: '2026-10-14',
      kinds: {TouchpointKind.nudge},
    ).toggle(day, TouchpointKind.greeting, off: true);
    // Yesterday's choice is dropped.
    expect(n.kinds, {TouchpointKind.greeting});
    expect(n.skips(day, TouchpointKind.greeting), isTrue);
    expect(
      n.skips(day.add(const Duration(days: 1)), TouchpointKind.greeting),
      isFalse,
    );
    expect(
      NotToday.fromMap(n.toMap()).skips(day, TouchpointKind.greeting),
      isTrue,
    );
  });

  group('how moments play', () {
    testWidgets('speak automatically and captions: on by default, saved on '
        'the profile', (tester) async {
      final h = await openDailyPlan(tester);
      Switch at(String key) => tester.widget<Switch>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Switch),
        ),
      );
      expect(at('plan-auto-speak').value, isTrue);
      expect(at('plan-captions').value, isTrue);
      await tap(tester, 'plan-auto-speak');
      expect(find.textContaining('Show text only'), findsOneWidget);
      await tap(tester, 'plan-captions');
      expect(h.profiles.settings[uid]![ProfileSettings.momentPlayback], {
        'auto_speak': false,
        'captions': false,
      });
      expect(at('plan-auto-speak').value, isFalse);
      expect(at('plan-captions').value, isFalse);
    });

    testWidgets('voice speed is saved with the chosen voice (one source of '
        'truth) and shows the saved value', (tester) async {
      final h = Harness(
        now: planDay,
        checkInPrompt: FakeCheckInPromptStore('2026-10-15'),
        auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
      );
      h.profiles.existing[uid] = ProfileStep.assessment;
      h.voices.chosen = const VoiceChoice(voiceId: 'lw-warm', speed: 0.9);
      await h.boot(tester);
      await tester.tap(find.byKey(const Key('profile-button')));
      await tester.pumpAndSettle();
      await tap(tester, 'profile-daily-plan');
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan-speed')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('0.9x'), findsOneWidget);
      // Drag to the right end: 1.2x.
      await tester.drag(
        find.byKey(const Key('plan-speed')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      expect(h.voices.chosen!.speed, VoiceChoice.maxSpeed);
      expect(h.voices.chosen!.voiceId, 'lw-warm');
      expect(find.text('1.2x'), findsOneWidget);
    });
  });

  group('preview', () {
    testWidgets('plays tomorrow\'s morning now: generic (no Why), marks '
        'nothing as seen', (tester) async {
      final h = await openDailyPlan(
        tester,
        flavor: Flavor.dev,
        why: 'I want energy to travel with my family.',
      );
      await tap(tester, 'plan-preview');
      expect(find.byType(MomentScreen), findsOneWidget);
      expect(find.byKey(const Key('moment-preview-tag')), findsOneWidget);
      final (msg, _) = h.speaker.spoken.single;
      expect(msg.moment, Moment.morning);
      expect(msg.messageId, startsWith('morning.'));
      expect(msg.text, contains('Priya'));
      expect(msg.text, isNot(contains('travel')));
      // Tomorrow 7:00 is a morning.
      expect(msg.text, contains('morning'));
      // Today's morning moment is still to come.
      expect(h.momentSeen.date, isNull);
      h.speaker.finish();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moment-close')));
      await tester.pumpAndSettle();
      expect(find.byType(DailyPlanScreen), findsOneWidget);
    });

    testWidgets('prod before the scripts are approved: says there is '
        'nothing to preview', (tester) async {
      final h = await openDailyPlan(tester);
      await tap(tester, 'plan-preview');
      expect(find.byType(MomentScreen), findsNothing);
      expect(find.textContaining('no morning message'), findsOneWidget);
      expect(h.speaker.spoken, isEmpty);
    });

    testWidgets('after a safety event today: no preview', (tester) async {
      final h = await openDailyPlan(tester, flavor: Flavor.dev);
      ProviderScope.containerOf(tester.element(find.byType(DailyPlanScreen)))
          .read(safetyHoldStoreProvider.notifier)
          .holdToday();
      await tap(tester, 'plan-preview');
      expect(find.byType(MomentScreen), findsNothing);
      expect(find.textContaining('keep today quiet'), findsOneWidget);
      expect(h.speaker.spoken, isEmpty);
    });
  });

  testWidgets('the widget guide is there, and the lock screen stays private', (
    tester,
  ) async {
    await openDailyPlan(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('plan-widget-private')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('plan-widget-guide')), findsOneWidget);
    expect(find.text('Add the widget'), findsOneWidget);
  });

  test('playback settings: defaults on, read back from the profile map', () {
    expect(MomentPlayback.fromMap(null).autoSpeak, isTrue);
    expect(MomentPlayback.fromMap(null).captions, isTrue);
    final off = MomentPlayback.fromMap(
      const MomentPlayback(autoSpeak: false, captions: false).toMap(),
    );
    expect((off.autoSpeak, off.captions), (false, false));
    // Junk is ignored, never turns speech off.
    expect(MomentPlayback.fromMap({'auto_speak': 'no'}).autoSpeak, isTrue);
  });
}
