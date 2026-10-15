import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../data/plan_repository.dart';
import '../data/reminders.dart';
import '../domain/touchpoints.dart';

/// Keeps the plan's reminders in step with the plan, the touchpoint times,
/// the notification consent and the device's time zone.
class PlanScheduler {
  PlanScheduler(this._ref);

  final Ref _ref;

  /// Default quiet hours until they can be edited in Profile (ONB-03f).
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
    final items = TouchpointScheduler.build(
      days: [for (final d in dates) DateTime.parse(d)],
      times: await plans.loadTimes(),
      quiet: quiet,
      consent: true,
      now: now,
    );
    await reminders.replaceAll(items, texts);
    await _ref.read(reminderZoneStoreProvider).save(await reminders.timeZone());
  }

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
