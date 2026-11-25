import '../../../l10n/app_localizations.dart';
import '../../avatar/application/coach_job_watcher.dart' show CoachNoticeTexts;
import '../../starter_plan/presentation/plan_preview_screen.dart'
    show reminderTexts;
import '../application/push_registrar.dart';

/// The generic words a push shows while the app is open (T-TCH-01): the
/// local reminders' and the coach notice's own lines.
PushTexts pushTexts(AppLocalizations l) => PushTexts(
  reminders: reminderTexts(l),
  coach: CoachNoticeTexts(
    readyTitle: l.coachNoticeReadyTitle,
    readyBody: l.coachNoticeReadyBody,
    notMadeTitle: l.coachNoticeNotMadeTitle,
    notMadeBody: l.coachNoticeNotMadeBody,
    channelName: l.coachNoticeChannel,
  ),
);
