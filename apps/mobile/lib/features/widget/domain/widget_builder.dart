import '../../starter_plan/domain/touchpoints.dart';
import 'widget_snapshot.dart';

/// The widget's words, from the app's approved copy (the ARB file).
class WidgetTexts {
  const WidgetTexts({
    required this.goodMorning,
    required this.goodMorningNamed,
    required this.checkInSub,
    required this.shorterOption,
    required this.timeFor,
    required this.dayN,
    required this.doneHeadline,
    required this.doneSub,
    required this.evening,
    required this.gentleSub,
    required this.noPlan,
    required this.signedOut,
    required this.lockNext,
    required this.lockReady,
    required this.lockDone,
    required this.checkIn,
    required this.start,
    required this.makeSmaller,
    required this.done,
    required this.reflect,
    required this.open,
    required this.routineMorning,
    required this.routineStep,
    required this.routineEvening,
    required this.routineNext,
    required this.routineCustom,
    required this.routineAt,
    required this.lockRoutine,
    required this.routineOpen,
  });

  final String goodMorning;
  final String Function(String name) goodMorningNamed;
  final String checkInSub;
  final String Function(String smaller) shorterOption;
  final String Function(String step) timeFor;
  final String Function(int days) dayN;
  final String doneHeadline;
  final String doneSub;
  final String evening;
  final String gentleSub;
  final String noPlan;
  final String signedOut;
  final String Function(String step) lockNext;
  final String lockReady;
  final String lockDone;
  final String checkIn;
  final String start;
  final String makeSmaller;
  final String done;
  final String reflect;
  final String open;
  final String routineMorning;
  final String routineStep;
  final String routineEvening;

  // My Daily Routine (T-GOL-03e).
  final String routineNext;
  final String routineCustom;
  final String Function(String time) routineAt;
  final String lockRoutine;
  final String routineOpen;
}

/// Builds the widget snapshot: one recommendation now, and what it turns
/// into at each touchpoint time for the rest of the day (FR-TCH-01..04).
class WidgetSnapshotBuilder {
  const WidgetSnapshotBuilder(this.t);

  final WidgetTexts t;

  WidgetSnapshot build(WidgetInputs i) {
    final entries = <WidgetEntry>[_entry(i, i.now)];
    final today = DateTime(i.now.year, i.now.month, i.now.day);
    DateTime at(ClockTime c) =>
        today.add(Duration(hours: c.hour, minutes: c.minute));
    for (final when in [
      at(i.times.morning),
      at(i.times.midday),
      at(i.times.evening),
    ]) {
      if (!when.isAfter(i.now)) continue;
      final e = _entry(i, when);
      if (e.slot != entries.last.slot) entries.add(e);
    }
    // A new day: the morning check-in, nothing done yet.
    final midnight = today.add(const Duration(days: 1));
    entries.add(
      _entry(
        WidgetInputs(
          now: midnight,
          signedIn: i.signedIn,
          firstName: i.firstName,
          // Tomorrow's step isn't known yet; the app refreshes it.
          stepTitle: i.stepTitle == null ? null : '',
          times: i.times,
          streakDays: i.streakDays,
          avatarThumbs: i.avatarThumbs,
          hideDetails: i.hideDetails,
        ),
        midnight,
      ),
    );
    return WidgetSnapshot(
      firstName: i.signedIn ? i.firstName : null,
      avatarThumbs: i.signedIn ? i.avatarThumbs : const {},
      streakDays: i.signedIn ? i.streakDays : null,
      routine: {
        'morning': i.checkedIn ? RoutineStatus.done : RoutineStatus.todo,
        'step': i.stepDone ? RoutineStatus.done : RoutineStatus.todo,
        'evening': i.reflected ? RoutineStatus.done : RoutineStatus.todo,
      },
      entries: entries,
      afterDone: !i.signedIn || i.stepTitle == null || i.stepDone
          ? null
          : _entry(_doneNow(i), i.now),
      routineLabels: {
        'morning': t.routineMorning,
        'step': t.routineStep,
        'evening': t.routineEvening,
      },
      hideDetails: i.hideDetails,
      updatedAt: i.now,
    );
  }

  /// Today's state once Done is tapped: the streak counts today.
  static WidgetInputs _doneNow(WidgetInputs i) => WidgetInputs(
    now: i.now,
    signedIn: i.signedIn,
    firstName: i.firstName,
    stepTitle: i.stepTitle,
    smallerTitle: i.smallerTitle,
    checkedIn: i.checkedIn,
    gentleDay: i.gentleDay,
    safetyHold: i.safetyHold,
    stepDone: true,
    smaller: i.smaller,
    // Before the evening; in the evening the widget still asks to reflect.
    reflected: true,
    times: i.times,
    streakDays: (i.streakDays ?? 0) + 1,
    avatarThumbs: i.avatarThumbs,
    hideDetails: i.hideDetails,
    nextRoutine: i.nextRoutine,
  );

