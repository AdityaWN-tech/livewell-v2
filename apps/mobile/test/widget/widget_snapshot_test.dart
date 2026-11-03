import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/home/application/home_data.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/widget/application/widget_sync.dart';
import 'package:livewell/features/widget/data/widget_publisher.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/widget/domain/widget_builder.dart';
import 'package:livewell/features/widget/domain/widget_snapshot.dart';
import 'package:livewell/l10n/app_localizations.dart';

import '../home/home_screen_test.dart' show bootPreview, today;

/// T-AVT-08g-a: the widget snapshot (T-TCH-02 PR TCH-a).

final builder = WidgetSnapshotBuilder(
  widgetTexts(lookupAppLocalizations(const Locale('en'))),
);

/// Wednesday 2026-10-14 at [hour]:[minute], signed in, Priya, the walk.
WidgetInputs day(
  int hour, {
  int minute = 0,
  bool checkedIn = false,
  bool gentle = false,
  bool hold = false,
  bool done = false,
  bool smaller = false,
  bool reflected = false,
  bool signedIn = true,
  bool plan = true,
  bool hideDetails = true,
  int? streak = 9,
}) => WidgetInputs(
  now: DateTime(2026, 10, 14, hour, minute),
  signedIn: signedIn,
  firstName: 'Priya',
  stepTitle: plan ? '10-min walk after lunch' : null,
  smallerTitle: plan ? '5-min walk after lunch' : null,
  checkedIn: checkedIn,
  gentleDay: gentle,
  safetyHold: hold,
  stepDone: done,
  smaller: smaller,
  reflected: reflected,
  streakDays: streak,
  avatarThumbs: const {'happy': '/faces/happy.png'},
  hideDetails: hideDetails,
);

WidgetEntry now(WidgetInputs i) => builder.build(i).current;

