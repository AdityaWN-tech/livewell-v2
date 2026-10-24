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
  openHome('open_home', 'livewell://home');

  const WidgetActionId(this.id, this.link);
  final String id;
  final String link;
}

class WidgetAction {
  const WidgetAction(this.id, this.label);

  final WidgetActionId id;
  final String label;

  Map<String, Object?> toJson() => {
    'id': id.id,
    'label': label,
    'link': id.link,
  };
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
}