  /// Which slot it is at [when], given today's state.
  static WidgetSlot slotAt(WidgetInputs i, DateTime when) {
    final slot = _coachSlotAt(i, when);
    // The routine's next item fills a quiet moment (T-GOL-03e); never
    // after a safety response, when the widget stays calm and simple.
    if ((slot == WidgetSlot.done || slot == WidgetSlot.none) &&
        i.nextRoutine != null &&
        !i.safetyHold) {
      return WidgetSlot.routineItem;
    }
    return slot;
  }

  static WidgetSlot _coachSlotAt(WidgetInputs i, DateTime when) {
    if (!i.signedIn) return WidgetSlot.signedOut;
    if (i.stepTitle == null) return WidgetSlot.none;
    final t = ClockTime(when.hour, when.minute);
    if (t.compareTo(i.times.evening) >= 0 && !i.reflected) {
      return WidgetSlot.evening;
    }
    if (i.stepDone) return WidgetSlot.done;
    if (!i.checkedIn && t.compareTo(i.times.midday) < 0) {
      return WidgetSlot.morningCheckIn;
    }
    if (i.gentleDay || i.safetyHold) return WidgetSlot.gentle;
    if (t.compareTo(i.times.midday) >= 0) return WidgetSlot.stepWindow;
    return WidgetSlot.step;
  }

  WidgetEntry _entry(WidgetInputs i, DateTime when) {
    final slot = slotAt(i, when);
    final name = i.firstName?.trim();
    final step = i.smaller || slot == WidgetSlot.gentle
        ? (i.smallerTitle ?? i.stepTitle ?? '')
        : (i.stepTitle ?? '');
    final lockStep = i.hideDetails || step.isEmpty
        ? t.lockReady
        : t.lockNext(step);
    WidgetAction a(WidgetActionId id, String label) => WidgetAction(id, label);
    final (
      expression,
      headline,
      subline,
      lock,
      primary,
      secondary,
    ) = switch (slot) {
      WidgetSlot.morningCheckIn => (
        'waving',
        name == null || name.isEmpty ? t.goodMorning : t.goodMorningNamed(name),
        t.checkInSub,
        lockStep,
        a(WidgetActionId.checkIn, t.checkIn),
        null,
      ),
      WidgetSlot.step => (
        'happy',
        step,
        i.smaller || i.smallerTitle == null
            ? null
            : t.shorterOption(i.smallerTitle!),
        lockStep,
        a(WidgetActionId.openStep, t.start),
        i.smaller || i.smallerTitle == null
            ? null
            : a(WidgetActionId.makeSmaller, t.makeSmaller),
      ),
      WidgetSlot.stepWindow => (
        'happy',
        t.timeFor(step),
        null,
        lockStep,
        a(WidgetActionId.done, t.done),
        a(WidgetActionId.openStep, t.start),
      ),
      WidgetSlot.gentle => (
        // Calm: never smiling after a safety response (T-AVT-08f).
        'calm',
        step,
        t.gentleSub,
        lockStep,
        a(WidgetActionId.openStep, t.start),
        null,
      ),
      WidgetSlot.done => (
        i.safetyHold ? 'calm' : 'celebrating',
        (i.streakDays ?? 0) > 0 ? t.dayN(i.streakDays!) : t.doneHeadline,
        t.doneSub,
        t.lockDone,
        a(WidgetActionId.openHome, t.open),
        null,
      ),
      WidgetSlot.evening => (
        i.safetyHold ? 'calm' : 'listening',
        t.evening,
        null,
        t.evening,
        a(WidgetActionId.reflect, t.reflect),
        null,
      ),
      WidgetSlot.routineItem => (
        'happy',
        i.nextRoutine!.label ?? t.routineCustom,
        '${t.routineNext} · ${t.routineAt(i.nextRoutine!.time)}',
        // Generic on the lock screen when details are hidden, and always
        // for a custom item.
        i.hideDetails || i.nextRoutine!.label == null
            ? t.lockRoutine
            : i.nextRoutine!.label!,
        WidgetAction(
          WidgetActionId.routineDone,
          t.done,
          linkOverride:
              '${WidgetActionId.routineDone.link}'
              '&r=${Uri.encodeQueryComponent(i.nextRoutine!.payload)}',
        ),
        a(WidgetActionId.openRoutine, t.routineOpen),
      ),
      WidgetSlot.none => (
        'happy',
        t.noPlan,
        null,
        t.noPlan,
        a(WidgetActionId.openHome, t.open),
        null,
      ),
      WidgetSlot.signedOut => (
        'happy',
        t.signedOut,
        null,
        t.signedOut,
        a(WidgetActionId.openHome, t.open),
        null,
      ),
    };
    return WidgetEntry(
      at: when,
      slot: slot,
      expression: expression,
      headline: headline,
      subline: subline,
      lockHeadline: lock,
      primary: primary,
      secondary: secondary,
    );
  }
}
