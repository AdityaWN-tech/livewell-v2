import 'package:flutter/material.dart' show TimeOfDay;

import '../../care/domain/chat.dart';
import '../../home/domain/home_models.dart';
import '../../learn/domain/lesson.dart';
import '../../learn/domain/portal.dart';
import '../../plan/domain/plan_models.dart';
import '../../track/domain/track_models.dart';

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

  /// 14 days, a rest day used this week (the weekly grace, FR-DLY-07).
  static const streak = StreakSummary(
    length: 14,
    best: 14,
    week: [
      StreakDay.done,
      StreakDay.done,
      StreakDay.rest,
      StreakDay.done,
      StreakDay.today,
      StreakDay.upcoming,
      StreakDay.upcoming,
    ],
  );

  /// A made-up offer; the real catalog is portal_offers (spec 13.2).
  static const offer = PortalOffer(
    id: 'sample-offer',
    title: 'Everyday Movement course',
    description: 'Short video lessons on fitting movement into a busy day.',
    url: 'https://example.com/everyday-movement',
    offerType: 'course',
    topicTags: ['movement'],
  );

  static const lessons = [
    Lesson(
      id: 'sample-1',
      category: 'Driver 1',
      title: 'Microhabits vs. willpower',
      summary: 'Why starting with 2 minutes helps a habit stick.',
      readMinutes: 3,
    ),
    Lesson(
      id: 'sample-2',
      category: 'Driver 3',
      title: 'Moving after meals',
      summary: 'Simple ways to add a short walk to your day.',
      readMinutes: 4,
    ),
    Lesson(
      id: 'sample-3',
      category: 'Driver 5',
      title: 'Winding down for sleep',
      summary: 'A calm routine for the last hour of your day.',
      readMinutes: 5,
    ),
    Lesson(
      id: 'sample-4',
      category: 'Driver 2',
      title: 'Your Why, every day',
      summary: 'Keeping your reason close when motivation dips.',
      readMinutes: 2,
    ),
  ];

  /// A sample exchange (spec Appendix C wording). The coach isn't built;
  /// staging and prod never show made-up answers.
  static const chat = [
    ChatMessage(
      author: ChatAuthor.user,
      text: 'Is walking after meals really useful?',
    ),
    ChatMessage(
      author: ChatAuthor.coach,
      text:
          'Yes. A short walk after a meal helps your body handle that meal '
          'more steadily.',
      sources: ['Book, chapter 2'],
    ),
  ];

  /// 30-day completion per driver, for the Live Well Map (T-UI-02d).
  static const driverCompletion = [0.6, 0.45, 0.7, 0.3, 0.5, 0.25, 0.4, 0.35];

  static const goal = PlanGoal(
    title: 'Feel more energetic every day',
    day: 12,
    progress: 0.4,
  );

  /// The week ahead (calendar button), day 9 first.
  static const week = [
    WeekDay(
      dayNumber: 9,
      date: '2026-10-14',
      title: '10-min walk after lunch',
      minutes: 10,
    ),
    WeekDay(
      dayNumber: 10,
      date: '2026-10-15',
      title: 'Stretch for 5 minutes after waking',
      minutes: 5,
    ),
    WeekDay(
      dayNumber: 11,
      date: '2026-10-16',
      title: '10-min walk after lunch',
      minutes: 10,
    ),
    WeekDay(
      dayNumber: 12,
      date: '2026-10-17',
      title: 'Glass of water before each meal',
      minutes: 2,
    ),
    WeekDay(
      dayNumber: 13,
      date: '2026-10-18',
      title: '15-min walk with a friend',
      minutes: 10,
    ),
    WeekDay(
      dayNumber: 14,
      date: '2026-10-19',
      title: 'A slow, easy walk',
      minutes: 5,
    ),
    WeekDay(
      dayNumber: 15,
      date: '2026-10-20',
      title: 'Look back on your week',
      minutes: 5,
    ),
  ];
}
