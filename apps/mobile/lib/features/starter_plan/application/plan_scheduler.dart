import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../moments/data/coach_faces.dart';
import '../data/plan_repository.dart';
import '../data/reminders.dart';
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
    final dates = await plans.datesFrom(localDateKey(now));
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    final settings = uid == null
        ? const <String, dynamic>{}
        : (await _ref.read(profileRepositoryProvider).get(uid))?.settings ??
              const <String, dynamic>{};
    final items = TouchpointScheduler.build(
      days: [for (final d in dates) DateTime.parse(d)],
      times: await plans.loadTimes(),
      quiet: QuietHours.fromMap(
        settings[ProfileSettings.quietHours] as Map<String, dynamic>?,
      ),
      consent: true,
      now: now,
      enabled: enabledFromMap(
        settings[ProfileSettings.notificationCategories]
            as Map<String, dynamic>?,
      ),
    );
    final faces = items.isEmpty
        ? const <TouchpointKind, String>{}
        : await _ref
              .read(coachFacesProvider)
              .render(await _ref.read(coachAvatarConfigProvider.future));
    await reminders.replaceAll(items, texts, faces: faces);
    await _ref.read(reminderZoneStoreProvider).save(await reminders.timeZone());
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
