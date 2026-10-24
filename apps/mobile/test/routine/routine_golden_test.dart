@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_editing.dart';

import '../plan/plan_screen_test.dart' show withStarterPlan;
import 'routine_screen_test.dart' show openRoutine;

/// My Daily Routine (T-GOL-03b) golden images: today with the coach's step
/// pinned, catalog and custom items, one done, and a time clash; light and
/// dark, text at 100% and 200%, on an iPhone SE. Regenerate after an
/// intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  const size = Size(750, 1334);
  const dpr = 2.0;
  RoutineItem item(
    String id,
    String label,
    String icon,
    String time,
    int minutes, {
    String? catalogId,
  }) => RoutineItem(
    itemId: id,
    routineId: myRoutineId,
    catalogId: catalogId,
    label: label,
    icon: icon,
    time: time,
    durationMin: minutes,
  );

  for (final dark in [false, true]) {
    for (final (label, scale) in [('normal', 1.0), ('large', 2.0)]) {
      final name = 'routine_se_${dark ? 'dark' : 'light'}_$label';
      testWidgets(name, (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final h = withStarterPlan();
        await h.routines.saveRoutine(
          const Routine(
            routineId: myRoutineId,
            name: 'My routine',
            days: everyDay,
          ),
        );
        for (final i in [
          item('wake', 'Wake up', 'sunrise', '07:00', 5, catalogId: 'wake_up'),
          item(
            'water',
            'Drink water',
            'water',
            '07:15',
            2,
            catalogId: 'drink_water',
          ),
          item(
            'stretch',
            'Morning stretch',
            'stretch',
            '07:15',
            5,
            catalogId: 'morning_stretch',
          ),
          item('call', 'Call mom', 'heart', '18:30', 10),
          item('bed', 'Bedtime', 'bed', '22:30', 5, catalogId: 'bedtime'),
        ]) {
          await h.routines.saveItem(i);
        }
        await h.routines.saveLog(
          const RoutineLog(
            date: '2026-10-14',
            itemId: 'wake',
            status: RoutineStatus.done,
            source: RoutineSource.app,
          ),
        );
        await h.boot(tester);
        await openRoutine(tester);
        final needed = size.height / dpr * (1.3 + (scale - 1) * 1.6);
        tester.view
          ..physicalSize = Size(size.width, needed * dpr)
          ..devicePixelRatio = dpr;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
