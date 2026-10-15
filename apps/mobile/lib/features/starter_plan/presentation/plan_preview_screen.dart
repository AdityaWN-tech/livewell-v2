import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/flavor.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../focus/domain/focus.dart';
import '../application/plan_scheduler.dart';
import '../data/plan_repository.dart';
import '../data/reminders.dart';
import '../domain/starter_plan.dart';
import '../domain/touchpoints.dart';

/// Generic reminder texts (no personal or health details, AGENTS.md).
ReminderTexts reminderTexts(AppLocalizations l) => ReminderTexts(
  greetingTitle: l.reminderGreetingTitle,
  greetingBody: l.reminderGreetingBody,
  nudgeTitle: l.reminderNudgeTitle,
  nudgeBody: l.reminderNudgeBody,
  reflectionTitle: l.reminderReflectionTitle,
  reflectionBody: l.reminderReflectionBody,
  channelName: l.reminderChannel,
);

/// "Your 7 days" (T-ONB-03e): the rule-based starter plan with its 3 daily
/// touchpoints, then "Start my plan" (reminders are asked for here).
class PlanPreviewScreen extends ConsumerStatefulWidget {
  const PlanPreviewScreen({super.key});

  @override
  ConsumerState<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends ConsumerState<PlanPreviewScreen> {
  StarterPlan? _plan;
  bool _notReady = false;
  bool _busy = false;
  TouchpointTimes _times = const TouchpointTimes();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  Future<void> _build() async {
    final l = AppLocalizations.of(context);
    final uid = ref.read(authServiceProvider).currentUser!.uid;
    final templates = await ref.read(planTemplatesProvider.future);
    // Only approved templates outside dev (pending ones are for review).
    if (!templatesUsable(
      isDev: ref.read(flavorProvider) == Flavor.dev,
      t: templates.all,
    )) {
      if (mounted) setState(() => _notReady = true);
      return;
    }
    final profile = await ref.read(profileRepositoryProvider).get(uid);
    final now = ref.read(clockProvider)();
    final checkIn = await ref
        .read(checkInRepositoryProvider)
        .watchDay(localDateKey(now))
        .first;
    final focus = [
      for (final id in profile?.focusChoices ?? const <String>[])
        ?FocusArea.byId(id),
    ];
    final plan = StarterPlanGenerator.generate(
      start: now,
      focus: focus.isEmpty ? [FocusArea.healthyRoutine] : focus,
      minutes: checkIn?.timeAvailable,
      gentleToday: checkIn?.gentleDay ?? false,
      activityLimited: profile?.activityLimited ?? false,
      templates: templates.byFocus,
      limited: templates.limited,
      gentleReason: l.homeStepGentleReason,
    );
    final times = await ref.read(planRepositoryProvider).loadTimes();
    if (mounted) {
      setState(() {
        _plan = plan;
        _times = times;
      });
    }
  }

  Future<void> _editTime(TouchpointKind k) async {
    final l = AppLocalizations.of(context);
    final current = _times.of(k);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    final t = ClockTime(picked.hour, picked.minute);
    if (PlanScheduler.quiet.contains(t)) {
      String fmt(ClockTime c) =>
          MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay(hour: c.hour, minute: c.minute));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.planQuietHours(
              fmt(PlanScheduler.quiet.start),
              fmt(PlanScheduler.quiet.end),
            ),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _times = _times.copyWith(k, t));
  }

