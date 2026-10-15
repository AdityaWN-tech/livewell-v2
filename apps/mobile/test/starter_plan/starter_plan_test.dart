import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/time/clock.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/focus/domain/focus.dart';
import 'package:livewell/features/starter_plan/application/plan_scheduler.dart';
import 'package:livewell/features/starter_plan/data/plan_repository.dart';
import 'package:livewell/features/starter_plan/data/reminders.dart';
import 'package:livewell/features/starter_plan/domain/starter_plan.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';

import '../consent/consent_test.dart' show FakeConsentRepository;
import '../support/fakes.dart';

final _dir = Directory('../../content/plan/templates');

PlanTemplate _load(String name) =>
    PlanTemplate.parse(File('${_dir.path}/$name.json').readAsStringSync());

final templates = {for (final f in FocusArea.values) f: _load(f.id)};
final limited = _load('limited');

StarterPlan plan({
  List<FocusArea> focus = const [FocusArea.moveMore],
  int? minutes = 10,
  bool gentle = false,
  bool limitedActivity = false,
}) => StarterPlanGenerator.generate(
  start: DateTime(2026, 10, 15),
  focus: focus,
  minutes: minutes,
  gentleToday: gentle,
  activityLimited: limitedActivity,
  templates: templates,
  limited: limited,
  gentleReason: 'A gentle day. Go easy on yourself.',
);

const texts = ReminderTexts(
  greetingTitle: 'Good morning',
  greetingBody: 'Your coach has a hello.',
  nudgeTitle: 'Time for your small step',
  nudgeBody: 'Open Live Well.',
  reflectionTitle: 'A moment to look back',
  reflectionBody: 'What went well today?',
  channelName: 'Daily plan',
);

