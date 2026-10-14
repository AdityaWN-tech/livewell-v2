import 'package:flutter/material.dart' show TimeOfDay;

import '../../home/domain/home_models.dart';
import '../../plan/domain/plan_models.dart';

/// Sample data shown only in the dev preview (dev flavour only; AGENTS.md:
/// no fake data in staging or prod). Lets the design be reviewed before the
/// plan, streak and profile data exist.
///
/// Driver labels are numbers only: Dr. Gokula's driver names aren't in the
/// content files yet (needs-product).
abstract final class PreviewSamples {
  static const firstName = 'Priya';
  static const day = 9;

  static const step = TodayStep(
    driver: 'Driver 3',
    title: '10-min walk after lunch',
    reason: 'A short walk after a meal can help you feel less tired later.',
    minutes: 10,
    smallerTitle: '5-min walk after lunch',
    smallerMinutes: 5,
  );

  static const milestone = Milestone(
    phase: 1,
    phaseCount: 3,
    habitsKept: 7,
    habitsPlanned: 9,
  );

  /// A full plan: 1 microhabit + 2 supporting habits (FR-GOL-01).
  static const habits = [
    PlanHabit(
      id: 'sample-water',
      role: HabitRole.supporting,
      driver: 'Driver 2',
      title: 'Glass of water with breakfast',
      status: HabitStatus.done,
      completedAt: TimeOfDay(hour: 8, minute: 15),
    ),
    PlanHabit(
      id: 'sample-walk',
      role: HabitRole.microhabit,
      driver: 'Driver 3',
      title: '10-min walk after lunch',
      status: HabitStatus.inProgress,
      target: TimeOfDay(hour: 13, minute: 30),
      microstep: 'Put your walking shoes on now',
      minutes: 10,
    ),
    PlanHabit(
      id: 'sample-screens',
      role: HabitRole.supporting,
      driver: 'Driver 5',
      title: 'Screens off at 10:30 PM',
      status: HabitStatus.scheduled,
      target: TimeOfDay(hour: 22, minute: 30),
      microstep: 'Dim the bedroom lights and read for 10 minutes',
      minutes: 10,
    ),
  ];
}
