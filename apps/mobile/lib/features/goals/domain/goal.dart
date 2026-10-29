/// The 30-day goal and the person's own supporting habits (FR-GOL-01/02,
/// Step 4a, D-53). Stored as users/{uid}/goals/primary,
/// users/{uid}/habits/support_1|support_2 and users/{uid}/habit_logs.
/// The fixed ids are the limits: one goal, at most two own habits, so the
/// server rules enforce FR-GOL-01 too.
library;

/// Typed words are kept short (and checked by the label rules, D-46).
const goalTextMaxLength = 60;
const barrierPlanMaxLength = 120;
const habitTitleMaxLength = 40;

enum GoalStatus { active, paused }

/// When in the day a habit happens (the anchor of FR-GOL-02).
enum HabitAnchor { wakeUp, breakfast, lunch, dinner, bedtime }

/// The SMART 30-day goal (Blueprint 6.4): action, how often, how long, the
/// anchor event, the barrier plan and the link to the person's Why.
class Goal {
  const Goal({
    required this.action,
    required this.daysPerWeek,
    required this.minutes,
    required this.anchor,
    this.barrierPlan = '',
    this.linkWhy = true,
    this.status = GoalStatus.active,
    required this.startDate,
  });

  static const id = 'primary';
  static const days = 30;
  static const minuteChoices = [2, 5, 10, 15, 20, 30];

  final String action;

  /// 1..7.
  final int daysPerWeek;
  final int minutes;
  final HabitAnchor anchor;

  /// "If it rains, I'll walk indoors." Optional.
  final String barrierPlan;

  /// Show the person's Why with the goal.
  final bool linkWhy;
  final GoalStatus status;

  /// yyyy-mm-dd, day 1. Restarting sets it to today.
  final String startDate;

  bool get isValid =>
      action.trim().isNotEmpty &&
      action.length <= goalTextMaxLength &&
      barrierPlan.length <= barrierPlanMaxLength &&
      daysPerWeek >= 1 &&
      daysPerWeek <= 7 &&
      minuteChoices.contains(minutes) &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(startDate);

  /// Day X of 30 on [today] (yyyy-mm-dd), from 1, at most 30.
  int dayOn(String today) {
    final start = DateTime.parse(startDate);
    final now = DateTime.parse(today);
    return (now.difference(start).inDays + 1).clamp(1, days);
  }

  /// How far through the 30 days (0..1).
  double progressOn(String today) => dayOn(today) / days;

  Goal copyWith({
    String? action,
    int? daysPerWeek,
    int? minutes,
    HabitAnchor? anchor,
    String? barrierPlan,
    bool? linkWhy,
    GoalStatus? status,
    String? startDate,
  }) => Goal(
    action: action ?? this.action,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    minutes: minutes ?? this.minutes,
    anchor: anchor ?? this.anchor,
    barrierPlan: barrierPlan ?? this.barrierPlan,
    linkWhy: linkWhy ?? this.linkWhy,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
  );

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.action == action &&
      other.daysPerWeek == daysPerWeek &&
      other.minutes == minutes &&
      other.anchor == anchor &&
      other.barrierPlan == barrierPlan &&
      other.linkWhy == linkWhy &&
      other.status == status &&
      other.startDate == startDate;

  @override
  int get hashCode => Object.hash(
    action,
    daysPerWeek,
    minutes,
    anchor,
    barrierPlan,
    linkWhy,
    status,
    startDate,
  );
}

/// A supporting habit the person added (FR-GOL-01). Stopping it sets
/// [active] to false; nothing is deleted.
class UserHabit {
  const UserHabit({
    required this.id,
    required this.title,
    required this.anchor,
    required this.minutes,
    this.active = true,
  });

  /// The only ids there are: two own habits at most.
  static const ids = ['support_1', 'support_2'];
  static const minuteChoices = [2, 5, 10, 15];

  final String id;
  final String title;
  final HabitAnchor anchor;
  final int minutes;
  final bool active;

  bool get isValid =>
      ids.contains(id) &&
      title.trim().isNotEmpty &&
      title.length <= habitTitleMaxLength &&
      minuteChoices.contains(minutes);

  UserHabit copyWith({
    String? title,
    HabitAnchor? anchor,
    int? minutes,
    bool? active,
  }) => UserHabit(
    id: id,
    title: title ?? this.title,
    anchor: anchor ?? this.anchor,
    minutes: minutes ?? this.minutes,
    active: active ?? this.active,
  );
}

/// A habit marked done on a day. Idempotent: the id is date_habitId.
/// The habit id of the coach's daily step (today's plan step) in
/// habit_logs (D-60). The two own habits use [UserHabit.ids].
const dailyStepHabitId = 'daily_step';

class HabitLog {
  const HabitLog({required this.date, required this.habitId, this.doneAt});

  final String date;
  final String habitId;

  /// When it was ticked (shown as "Completed at").
  final DateTime? doneAt;

  String get id => '${date}_$habitId';
}

/// The first free slot for a new own habit, or null when there's no room.
/// [taken] counts every supporting habit shown today (the plan's and the
/// person's): FR-GOL-01 allows two in all.
String? freeHabitSlot(Iterable<UserHabit> own, int taken) {
  if (taken >= UserHabit.ids.length) return null;
  final used = {
    for (final h in own)
      if (h.active) h.id,
  };
  return UserHabit.ids.where((id) => !used.contains(id)).firstOrNull;
}