void main() {
  group('one thing to do now, through the day', () {
    test('morning, before the check-in: waving, good morning, Check in', () {
      final e = now(day(8));
      expect(e.slot, WidgetSlot.morningCheckIn);
      expect(e.expression, 'waving');
      expect(e.headline, 'Good morning, Priya!');
      expect(e.subline, 'Start with a 30-second check-in');
      expect(e.primary.id, WidgetActionId.checkIn);
      expect(e.primary.id.link, 'livewell://checkin');
    });

    test("after the check-in: today's step, Start or Make it smaller", () {
      final e = now(day(9, checkedIn: true));
      expect(e.slot, WidgetSlot.step);
      expect(e.headline, '10-min walk after lunch');
      expect(e.subline, 'Short on time? 5-min walk after lunch');
      expect(e.primary.id, WidgetActionId.openStep);
      expect(e.secondary!.id, WidgetActionId.makeSmaller);
      // Made smaller: the smaller step, no second offer.
      final s = now(day(9, checkedIn: true, smaller: true));
      expect(s.headline, '5-min walk after lunch');
      expect(s.secondary, isNull);
    });

    test('step time: "Time for your..." with Done', () {
      final e = now(day(13, minute: 30, checkedIn: true));
      expect(e.slot, WidgetSlot.stepWindow);
      expect(e.headline, 'Time for your 10-min walk after lunch');
      expect(e.primary.id, WidgetActionId.done);
      expect(e.primary.label, 'Done');
    });

    test('after Done: celebrating, "Day 9!", Open', () {
      final e = now(day(15, checkedIn: true, done: true));
      expect(e.slot, WidgetSlot.done);
      expect(e.expression, 'celebrating');
      expect(e.headline, 'Day 9!');
      expect(e.primary.id, WidgetActionId.openHome);
      expect(
        now(day(15, checkedIn: true, done: true, streak: null)).headline,
        'Nice work!',
      );
    });

    test('evening: listening, "How did today go?", Reflect; then done', () {
      final e = now(day(21, checkedIn: true, done: true));
      expect(e.slot, WidgetSlot.evening);
      expect(e.expression, 'listening');
      expect(e.headline, 'How did today go?');
      expect(e.primary.id, WidgetActionId.reflect);
      final after = now(day(21, checkedIn: true, done: true, reflected: true));
      expect(after.slot, WidgetSlot.done);
    });

    test('gentle day: calm, the smaller step, gentle words', () {
      final e = now(day(10, checkedIn: true, gentle: true));
      expect(e.slot, WidgetSlot.gentle);
      expect(e.expression, 'calm');
      expect(e.headline, '5-min walk after lunch');
      expect(e.subline, "Let's keep today gentle.");
    });

    test('after a safety response the coach never smiles or celebrates', () {
      for (final i in [
        day(10, checkedIn: true, hold: true),
        day(15, checkedIn: true, hold: true, done: true),
        day(21, checkedIn: true, hold: true, done: true),
      ]) {
        expect(now(i).expression, 'calm', reason: now(i).slot.id);
      }
    });

    test('no plan, and signed out (nothing personal kept)', () {
      expect(now(day(9, plan: false)).slot, WidgetSlot.none);
      expect(
        now(day(9, plan: false)).headline,
        'Open Live Well to start your plan',
      );
      final out = builder.build(day(9, signedIn: false));
      expect(out.current.slot, WidgetSlot.signedOut);
      expect(out.firstName, isNull);
      expect(out.avatarThumbs, isEmpty);
      expect(out.streakDays, isNull);
    });

    test('the routine row: done or to do, never "missed"', () {
      final s = builder.build(day(15, checkedIn: true, done: true));
      expect(s.routine, {
        'morning': RoutineStatus.done,
        'step': RoutineStatus.done,
        'evening': RoutineStatus.todo,
      });
      expect(RoutineStatus.values.map((v) => v.name), ['todo', 'done']);
    });
  });

  group('the timeline (so the widget changes without the app)', () {
    test('from 8:00: step time at 13:00, evening at 20:30, a new day at '
        'midnight', () {
      final s = builder.build(day(8));
      expect(
        [for (final e in s.entries) (e.at.hour, e.at.minute, e.slot)],
        [
          (8, 0, WidgetSlot.morningCheckIn),
          (13, 0, WidgetSlot.stepWindow),
          (20, 30, WidgetSlot.evening),
          (0, 0, WidgetSlot.morningCheckIn),
        ],
      );
      expect(s.entries.last.at, DateTime(2026, 10, 15));
      expect(s.entries.last.headline, 'Good morning, Priya!');
    });

    test('late in the evening: only midnight is left', () {
      final s = builder.build(day(22, reflected: true, done: true));
      expect(s.entries.map((e) => e.slot), [
        WidgetSlot.done,
        WidgetSlot.morningCheckIn,
      ]);
    });
  });

  group('privacy', () {
    test('lock screen: "Your next step is ready" unless details are on', () {
      expect(
        now(day(9, checkedIn: true)).lockHeadline,
        'Your next step is ready',
      );
      expect(
        now(day(9, checkedIn: true, hideDetails: false)).lockHeadline,
        'Next: 10-min walk after lunch',
      );
    });

    test('only the allowed fields, ever (a new field fails this test)', () {
      final json = builder.build(day(14, checkedIn: true)).toJson();
      expect(json.keys.toSet(), {
        'version',
        'first_name',
        'avatar_thumbs',
        'streak_days',
        'routine',
        'entries',
        'after_done',
        'routine_labels',
        'hide_details',
        'updated_at',
      });
      final entry = (json['entries']! as List).first as Map<String, Object?>;
      expect(entry.keys.toSet(), {
        'at',
        'slot',
        'expression',
        'headline',
        'subline',
        'lock_headline',
        'primary_action',
        'secondary_action',
      });
    });

    test('the inputs have no place for check-in answers or health values', () {
      final source = File('lib/features/widget/domain/widget_snapshot.dart')
          .readAsStringSync()
          .toLowerCase();
      final fields = RegExp(r'final [\w<>?, ]+ (\w+);')
          .allMatches(source)
          .map((m) => m[1]!)
          .toSet();
      for (final banned in [
        'mood',
        'energy',
        'sleep',
        'stress',
        'note',
        'barrier',
        'reflection',
        'weight',
        'glucose',
      ]) {
        expect(
          fields.where((f) => f.contains(banned)),
          isEmpty,
          reason: banned,
        );
      }
    });
  });

  test("each flavour writes to its own App Group", () {
    expect(
      appGroupFor(Flavor.dev),
      'group.net.conciergeconnectedcare.livewell.dev',
    );
    expect(
      appGroupFor(Flavor.staging),
      'group.net.conciergeconnectedcare.livewell.stg',
    );
    expect(
      appGroupFor(Flavor.prod),
      'group.net.conciergeconnectedcare.livewell',
    );
  });

  group('kept up to date in the app', () {
    Future<void> waitSync(WidgetTester tester) async {
      await tester.pump(WidgetSync.pause);
      await tester.pump();
    }

    testWidgets('signed out at first, then the day; the check-in and Done '
        'update it, with no check-in answers in it', (tester) async {
      final h = await bootPreview(tester);
      await waitSync(tester);
      expect(h.widget.published, isNotEmpty);
      final first = h.widget.published.first;
      expect(first.current.slot, WidgetSlot.signedOut);

      var s = h.widget.last!;
      expect(s.firstName, 'Priya');
      expect(s.current.slot, isNot(WidgetSlot.signedOut));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 2,
        stress: 5,
        gentleDay: true,
      );
      container.invalidate(todayCheckInProvider);
      await tester.pump();
      await waitSync(tester);
      s = h.widget.last!;
      expect(s.current.slot, WidgetSlot.gentle);
      final text = jsonEncode(s.toJson());
      expect(text, isNot(contains('mood')));
      expect(text, isNot(contains('stress')));

      container.read(stepProgressActionsProvider).markDone();
      await tester.pump();
      await waitSync(tester);
      expect(h.widget.last!.routine['step'], RoutineStatus.done);
    });
  });
}
