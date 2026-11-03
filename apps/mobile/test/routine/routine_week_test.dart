import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/domain/moment_builder.dart';
import 'package:livewell/features/moments/domain/moment_templates.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_catalog.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';
import 'package:livewell/features/routine/domain/routine_week.dart';
import 'package:livewell/features/widget/application/widget_sync.dart';
import 'package:livewell/features/widget/data/widget_inbox.dart';
import 'package:livewell/features/widget/domain/widget_builder.dart';
import 'package:livewell/features/widget/domain/widget_snapshot.dart'
    hide RoutineStatus;
import 'package:livewell/l10n/app_localizations.dart';

/// T-GOL-03e: the next item, done per day, the week's win, the widget's
/// routine slot and the weekly review line.

RoutineCatalog catalog() => RoutineCatalog.parse(
  File('../../content/routine/catalog.json').readAsStringSync(),
);

RoutineItem item(String id, String time, {String? catalogId}) => RoutineItem(
  itemId: id,
  routineId: myRoutineId,
  catalogId: catalogId,
  label: id,
  icon: 'water',
  time: time,
  durationMin: 2,
);

RoutineLog log(
  String date,
  String id, [
  RoutineStatus s = RoutineStatus.done,
]) => RoutineLog(date: date, itemId: id, status: s, source: RoutineSource.app);

final builder = WidgetSnapshotBuilder(
  widgetTexts(lookupAppLocalizations(const Locale('en'))),
);

WidgetInputs inputs({
  int hour = 15,
  bool done = true,
  bool plan = true,
  bool hold = false,
  bool hideDetails = true,
  WidgetRoutineItem? next,
}) => WidgetInputs(
  now: DateTime(2026, 10, 14, hour),
  signedIn: true,
  firstName: 'Priya',
  stepTitle: plan ? '10-min walk after lunch' : null,
  checkedIn: true,
  stepDone: done,
  safetyHold: hold,
  reflected: false,
  hideDetails: hideDetails,
  nextRoutine: next,
);

const water = WidgetRoutineItem(
  payload: 'routine:2026-10-14:water',
  time: '4:00 PM',
  label: 'Drink water',
);
const custom = WidgetRoutineItem(
  payload: 'routine:2026-10-14:c1',
  time: '6:30 PM',
);