  /// Ask once: the in-app reason first, then the OS prompt. The answer is
  /// recorded either way (FR-ONB-03).
  Future<void> _askReminders() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(consentRepositoryProvider);
    final current = currentConsents(await repo.watchRecords().first);
    if (current.containsKey(ConsentType.notifications) || !mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.planReminderTitle),
        content: Text(l.planReminderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.planReminderNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.planReminderAllow),
          ),
        ],
      ),
    );
    final granted =
        allow == true && await ref.read(remindersProvider).requestPermission();
    await repo.record(ConsentType.notifications, granted: granted);
  }

  Future<void> _start() async {
    final plan = _plan;
    if (plan == null) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _askReminders();
      await ref.read(planRepositoryProvider).save(plan, _times);
      if (!mounted) return;
      await ref.read(planSchedulerProvider).reschedule(reminderTexts(l));
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref
          .read(profileRepositoryProvider)
          .setStep(uid, ProfileStep.assessment);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.planSaveError)));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _skipNotReady() async {
    final uid = ref.read(authServiceProvider).currentUser!.uid;
    await ref
        .read(profileRepositoryProvider)
        .setStep(uid, ProfileStep.assessment);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final ml = MaterialLocalizations.of(context);
    String time(ClockTime c) =>
        ml.formatTimeOfDay(TimeOfDay(hour: c.hour, minute: c.minute));
    final plan = _plan;

    Widget body;
    if (_notReady) {
      body = ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(l.planPreviewTitle, style: t.displaySmall),
          const SizedBox(height: LwSpacing.md),
          Text(
            l.planNotReady,
            key: const Key('plan-not-ready'),
            style: t.bodyLarge,
          ),
          const SizedBox(height: LwSpacing.lg),
          FilledButton(
            onPressed: _skipNotReady,
            child: Text(l.planNotReadyContinue),
          ),
        ],
      );
    } else if (plan == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final moments = [
        (TouchpointKind.greeting, l.planMorning, Icons.wb_sunny_outlined),
        (TouchpointKind.nudge, l.planMidday, Icons.directions_walk),
        (TouchpointKind.reflection, l.planEvening, Icons.nightlight_outlined),
      ];
      body = Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(LwSpacing.screenGutter),
              children: [
                Semantics(
                  header: true,
                  child: Text(l.planPreviewTitle, style: t.displaySmall),
                ),
                const SizedBox(height: LwSpacing.xs),
                Text(l.planPreviewBody, style: t.bodyMedium),
                const SizedBox(height: LwSpacing.lg),
                Text(l.planTouchpoints, style: t.titleSmall),
                const SizedBox(height: LwSpacing.xs),
                Card(
                  child: Column(
                    children: [
                      for (final (kind, name, icon) in moments)
                        Semantics(
                          button: true,
                          container: true,
                          excludeSemantics: true,
                          label: l.planTimeLabel(name, time(_times.of(kind))),
                          child: ListTile(
                            key: Key('plan-time-${kind.name}'),
                            leading: Icon(icon, color: p.primary),
                            title: Text(name),
                            trailing: Text(
                              time(_times.of(kind)),
                              style: t.labelLarge?.copyWith(
                                color: p.accentStrong,
                              ),
                            ),
                            onTap: () => _editTime(kind),
                          ),
                        ),
                    ],
                  ),
                ),
                if (plan.supporting.isNotEmpty) ...[
                  const SizedBox(height: LwSpacing.lg),
                  Text(l.planAlsoThisWeek, style: t.titleSmall),
                  const SizedBox(height: LwSpacing.xs),
                  for (final s in plan.supporting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LwSpacing.xxs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: LwSize.iconSm,
                            color: p.success,
                          ),
                          const SizedBox(width: LwSpacing.xs),
                          Expanded(child: Text(s.title, style: t.bodyLarge)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: LwSpacing.lg),
                for (final d in plan.days) ...[
                  _DayCard(day: d),
                  const SizedBox(height: LwSpacing.xs),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('plan-start'),
                onPressed: _busy ? null : _start,
                child: Text(l.planStart),
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(body: SafeArea(child: body));
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});
  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    final date = DateTime.parse(day.date);
    final ml = MaterialLocalizations.of(context);
    return Card(
      key: Key('plan-day-${day.dayNumber}'),
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: LwSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l.planDay(day.dayNumber).toUpperCase(),
                  style: t.labelSmall?.copyWith(color: p.accentStrong),
                ),
                Text(ml.formatMediumDate(date), style: t.labelSmall),
                Text('· ${day.anchor}', style: t.labelSmall),
              ],
            ),
            const SizedBox(height: LwSpacing.xxs),
            Text(day.title, style: t.titleMedium),
            if (day.gentle)
              Text(l.planGentle, style: t.bodySmall)
            else if (day.smallerTitle != null)
              Text(l.planSmaller(day.smallerTitle!), style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
