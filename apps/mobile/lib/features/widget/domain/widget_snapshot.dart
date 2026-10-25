import '../../starter_plan/domain/touchpoints.dart';

/// What the home-screen widget shows now (T-AVT-08g, T-TCH-02): one thing
/// to do, delivered by the coach.
enum WidgetSlot {
  morningCheckIn('morning_checkin'),
  step('step'),
  stepWindow('step_window'),
  done('done'),
  evening('evening'),
  gentle('gentle'),

  /// My Daily Routine's next item (T-GOL-03e), when the coach's step is
  /// done or there is no plan: the coach's step always comes first.
  routineItem('routine_item'),
  none('none'),
  signedOut('signed_out');

  const WidgetSlot(this.id);
  final String id;
}

/// What a widget button does. Each opens a screen through its link; Done
/// is also logged by the widget itself on iOS 17+ and Android 12+
/// (native PRs), else it opens the app.
enum WidgetActionId {
  checkIn('check_in', 'livewell://checkin'),
  openStep('open_step', 'livewell://step'),
  makeSmaller('make_smaller', 'livewell://step?smaller=1'),
  done('done', 'livewell://step?done=1'),
  reflect('reflect', 'livewell://reflection'),
  openHome('open_home', 'livewell://home'),
  // T-GOL-03e: the link also names the item (see WidgetAction.link).
  routineDone('routine_done', 'livewell://routine?done=1'),
  openRoutine('open_routine', 'livewell://routine');

  const WidgetActionId(this.id, this.link);
  final String id;
  final String link;
}

class WidgetAction {
  const WidgetAction(this.id, this.label, {this.linkOverride});

  final WidgetActionId id;
  final String label;

  /// The action's own link when it carries more (a routine item's Done).
  final String? linkOverride;

  String get link => linkOverride ?? id.link;

  Map<String, Object?> toJson() => {'id': id.id, 'label': label, 'link': link};
}

/// The routine item the widget can show (T-GOL-03e). [label] is null for a
/// custom item: the person's own words never go to the widget.
class WidgetRoutineItem {
  const WidgetRoutineItem({
    required this.payload,
    required this.time,
    this.label,
  });

  /// "routine:date:itemId", carried by the Done link.
  final String payload;

  /// The time to show, already formatted ("9:00 AM").
  final String time;
  final String? label;
}

enum RoutineStatus { todo, done }

/// One point on the day's timeline: from [at] the widget shows this.
class WidgetEntry {
  const WidgetEntry({
    required this.at,
    required this.slot,
    required this.expression,
    required this.headline,
    required this.lockHeadline,
    required this.primary,
    this.subline,
    this.secondary,
  });

  final DateTime at;
  final WidgetSlot slot;

  /// The coach's face: an [AvatarExpression] name (its thumbnail).
  final String expression;
  final String headline;
  final String? subline;

  /// For the lock screen: generic unless the person turned details on.
  final String lockHeadline;
  final WidgetAction primary;
  final WidgetAction? secondary;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'slot': slot.id,
    'expression': expression,
    'headline': headline,
    'subline': subline,
    'lock_headline': lockHeadline,
    'primary_action': primary.toJson(),
    'secondary_action': secondary?.toJson(),
  };
}

/// Everything the native widgets read (through the App Group on iOS and
/// shared storage on Android). **Only these fields, ever**: never mood,
/// energy, sleep, stress, health values, reflection text or other free
/// text (AGENTS.md; a test fails if a field is added).
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.firstName,
    required this.avatarThumbs,
    required this.streakDays,
    required this.routine,
    required this.entries,
    required this.afterDone,
    required this.routineLabels,
    required this.hideDetails,
    required this.updatedAt,
  });

  final String? firstName;

  /// PNG face per expression name (T-AVT-08d thumbnails or the initial
  /// circle); copied into the shared container by the native side.
  final Map<String, String> avatarThumbs;
  final int? streakDays;

  /// Morning (check-in), step, evening (reflection): never "missed".
  final Map<String, RoutineStatus> routine;

  /// Now first, then the rest of today and the next midnight, so the widget
  /// changes on time without the app running.
  final List<WidgetEntry> entries;

  /// What to show right after Done is tapped on the widget itself (iOS
  /// 17+, Android 12+), until the app has caught up; null when Done isn't
  /// offered today.
  final WidgetEntry? afterDone;

  /// The routine row's words: morning, step, evening.
  final Map<String, String> routineLabels;

  /// "Hide details on lock screen" (on by default).
  final bool hideDetails;
  final DateTime updatedAt;

  WidgetEntry get current => entries.first;

  static const version = 1;

  Map<String, Object?> toJson() => {
    'version': version,
    'first_name': firstName,
    'avatar_thumbs': avatarThumbs,
    'streak_days': streakDays,
    'routine': {for (final e in routine.entries) e.key: e.value.name},
    'entries': [for (final e in entries) e.toJson()],
    'after_done': afterDone?.toJson(),
    'routine_labels': routineLabels,
    'hide_details': hideDetails,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// The day's state the widget is built from. Deliberately has no field for
/// check-in answers: only whether the check-in happened and whether today
/// is a gentle day.
class WidgetInputs {
  const WidgetInputs({
    required this.now,
    required this.signedIn,
    this.firstName,
    this.stepTitle,
    this.smallerTitle,
    this.checkedIn = false,
    this.gentleDay = false,
    this.safetyHold = false,
    this.stepDone = false,
    this.smaller = false,
    this.reflected = false,
    this.times = const TouchpointTimes(),
    this.streakDays,
    this.avatarThumbs = const {},
    this.hideDetails = true,
    this.nextRoutine,
  });

  final DateTime now;
  final bool signedIn;
  final String? firstName;

  /// Today's step from the plan; null when there is no plan.
  final String? stepTitle;
  final String? smallerTitle;
  final bool checkedIn;
  final bool gentleDay;

  /// A safety response today: the coach stays calm (T-AVT-08f).
  final bool safetyHold;
  final bool stepDone;
  final bool smaller;
  final bool reflected;
  final TouchpointTimes times;
  final int? streakDays;
  final Map<String, String> avatarThumbs;
  final bool hideDetails;

  /// Today's next routine item, if any (T-GOL-03e).
  final WidgetRoutineItem? nextRoutine;
}
