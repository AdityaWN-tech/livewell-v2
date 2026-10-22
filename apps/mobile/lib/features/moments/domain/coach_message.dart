/// Avatar Moments (T-DLY-03): the coach delivers each touchpoint of the day.
library;

/// The moments of the day (T-DLY-03 table).
enum Moment {
  morning,
  stepReminder,
  stepDone,
  evening,
  gentle,
  missedDay,
  weeklyReview;

  /// The template file name in content/coach/moments.
  String get file => switch (this) {
    Moment.morning => 'morning',
    Moment.stepReminder => 'step_reminder',
    Moment.stepDone => 'step_done',
    Moment.evening => 'evening',
    Moment.gentle => 'gentle',
    Moment.missedDay => 'missed_day',
    Moment.weeklyReview => 'weekly_review',
  };

  static Moment? byFile(String name) =>
      Moment.values.where((m) => m.file == name).firstOrNull;
}

/// The avatar's expression for a moment (CoachMessage `emotion`).
enum CoachEmotion { waving, happy, encouraging, calm, listening, celebrating }

/// What the buttons under a moment do.
enum MomentAction {
  checkIn,
  startStep,
  makeSmaller,
  done,
  notToday,
  close,
  reply,
  restart,
  seeWeek;

  static MomentAction? byName(String name) => switch (name) {
    'check_in' => MomentAction.checkIn,
    'start_step' => MomentAction.startStep,
    'make_smaller' => MomentAction.makeSmaller,
    'done' => MomentAction.done,
    'not_today' => MomentAction.notToday,
    'close' => MomentAction.close,
    'reply' => MomentAction.reply,
    'restart' => MomentAction.restart,
    'see_week' => MomentAction.seeWeek,
    _ => null,
  };
}

/// One message from the coach (spec 9.5 CoachMessage), built from an
/// approved template (T-DLY-03a).
class CoachMessage {
  const CoachMessage({
    required this.messageId,
    required this.moment,
    required this.text,
    required this.emotion,
    required this.primaryAction,
    required this.secondaryActions,
    required this.containsUserText,
    required this.approved,
  });

  /// "{moment}.{variant}@v{version}": which template line this is. The
  /// voice layer only speaks text that carries an approved message_id
  /// (closed-script rule, FR-VOC-05).
  final String messageId;
  final Moment moment;
  final String text;
  final CoachEmotion emotion;
  final MomentAction primaryAction;
  final List<MomentAction> secondaryActions;

  /// True when the text includes words the person typed (their first name
  /// or Why). A cloned voice must not speak those words (FR-VOC-05); the
  /// player (T-DLY-03b) uses a library voice or the text for them.
  final bool containsUserText;

  /// The template is clinically approved (prod uses approved only).
  final bool approved;
}
