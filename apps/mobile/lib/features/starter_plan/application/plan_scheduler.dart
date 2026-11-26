import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../home/application/home_data.dart'
    show coachNameProvider, repeatedPlanDay, stepProgressProvider;
import '../../routine/data/routine_repository.dart'
    show routineRepositoryProvider;
import '../data/notification_names.dart';
import '../../moments/data/coach_faces.dart';
import '../../routine/application/routine_moment.dart';
import '../data/plan_repository.dart';
import '../data/reminders.dart';
import '../domain/daily_cap.dart';
import '../domain/touchpoints.dart';

/// Keeps the plan's reminders in step with the plan, the touchpoint times,
/// the notification consent and the device's time zone.
class PlanScheduler {
  PlanScheduler(this._ref);

  final Ref _ref;

  /// Default quiet hours; Profile > Daily plan can change them.
  static const quiet = QuietHours();

  Future<bool> _consent() async => isGranted(
    currentConsents(
      await _ref.read(consentRepositoryProvider).watchRecords().first,
    ),
    ConsentType.notifications,
  );

  /// Replaces all scheduled reminders. Without the notification consent
  /// everything is cancelled; the plan still works in the app.
  Future<void> reschedule(ReminderTexts texts) async {
    final reminders = _ref.read(remindersProvider);
    if (!await _consent()) {
      await reminders.cancelAll();
      return;
    }
    final plans = _ref.read(planRepositoryProvider);
    final now = _ref.read(clockProvider)();
    // The plan's saved days; once the starter plan has ended (the step
    // repeats, D-109), the next 7 days too, so reminders go on. Nobody who
    // never had a plan gets plan reminders.
    final saved = await plans.datesFrom(localDateKey(now));
    final repeats = await repeatedPlanDay(plans, now) != null;
    final dates = {
      ...saved,
      if (repeats)
        for (var d = 0; d < 7; d++)
          localDateKey(DateTime(now.year, now.month, now.day + d)),
    }.toList()..sort();
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    final settings = uid == null
        ? const <String, dynamic>{}
        : (await _ref.read(profileRepositoryProvider).get(uid))?.settings ??
              const <String, dynamic>{};
    final quiet = QuietHours.fromMap(
      settings[ProfileSettings.quietHours] as Map<String, dynamic>?,
    );
    // "Not today" (T-DLY-03e): that moment's reminder is off for the day.
    final notToday = NotToday.fromMap(
      settings[ProfileSettings.notToday] as Map<String, dynamic>?,
    );
    // Today's step reminder is dropped once the step is done (TCH-e).
    final stepDone = _ref.read(stepProgressProvider).done;
    final doneNudge = TouchpointScheduler.idFor(now, TouchpointKind.nudge);
    final items = notToday.filter([
      for (final i in TouchpointScheduler.build(
        days: [for (final d in dates) DateTime.parse(d)],
        times: await plans.loadTimes(),
        quiet: quiet,
        consent: true,
        now: now,
        enabled: enabledFromMap(
          settings[ProfileSettings.notificationCategories]
              as Map<String, dynamic>?,
        ),
      ))
        if (!(stepDone && i.id == doneNudge)) i,
    ]);
    // My Daily Routine (T-GOL-03d): its own category and cap, same quiet
    // hours, scheduled in the same pass so neither wipes the other.
    final routine = await routineRemindersFor(
      _ref,
      now: now,
      settings: settings,
      quiet: quiet,
    );
    // One cap of 4 a day across plan and routine together (T-DLY-04,
    // FR-TCH-01, D-71): the plan's touchpoints first, then routine
    // reminders, earliest first; today's already shown ones count.
    final ledgers = _ref.read(reminderLedgerStoreProvider);
    final before = await ledgers.load();
    final capped = capPerDay(
      plan: items,
      routine: routine,
      used: {localDateKey(now): before?.shownBy(now).length ?? 0},
    );
    final faces = capped.plan.isEmpty && capped.routine.isEmpty
        ? const <TouchpointKind, String>{}
        : await _faces();
    await reminders.replaceAll(
      capped.plan,
      texts,
      faces: faces,
      routine: capped.routine,
      names: await _taskNames(plans, capped),
    );
    await ledgers.save(ReminderLedger.next(before, now, capped));
    await _ref.read(reminderZoneStoreProvider).save(await reminders.timeZone());
  }

  /// Task names for the step and single routine reminders, only when the
  /// person turned "Show task names in notifications" on (D-111). A custom
  /// routine item's own words are never used (as on the widget).
  Future<Map<int, String>> _taskNames(
    PlanRepository plans,
    CappedReminders capped,
  ) async {
    // The loaded value only: never wait on storage here (off until loaded).
    final on = _ref.read(notificationNamesProvider).value ?? false;
    if (!on) return const {};
    final names = <int, String>{};
    for (final i in capped.plan) {
      if (i.kind != TouchpointKind.nudge) continue;
      final date = localDateKey(i.when);
      final day =
          await plans.watchDay(date).first ??
          await repeatedPlanDay(plans, i.when);
      if (day != null) names[i.id] = day.title;
    }
    if (capped.routine.isNotEmpty) {
      final items = {
        for (final it
            in await _ref.read(routineRepositoryProvider).watchItems().first)
          it.itemId: it,
      };
      for (final r in capped.routine) {
        if (r.itemIds.length != 1) continue;
        final it = items[r.itemIds.single];
        if (it != null && !it.custom && it.label.isNotEmpty) {
          names[r.id] = it.label;
        }
      }
    }
    return names;
  }

  /// The coach's face per reminder: its frames on the device, else the
  /// initial circle (T-AVT-08a).
  Future<Map<TouchpointKind, String>> _faces() async {
    await _ref.read(coachChoiceProvider.future);
    final name = _ref.read(coachNameProvider) ?? 'Coach';
    return _ref
        .read(coachFacesProvider)
        .render(
          frames: await _ref.read(ownFrameSetProvider.future),
          initial: name.isEmpty ? '' : name.characters.first.toUpperCase(),
          background: _ref.read(coachBackgroundProvider),
        );
  }

  /// Today's morning reminder leaves the tray once its moment was played
  /// in the app (T-DLY-03c).
  Future<void> dismissMorning() => _ref
      .read(remindersProvider)
      .dismiss(
        TouchpointScheduler.idFor(
          _ref.read(clockProvider)(),
          TouchpointKind.greeting,
        ),
      );

  /// After travel the wall-clock times must follow the new zone, so a
  /// change of time zone reschedules everything.
  Future<bool> rescheduleIfZoneChanged(ReminderTexts texts) async {
    final zone = await _ref.read(remindersProvider).timeZone();
    final saved = await _ref.read(reminderZoneStoreProvider).load();
    if (saved == null || saved == zone) return false;
    await reschedule(texts);
    return true;
  }
}

final planSchedulerProvider = Provider<PlanScheduler>(PlanScheduler.new);
