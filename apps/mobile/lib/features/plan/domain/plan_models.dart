import 'package:flutter/material.dart' show TimeOfDay;

/// The one daily microhabit, or one of up to two supporting habits
/// (FR-GOL-01).
enum HabitRole { microhabit, supporting }

/// Today's status of a habit, shown as words (never colour alone).
enum HabitStatus { done, inProgress, scheduled }

/// A habit as the Plan tab shows it for today.
class PlanHabit {
  const PlanHabit({
    required this.id,
    required this.role,
    required this.driver,
    required this.title,
    required this.status,
    this.target,
    this.microstep,
    this.minutes,
    this.completedAt,
  });

  final String id;
  final HabitRole role;

  /// Driver label from the goal, for example "Driver 3".
  final String driver;
  final String title;
  final HabitStatus status;

  /// Planned time of day (the habit's window start).
  final TimeOfDay? target;

  /// The tiny first action ("Put your walking shoes on now").
  final String? microstep;
  final int? minutes;
  final TimeOfDay? completedAt;

  PlanHabit copyWith({HabitStatus? status, TimeOfDay? completedAt}) =>
      PlanHabit(
        id: id,
        role: role,
        driver: driver,
        title: title,
        status: status ?? this.status,
        target: target,
        microstep: microstep,
        minutes: minutes,
        completedAt: completedAt ?? this.completedAt,
      );
}

/// FR-GOL-01: 1 daily microhabit and up to 2 supporting habits. Enforced in
/// the UI here; the API enforces it again when habits can be created.
abstract final class HabitLimits {
  static const microhabits = 1;
  static const supporting = 2;

  static int count(List<PlanHabit> habits, HabitRole role) =>
      habits.where((h) => h.role == role).length;

  /// Whether another habit of [role] fits.
  static bool canAdd(List<PlanHabit> habits, HabitRole role) =>
      count(habits, role) <
      (role == HabitRole.microhabit ? microhabits : supporting);

  /// No room for any new habit.
  static bool isFull(List<PlanHabit> habits) =>
      !canAdd(habits, HabitRole.microhabit) &&
      !canAdd(habits, HabitRole.supporting);
}

/// The 30-day goal card (T-UI-02d).
class PlanGoal {
  const PlanGoal({
    required this.title,
    required this.day,
    required this.progress,
  });

  final String title;

  /// Day X of 30.
  final int day;

  /// 0..1.
  final double progress;

  static const days = 30;
}

/// One day of the week view (calendar button).
class WeekDay {
  const WeekDay({
    required this.dayNumber,
    required this.date,
    required this.title,
    required this.minutes,
  });

  final int dayNumber;

  /// YYYY-MM-DD.
  final String date;
  final String title;
  final int minutes;
}

/// One of the 8 drivers on the Live Well Map.
class Driver {
  const Driver({required this.index, required this.label});

  /// 0..7, fixed order.
  final int index;
  final String label;
}
