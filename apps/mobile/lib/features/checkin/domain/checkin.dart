/// Daily check-in (T-DLY-02, FR-DLY-02): mood first, the rest optional.
library;

/// One day's check-in (users/{uid}/checkins/{yyyy-mm-dd}).
class CheckIn {
  const CheckIn({
    required this.date,
    required this.mood,
    this.energy,
    this.sleep,
    this.stress,
    this.timeAvailable,
    this.barrierText,
    required this.gentleDay,
    this.createdAt,
  });

  /// Local date key, yyyy-mm-dd.
  final String date;

  /// 1 Very low .. 5 Great. Required.
  final int mood;
  final int? energy;
  final int? sleep;

  /// 1 Not at all .. 5 Very.
  final int? stress;

  /// Minutes: 2, 5, 10 or 30.
  final int? timeAvailable;
  final String? barrierText;

  /// Low mood, high stress or a red flag: no portal card today (spec 15.3),
  /// and Home uses the gentle message.
  final bool gentleDay;

  /// Kept unchanged when the same day is re-submitted.
  final DateTime? createdAt;

  /// Questions answered, for the analytics count (never the values).
  int get stepsAnswered => [
    mood,
    energy,
    sleep,
    stress,
    timeAvailable,
    (barrierText?.trim().isEmpty ?? true) ? null : barrierText,
  ].where((v) => v != null).length;
}

/// Minutes offered for "How much time do you have today?" (FR-DLY-02).
const timeOptions = [2, 5, 10, 30];

/// "What could make today hard?" stays short (rules allow 140).
const barrierMaxLength = 140;

/// Low mood or high stress makes a gentle day (T-DLY-02). The security
/// rules enforce the same floor.
bool isGentleDay({required int mood, int? stress}) =>
    mood <= 2 || (stress != null && stress >= 4);

/// yyyy-mm-dd of a local time. "Today" always follows the device's time
/// zone, so travelling changes the day with the clock (FR-TRV).
String localDateKey(DateTime local) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
}

/// Ask once per local day: not if today's check-in exists, and not again
/// today after the sheet was shown (even if it was closed).
bool shouldAskToday({
  required String today,
  required bool hasCheckinToday,
  required String? lastAskedDay,
}) => !hasCheckinToday && lastAskedDay != today;

/// Which supportive line Home shows after the check-in.
enum CheckInTone { high, steady, gentle }

CheckInTone toneFor(CheckIn c) {
  if (c.gentleDay) return CheckInTone.gentle;
  return c.mood >= 4 ? CheckInTone.high : CheckInTone.steady;
}

/// Why today is a gentle day, so the wording fits (T-UI-02c). [other] is a
/// red flag in the note (D-24) with mood and stress in range: the neutral
/// wording, never a guess.
enum GentleReason { lowMood, highStress, both, other }

GentleReason? gentleReasonFor(CheckIn c) {
  if (!c.gentleDay) return null;
  final low = c.mood <= 2;
  final stressed = c.stress != null && c.stress! >= 4;
  if (low && stressed) return GentleReason.both;
  if (low) return GentleReason.lowMood;
  if (stressed) return GentleReason.highStress;
  return GentleReason.other;
}