void main() {
  group('the next item', () {
    final day = [item('a', '08:00'), item('b', '12:00'), item('c', '18:00')];
    final now = DateTime(2026, 10, 14, 12, 20);

    test('the first not marked, up to 30 minutes after its time', () {
      expect(nextRoutineItem(day, {}, now)?.itemId, 'b');
      expect(nextRoutineItem(day, {'b'}, now)?.itemId, 'c');
      expect(
        nextRoutineItem(day, {}, DateTime(2026, 10, 14, 12, 31))?.itemId,
        'c',
      );
      expect(nextRoutineItem(day, {'c'}, DateTime(2026, 10, 14, 19)), isNull);
    });
  });

  group('the week', () {
    test('done per day; skipped never counts', () {
      final logs = [
        log('2026-10-12', 'a'),
        log('2026-10-12', 'b'),
        log('2026-10-13', 'a', RoutineStatus.skipped),
        log('2026-10-14', 'a'),
      ];
      expect(doneByDay(logs, ['2026-10-12', '2026-10-13', '2026-10-14']), [
        2,
        0,
        1,
      ]);
      expect(doneCount(logs), 3);
    });

    test('the win: a catalog activity done on 4+ days, never a custom one', () {
      final items = {
        'w': item('w', '07:00', catalogId: 'drink_water'),
        'r': item('r', '21:00', catalogId: 'read'),
        'c': item('c', '18:00'),
      };
      final logs = [
        for (var d = 8; d <= 14; d++)
          log('2026-10-${d.toString().padLeft(2, '0')}', 'c'),
        for (var d = 9; d <= 13; d++)
          log('2026-10-${d.toString().padLeft(2, '0')}', 'w'),
        for (var d = 11; d <= 14; d++)
          log('2026-10-${d.toString().padLeft(2, '0')}', 'r'),
      ];
      final win = routineWin(logs, items, catalog())!;
      expect(win.spokenName, 'a glass of water');
      expect(win.days, 5);
      // Three days is not yet a win.
      expect(
        routineWin(
          logs.where((l) => l.itemId != 'w' && l.itemId != 'r').toList(),
          items,
          catalog(),
        ),
        isNull,
      );
    });

    test('every spoken name reads well after "you made time for"', () {
      for (final a in catalog().activities) {
        expect(a.spokenName, isNot(matches(r'^[A-Z]')), reason: a.id);
        expect(a.spokenName.split(' ').length, lessThanOrEqualTo(6));
      }
    });
  });

  group('the widget', () {
    test('the routine item fills the quiet moment after the step', () {
      final e = builder.build(inputs(next: water)).current;
      expect(e.slot, WidgetSlot.routineItem);
      expect(e.headline, 'Drink water');
      expect(e.subline, contains('4:00 PM'));
      expect(e.primary.id, WidgetActionId.routineDone);
      expect(e.secondary!.id, WidgetActionId.openRoutine);
      // The link names the item, so the app can log it.
      final uri = Uri.parse(e.primary.link);
      expect(parseWidgetLink(uri), WidgetLink.routineDone);
      expect(routinePayloadOf(uri), 'routine:2026-10-14:water');
      expect(parseWidgetLink(Uri.parse(e.secondary!.link)), WidgetLink.routine);
    });

    test('no plan: the routine item too', () {
      final e = builder.build(inputs(plan: false, next: water)).current;
      expect(e.slot, WidgetSlot.routineItem);
    });

    test("the coach's step always comes first", () {
      final e = builder.build(inputs(done: false, next: water)).current;
      expect(e.slot, isNot(WidgetSlot.routineItem));
    });

    test('a custom item never puts its words on the widget', () {
      final s = builder.build(inputs(next: custom, hideDetails: false));
      expect(s.current.headline, 'Your next routine step');
      expect(s.current.lockHeadline, 'A small step from your routine');
      expect(jsonEncode(s.toJson()), isNot(contains('Call mom')));
    });

    test('lock screen: generic while details are hidden', () {
      expect(
        builder.build(inputs(next: water)).current.lockHeadline,
        'A small step from your routine',
      );
      expect(
        builder
            .build(inputs(next: water, hideDetails: false))
            .current
            .lockHeadline,
        'Drink water',
      );
    });

    test('after a safety response the widget stays calm and simple', () {
      final e = builder.build(inputs(hold: true, next: water)).current;
      expect(e.slot, WidgetSlot.done);
    });
  });

  group('the weekly review', () {
    MomentBuilder moments() => MomentBuilder([
      MomentTemplate.parse(
        File('../../content/coach/moments/weekly_review.json')
            .readAsStringSync(),
      ),
    ], approvedOnly: false);

    test('mentions the routine win when there is one', () {
      for (var d = 11; d <= 18; d++) {
        final m = moments().build(
          Moment.weeklyReview,
          MomentContext(
            now: DateTime(2026, 10, d, 8),
            firstName: 'Priya',
            weeklyCount: 12,
            routineWin: 'a glass of water',
            routineWinDays: 6,
          ),
        )!;
        expect(m.text, contains('a glass of water on 6 days'), reason: '$d');
      }
    });

    test('without a win, the other lines', () {
      final m = moments().build(
        Moment.weeklyReview,
        MomentContext(now: DateTime(2026, 10, 18, 8), weeklyCount: 3),
      )!;
      expect(m.text, isNot(contains('{')));
      expect(m.text, isNot(contains('made time for')));
    });

    test('the win is approved wording, not the person\'s own words', () {
      expect(
        MomentPlaceholders.userText,
        isNot(contains(MomentPlaceholders.routineWin)),
      );
    });
  });
}