void main() {
  group('template files (content/plan/templates)', () {
    final files = _dir.listSync().whereType<File>().toList();

    test('one per focus plus limited, each pending review with 7 days', () {
      expect(files.map((f) => f.uri.pathSegments.last).toSet(), {
        for (final f in FocusArea.values) '${f.id}.json',
        'limited.json',
      });
      for (final t in [...templates.values, limited]) {
        expect(t.reviewStatus, 'pending');
        expect(t.days, hasLength(7));
        for (final d in t.days) {
          expect(d.title, contains('{minutes}'));
        }
      }
    });

    test('the app copies match content/', () {
      for (final f in files) {
        final copy = File('assets/plan/templates/${f.uri.pathSegments.last}');
        expect(copy.readAsStringSync(), f.readAsStringSync(), reason: f.path);
      }
    });

    test('no weight-loss, calorie or fasting content', () {
      final banned = RegExp(
        r'\b(weight|calorie|calories|fasting|fast|diet|lose|burn|kg|lbs?)\b',
        caseSensitive: false,
      );
      for (final f in files) {
        expect(banned.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('the no-exercise set has no movement at all (FR-GOL-03)', () {
      expect(limited.days.any((d) => d.movement), isFalse);
      expect(limited.supporting.any((s) => s.movement), isFalse);
    });

    test('only approved templates outside dev', () {
      expect(templatesUsable(isDev: true, t: templates.values), isTrue);
      expect(templatesUsable(isDev: false, t: templates.values), isFalse);
    });
  });

  group('plan generation', () {
    for (final f in FocusArea.values) {
      for (final size in TimeSizes.all) {
        test(
          '${f.id} at $size min: 7 days, one step a day, smaller option',
          () {
            final p = plan(focus: [f], minutes: size);
            expect(p.days, hasLength(7));
            expect(p.days.first.date, '2026-10-15');
            expect(p.days.last.date, '2026-10-21');
            for (final d in p.days) {
              expect(d.minutes, size);
              expect(d.title, contains('$size'));
              expect(d.title, isNot(contains('{minutes}')));
              expect(d.smallerMinutes, TimeSizes.smaller(size));
              expect(d.smallerTitle == null, size == 2);
            }
            expect(p.supporting.length, lessThanOrEqualTo(2));
          },
        );
      }
    }

    test('skipped time question: 5 minutes', () {
      expect(plan(minutes: null).days.first.minutes, 5);
    });

    test('second focus gets days 3 and 6', () {
      final p = plan(focus: [FocusArea.moveMore, FocusArea.sleepBetter]);
      expect(
        [for (final d in p.days) d.focus],
        [
          FocusArea.moveMore,
          FocusArea.moveMore,
          FocusArea.sleepBetter,
          FocusArea.moveMore,
          FocusArea.moveMore,
          FocusArea.sleepBetter,
          FocusArea.moveMore,
        ],
      );
    });

    test('gentle day: day 1 is the smallest step with the gentle message', () {
      final p = plan(gentle: true, minutes: 30);
      expect(p.days.first.minutes, 2);
      expect(p.days.first.gentle, isTrue);
      expect(p.days.first.reason, 'A gentle day. Go easy on yourself.');
      expect(p.days[1].minutes, 30);
      expect(p.days[1].gentle, isFalse);
    });

    test('activity limited: no movement step or habit anywhere', () {
      for (final f in FocusArea.values) {
        final p = plan(focus: [f], limitedActivity: true);
        for (var i = 0; i < 7; i++) {
          final t = templates[f]!.days[i];
          final expected = t.movement ? limited.days[i] : t;
          expect(p.days[i].title, expected.titleFor(10), reason: '${f.id} $i');
        }
        expect(p.supporting.any((s) => s.movement), isFalse);
      }
    });

    test('at most 2 supporting habits, no duplicates (FR-GOL-01)', () {
      final p = plan(focus: [FocusArea.sleepBetter, FocusArea.healthyRoutine]);
      expect(p.supporting, hasLength(2));
      expect(p.supporting.map((s) => s.id).toSet(), hasLength(2));
    });

    test('next week (FR-DLY-08): up at 5+/7, down under 2/7, else same', () {
      expect(StarterPlanGenerator.suggestedNextSize(5, 5), 10);
      expect(StarterPlanGenerator.suggestedNextSize(30, 7), 30);
      expect(StarterPlanGenerator.suggestedNextSize(10, 1), 5);
      expect(StarterPlanGenerator.suggestedNextSize(2, 0), 2);
      expect(StarterPlanGenerator.suggestedNextSize(10, 3), 10);
    });
  });

  group('touchpoints and reminders', () {
    final days = [for (var i = 0; i < 7; i++) DateTime(2026, 10, 15 + i)];

    test('3 a day at the default times, never the ones already past', () {
      final s = TouchpointScheduler.build(
        days: days,
        times: const TouchpointTimes(),
        quiet: const QuietHours(),
        consent: true,
        now: DateTime(2026, 10, 15, 12),
      );
      // Today: the 7:00 greeting has passed; 13:00 and 20:30 remain.
      expect(s.where((x) => x.when.day == 15).map((x) => x.kind), [
        TouchpointKind.nudge,
        TouchpointKind.reflection,
      ]);
      expect(s, hasLength(2 + 6 * 3));
      expect(s.first.when, DateTime(2026, 10, 15, 13));
    });

    test('caps: at most 4 a day and 3 nudges a day', () {
      final s = TouchpointScheduler.build(
        days: days,
        times: const TouchpointTimes(),
        quiet: const QuietHours(),
        consent: true,
        now: DateTime(2026, 10, 14),
      );
      for (final d in days) {
        final today = s.where((x) => x.when.day == d.day);
        expect(today.length, lessThanOrEqualTo(NotificationCaps.perDay));
        expect(
          today.where((x) => x.kind == TouchpointKind.nudge).length,
          lessThanOrEqualTo(NotificationCaps.nudgesPerDay),
        );
      }
    });

    test('quiet hours (crossing midnight) are respected', () {
      const q = QuietHours();
      expect(q.contains(const ClockTime(23, 0)), isTrue);
      expect(q.contains(const ClockTime(6, 59)), isTrue);
      expect(q.contains(const ClockTime(7, 0)), isFalse);
      expect(q.contains(const ClockTime(21, 59)), isFalse);
      final s = TouchpointScheduler.build(
        days: days,
        times: const TouchpointTimes(evening: ClockTime(22, 30)),
        quiet: q,
        consent: true,
        now: DateTime(2026, 10, 14),
      );
      expect(s.any((x) => x.kind == TouchpointKind.reflection), isFalse);
    });

    test('no notification consent: nothing scheduled', () {
      expect(
        TouchpointScheduler.build(
          days: days,
          times: const TouchpointTimes(),
          quiet: const QuietHours(),
          consent: false,
          now: DateTime(2026, 10, 14),
        ),
        isEmpty,
      );
    });

    test('edited times move the reminders; ids stay the same (replace)', () {
      List<ScheduledTouchpoint> at(TouchpointTimes t) =>
          TouchpointScheduler.build(
            days: days,
            times: t,
            quiet: const QuietHours(),
            consent: true,
            now: DateTime(2026, 10, 14),
          );
      final before = at(const TouchpointTimes());
      final after = at(
        const TouchpointTimes().copyWith(
          TouchpointKind.nudge,
          const ClockTime(12, 15),
        ),
      );
      expect(after.map((x) => x.id), before.map((x) => x.id));
      final nudge = after.firstWhere((x) => x.kind == TouchpointKind.nudge);
      expect(nudge.when, DateTime(2026, 10, 15, 12, 15));
    });

    test('touchpoint times round-trip as HH:MM (rules format)', () {
      const t = TouchpointTimes(midday: ClockTime(12, 5));
      expect(t.toMap(), {
        'morning': '07:00',
        'midday': '12:05',
        'evening': '20:30',
      });
      expect(TouchpointTimes.fromMap(t.toMap()).midday, const ClockTime(12, 5));
      expect(
        TouchpointTimes.fromMap({'morning': '25:00'}).morning,
        const ClockTime(7, 0),
      );
    });
  });

  group('PlanScheduler', () {
    late FakePlanRepository plans;
    late FakeReminders reminders;
    late FakeReminderZoneStore zone;
    late FakeConsentRepository consents;
    late ProviderContainer c;

    setUp(() async {
      plans = FakePlanRepository();
      reminders = FakeReminders();
      zone = FakeReminderZoneStore();
      consents = FakeConsentRepository();
      await plans.save(plan(), const TouchpointTimes());
      c = ProviderContainer(
        overrides: [
          planRepositoryProvider.overrideWithValue(plans),
          remindersProvider.overrideWithValue(reminders),
          reminderZoneStoreProvider.overrideWithValue(zone),
          consentRepositoryProvider.overrideWithValue(consents),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 8)),
        ],
      );
    });
    tearDown(() => c.dispose());

    test('with consent: schedules the plan, generic texts only', () async {
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(planSchedulerProvider).reschedule(texts);
      expect(reminders.scheduled, hasLength(2 + 6 * 3));
      expect(zone.zone, 'Asia/Kolkata');
      for (final s in [
        texts.greetingBody,
        texts.nudgeBody,
        texts.reflectionBody,
      ]) {
        expect(s, isNot(contains('walk')), reason: 'no health details');
      }
    });

    test('without consent: everything is cancelled', () async {
      await consents.record(ConsentType.notifications, granted: false);
      await c.read(planSchedulerProvider).reschedule(texts);
      expect(reminders.scheduled, isEmpty);
      expect(reminders.cancels, 1);
    });

    test('a time zone change reschedules; the same zone does not', () async {
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(planSchedulerProvider).reschedule(texts);
      reminders.scheduled = [];
      expect(
        await c.read(planSchedulerProvider).rescheduleIfZoneChanged(texts),
        isFalse,
      );
      reminders.zone = 'America/New_York';
      expect(
        await c.read(planSchedulerProvider).rescheduleIfZoneChanged(texts),
        isTrue,
      );
      expect(reminders.scheduled, isNotEmpty);
      expect(zone.zone, 'America/New_York');
    });
  });
}
