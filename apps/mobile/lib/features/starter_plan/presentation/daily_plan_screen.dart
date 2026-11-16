import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/illustrated.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../moments/application/moment_context.dart'
    show coachVoiceSpeedProvider;
import '../../moments/application/moment_playback.dart';
import '../../moments/application/moment_preview.dart';
import '../../moments/domain/coach_message.dart';
import '../../moments/presentation/moment_screen.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show reminderTimesProvider;
import '../../routine/domain/routine_reminders.dart';
import '../../voice/data/voice_repository.dart';
import '../../voice/domain/voice.dart';
import '../application/plan_scheduler.dart';
import '../data/plan_repository.dart';
import '../domain/touchpoints.dart';
import 'plan_preview_screen.dart' show reminderTexts;

/// Profile > Daily plan (T-DLY-03e, AVT-08h): the moment times with "Not
/// today", quiet hours and the per-moment switches (moved here from
/// Profile, not duplicated), how moments play (speak automatically, voice
/// speed, captions), a preview of tomorrow's morning, and the widget guide.
class DailyPlanScreen extends ConsumerStatefulWidget {
  const DailyPlanScreen({super.key});

  static const path = '/profile/daily-plan';

  @override
  ConsumerState<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends ConsumerState<DailyPlanScreen> {
  /// The slider's value while it is dragged; saved when let go.
  double? _speed;

  String? get _uid => ref.read(authServiceProvider).currentUser?.uid;

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _fmt(ClockTime c) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: c.hour, minute: c.minute));

  Future<void> _save(Map<String, Object> fields) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(profileRepositoryProvider).updateSettings(uid, fields);
    ref.invalidate(currentProfileProvider);
  }

  /// Every change to times, quiet hours or switches goes through the one
  /// scheduler, so caps and quiet hours always apply.
  Future<void> _reschedule() async {
    try {
      await ref
          .read(planSchedulerProvider)
          .reschedule(reminderTexts(AppLocalizations.of(context)));
    } catch (_) {
      // Reminders are best effort; the settings are saved.
    }
  }

  Future<ClockTime?> _pickTime(ClockTime current) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    return t == null ? null : ClockTime(t.hour, t.minute);
  }

  /// A moment's time. A time inside quiet hours is refused with a clear
  /// message (conservative: nothing is moved silently).
  Future<void> _editTime(TouchpointKind k, QuietHours quiet) async {
    if (_uid == null) return;
    final l = AppLocalizations.of(context);
    final plans = ref.read(planRepositoryProvider);
    final times = await plans.loadTimes();
    final t = await _pickTime(times.of(k));
    if (t == null || !mounted) return;
    if (quiet.contains(t)) {
      _say(l.planQuietHours(_fmt(quiet.start), _fmt(quiet.end)));
      return;
    }
    await plans.saveTimes(times.copyWith(k, t));
    ref.invalidate(reminderTimesProvider);
    await _reschedule();
    if (mounted) _say(l.profileSaved);
  }

  Future<void> _editQuiet(QuietHours quiet, {required bool start}) async {
    if (_uid == null) return;
    final t = await _pickTime(start ? quiet.start : quiet.end);
    if (t == null) return;
    final next = start
        ? QuietHours(start: t, end: quiet.end)
        : QuietHours(start: quiet.start, end: t);
    await _save({ProfileSettings.quietHours: next.toMap()});
    await _reschedule();
  }

  Future<void> _toggleCategory(
    Set<TouchpointKind> enabled,
    TouchpointKind k,
    bool on,
  ) async {
    final next = {...enabled};
    on ? next.add(k) : next.remove(k);
    await _save({ProfileSettings.notificationCategories: enabledToMap(next)});
    await _reschedule();
  }

  Future<void> _notToday(
    NotToday current,
    TouchpointKind k,
    String name, {
    required bool off,
  }) async {
    if (_uid == null) return;
    final l = AppLocalizations.of(context);
    final next = current.toggle(ref.read(clockProvider)(), k, off: off);
    await _save({ProfileSettings.notToday: next.toMap()});
    await _reschedule();
    if (mounted && off) _say(l.dailyPlanNotTodayDone(name.toLowerCase()));
  }

  /// "Routine reminders per day" (T-GOL-03d): 0 (off) to 10.
  Future<void> _setRoutinePerDay(int n) async {
    await _save({ProfileSettings.routineRemindersPerDay: n});
    await _reschedule();
  }

  Future<void> _setPlayback(MomentPlayback p) =>
      _save({ProfileSettings.momentPlayback: p.toMap()});

  /// Voice speed: saved with the chosen voice, the one place the player,
  /// the lesson reader and the Studio read it from.
  Future<void> _saveSpeed(double v) async {
    final voices = ref.read(voiceRepositoryProvider);
    try {
      final choice = await voices.current() ?? VoiceChoice.fallback;
      await voices.choose(choice.copyWith(speed: v));
    } catch (_) {
      if (mounted) setState(() => _speed = null);
      return;
    }
    ref.invalidate(coachVoiceSpeedProvider);
  }

  Future<void> _preview() async {
    final l = AppLocalizations.of(context);
    final (message, block) = await ref.read(morningPreviewProvider.future);
    if (!mounted) return;
    if (message == null) {
      _say(
        block == PreviewBlock.safetyHold
            ? l.dailyPlanPreviewPaused
            : l.dailyPlanPreviewNone,
      );
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Whatever button is tapped in a preview, nothing happens: it closes.
    await Navigator.of(context).push<MomentAction>(
      MaterialPageRoute(
        builder: (_) => MomentScreen(moment: Moment.morning, preview: message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final signedIn = ref.watch(signedInUidProvider) != null;
    final settings =
        ref.watch(currentProfileProvider).value?.settings ??
        const <String, dynamic>{};
    final quiet = QuietHours.fromMap(
      settings[ProfileSettings.quietHours] as Map<String, dynamic>?,
    );
    final enabled = enabledFromMap(
      settings[ProfileSettings.notificationCategories] as Map<String, dynamic>?,
    );
    final notToday = NotToday.fromMap(
      settings[ProfileSettings.notToday] as Map<String, dynamic>?,
    );
    final today = ref.watch(clockProvider)();
    final playback = ref.watch(momentPlaybackProvider);
    final times =
        ref.watch(reminderTimesProvider).value ?? const TouchpointTimes();
    final speed =
        _speed ??
        ref.watch(coachVoiceSpeedProvider).value ??
        VoiceChoice.fallback.speed;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: LwSpacing.lg, bottom: LwSpacing.xs),
      child: Semantics(header: true, child: Text(text, style: t.titleSmall)),
    );

    final moments = [
      (TouchpointKind.greeting, l.planMorning),
      (TouchpointKind.nudge, l.planMidday),
      (TouchpointKind.reflection, l.planEvening),
    ];

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            LwPageTitle(l.profileDailyPlan),
            Text(l.dailyPlanIntro, style: t.bodyMedium),
            if (!signedIn) ...[
              const SizedBox(height: LwSpacing.md),
              Text(l.notificationsSignedOut, style: t.bodyLarge),
            ] else ...[
              // ---- Moment times ----
              header(l.dailyPlanTimesHeader),
              Card(
                child: Column(
                  children: [
                    for (final (k, name) in moments)
                      _MomentRow(
                        kind: k,
                        name: name,
                        time: _fmt(times.of(k)),
                        on: enabled.contains(k),
                        skippedToday: notToday.skips(today, k),
                        inQuiet: quiet.contains(times.of(k)),
                        onToggle: (on) => _toggleCategory(enabled, k, on),
                        onEditTime: () => _editTime(k, quiet),
                        onNotToday: (off) =>
                            _notToday(notToday, k, name, off: off),
                      ),
                  ],
                ),
              ),

              // ---- Quiet hours and routine reminders ----
              header(l.dailyPlanQuietHeader),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('plan-quiet-start'),
                      leading: const Icon(Icons.bedtime_outlined),
                      title: Text(l.profileQuietStart),
                      trailing: Text(_fmt(quiet.start), style: t.labelLarge),
                      onTap: () => _editQuiet(quiet, start: true),
                    ),
                    ListTile(
                      key: const Key('plan-quiet-end'),
                      leading: const Icon(Icons.wb_twilight_outlined),
                      title: Text(l.profileQuietEnd),
                      trailing: Text(_fmt(quiet.end), style: t.labelLarge),
                      onTap: () => _editQuiet(quiet, start: false),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: Text(l.profileRoutineReminders),
                      trailing: DropdownButton<int>(
                        key: const Key('plan-routine-reminders'),
                        value: routineRemindersPerDay(
                          settings[ProfileSettings.routineRemindersPerDay],
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (n) =>
                            n == null ? null : _setRoutinePerDay(n),
                        items: [
                          for (var n = 0; n <= routineRemindersMax; n++)
                            DropdownMenuItem(
                              value: n,
                              child: Text(
                                n == 0 ? l.profileRoutineRemindersOff : '$n',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ---- How moments play ----
              header(l.dailyPlanCoachHeader),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const Key('plan-auto-speak'),
                      title: Text(l.dailyPlanAutoSpeak),
                      subtitle: playback.autoSpeak
                          ? null
                          : Text(l.dailyPlanTextOnly),
                      value: playback.autoSpeak,
                      onChanged: (on) =>
                          _setPlayback(playback.copyWith(autoSpeak: on)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        LwSpacing.md,
                        LwSpacing.xs,
                        LwSpacing.md,
                        0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(l.voiceSpeed, style: t.bodyLarge),
                          ),
                          Text(
                            l.voiceSpeedValue(speed.toStringAsFixed(1)),
                            key: const Key('plan-speed-value'),
                            style: t.labelLarge,
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      key: const Key('plan-speed'),
                      min: VoiceChoice.minSpeed,
                      max: VoiceChoice.maxSpeed,
                      divisions: 4,
                      value: speed
                          .clamp(VoiceChoice.minSpeed, VoiceChoice.maxSpeed)
                          .toDouble(),
                      label: l.voiceSpeedValue(speed.toStringAsFixed(1)),
                      onChanged: (v) => setState(() => _speed = v),
                      onChangeEnd: _saveSpeed,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LwSpacing.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l.dailyPlanSpeedNote, style: t.bodySmall),
                      ),
                    ),
                    SwitchListTile(
                      key: const Key('plan-captions'),
                      title: Text(l.dailyPlanCaptions),
                      subtitle: Text(
                        playback.captions
                            ? l.dailyPlanCaptionsOn
                            : l.dailyPlanCaptionsOff,
                      ),
                      value: playback.captions,
                      onChanged: (on) =>
                          _setPlayback(playback.copyWith(captions: on)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LwSpacing.md),
              // The screen's one primary action (spec 4.1).
              FilledButton.icon(
                key: const Key('plan-preview'),
                onPressed: _preview,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.dailyPlanPreview),
              ),
            ],

            // ---- Widget guide (AVT-08g/h) ----
            header(l.dailyPlanWidgetHeader),
            LwPastelCard(
              key: const Key('plan-widget-guide'),
              tint: p.mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.widgets_outlined, color: p.accentStrong),
                      const SizedBox(width: LwSpacing.xs),
                      Expanded(
                        child: Text(
                          l.dailyPlanWidgetTitle,
                          style: t.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LwSpacing.xs),
                  Text(l.dailyPlanWidgetBody, style: t.bodyMedium),
                  const SizedBox(height: LwSpacing.xs),
                  // The phone's own steps first.
                  for (final step
                      in Theme.of(context).platform == TargetPlatform.iOS
                          ? [l.dailyPlanWidgetIos, l.dailyPlanWidgetAndroid]
                          : [l.dailyPlanWidgetAndroid, l.dailyPlanWidgetIos])
                    Padding(
                      padding: const EdgeInsets.only(top: LwSpacing.xxs),
                      child: Text(step, style: t.bodySmall),
                    ),
                  const SizedBox(height: LwSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: LwSize.iconSm,
                        color: p.textSecondary,
                      ),
                      const SizedBox(width: LwSpacing.xs),
                      Expanded(
                        child: Text(
                          l.dailyPlanWidgetPrivate,
                          key: const Key('plan-widget-private'),
                          style: t.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: LwSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// One moment: its switch, its time (tap to change) and "Not today".
class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.kind,
    required this.name,
    required this.time,
    required this.on,
    required this.skippedToday,
    required this.inQuiet,
    required this.onToggle,
    required this.onEditTime,
    required this.onNotToday,
  });

  final TouchpointKind kind;
  final String name;
  final String time;
  final bool on;
  final bool skippedToday;
  final bool inQuiet;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditTime;
  final ValueChanged<bool> onNotToday;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: Key('plan-touchpoint-${kind.name}'),
          title: Text(name),
          value: on,
          onChanged: onToggle,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.xs,
            0,
            LwSpacing.md,
            LwSpacing.xs,
          ),
          child: Wrap(
            spacing: LwSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                button: true,
                label: l.dailyPlanChangeTime(name.toLowerCase()),
                excludeSemantics: true,
                child: TextButton.icon(
                  key: Key('plan-time-${kind.name}'),
                  onPressed: onEditTime,
                  icon: const Icon(Icons.schedule, size: LwSize.iconSm),
                  label: Text(
                    time,
                    style: t.labelLarge?.copyWith(color: p.accentStrong),
                  ),
                ),
              ),
              if (on)
                FilterChip(
                  key: Key('plan-not-today-${kind.name}'),
                  label: Text(l.dailyPlanNotToday),
                  selected: skippedToday,
                  onSelected: onNotToday,
                ),
            ],
          ),
        ),
        if (on && inQuiet)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LwSpacing.md,
              0,
              LwSpacing.md,
              LwSpacing.sm,
            ),
            child: Text(
              l.dailyPlanInQuiet,
              key: Key('plan-in-quiet-${kind.name}'),
              style: t.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}
