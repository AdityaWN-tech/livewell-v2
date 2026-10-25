import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../studio/presentation/studio_screen.dart';
import '../../studio/presentation/studio_widgets.dart' show StudioTab;
import '../../../core/config/flavor.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../auth/domain/auth.dart';
import '../../auth/presentation/auth_copy.dart';
import '../../home/application/home_data.dart';
import '../../routine/domain/routine_reminders.dart';
import '../../starter_plan/application/plan_scheduler.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../starter_plan/domain/touchpoints.dart';
import '../../starter_plan/presentation/plan_preview_screen.dart'
    show reminderTexts;
import '../data/account_actions.dart';
import '../data/appearance.dart';
import 'profile_button.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/domain/coach_choice.dart';
import '../../avatar/presentation/coach_avatar.dart' show coachChoiceProvider;

final _versionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Profile (T-ONB-03f, FR-SET-01..03): account, my coach, appearance, daily
/// plan, privacy & data, help, and (dev flavour only) developer tools.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AuthUser? get _user => ref.read(authServiceProvider).currentUser;

  /// Only called after [_signedIn] checks; the dev preview has no account.
  String get _uid => _user!.uid;
  bool get _signedIn => _user != null;

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).profileCancel),
            ),
            FilledButton(
              key: const Key('confirm-action'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _askText({
    required String title,
    required String hint,
    String? initial,
    String? Function(String)? validate,
  }) {
    final c = TextEditingController(text: initial);
    final l = AppLocalizations.of(context);
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(title),
          content: TextField(
            key: const Key('profile-text'),
            controller: c,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(hintText: hint, errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.profileCancel),
            ),
            FilledButton(
              key: const Key('profile-text-save'),
              onPressed: () {
                final v = c.text.trim();
                final e = validate?.call(v);
                if (e != null) {
                  setDialog(() => error = e);
                  return;
                }
                Navigator.pop(context, v);
              },
              child: Text(l.profileSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reschedule() async {
    try {
      await ref
          .read(planSchedulerProvider)
          .reschedule(reminderTexts(AppLocalizations.of(context)));
    } catch (_) {
      // Reminders are best effort; the settings are saved.
    }
  }

  Future<void> _photo() async {
    final l = AppLocalizations.of(context);
    final hasPhoto = ref.read(profilePhotoProvider).value != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.profileTakePhoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.profileChoosePhoto),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l.profileRemovePhoto),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final store = ref.read(profilePhotoStoreProvider);
    if (choice == 'remove') {
      await store.remove();
    } else {
      await store.pick(camera: choice == 'camera');
    }
    ref.invalidate(profilePhotoProvider);
  }

  Future<void> _editName() async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    final name = await _askText(
      title: l.profileEditName,
      hint: l.profileNameHint,
      initial: ref.read(firstNameProvider),
      validate: (v) => v.isEmpty ? l.profileCoachNameError : null,
    );
    if (name == null) return;
    await ref.read(profileRepositoryProvider).updateSettings(_uid, {
      ProfileSettings.displayName: name,
    });
    ref.invalidate(currentProfileProvider);
    if (mounted) _say(l.profileSaved);
  }

  Future<void> _toggleLink(SocialProvider p, bool linked) async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    final auth = ref.read(authServiceProvider);
    try {
      if (linked) {
        await auth.unlink(p);
      } else {
        await auth.link(p);
      }
      if (mounted) setState(() {});
    } on AuthException catch (e) {
      if (mounted) showAuthMessage(context, authErrorText(l, e.failure));
    }
  }

  Future<void> _logOut() async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    if (!await _confirm(
      l.profileLogOutTitle,
      l.profileLogOutBody,
      l.profileLogOut,
    )) {
      return;
    }
    await ref.read(accountActionsProvider).logOut();
    if (mounted) context.go('/sign-in');
  }

  /// The Avatar & Voice Studio (T-UI-02h), on the avatar or voice tab.
  Future<void> _openStudio(StudioTab tab) async {
    // A message from before must not cover the next screen's button.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StudioScreen(initialTab: tab)),
    );
  }

  Future<void> _coachName() async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    final name = await _askText(
      title: l.profileCoachName,
      hint: l.profileCoachNameHint,
      initial: ref.read(coachNameProvider),
      validate: (v) =>
          RegExp(r"^[\p{L}][\p{L} '\-]{0,19}$", unicode: true).hasMatch(v)
          ? null
          : l.profileCoachNameError,
    );
    if (name == null) return;
    // Saved with the avatar (T-AVT-08b).
    final avatars = ref.read(avatarRepositoryProvider);
    final choice = await avatars.load() ?? CoachChoice.fallback;
    await avatars.save(choice.copyWith(coachName: CoachChoice.cleanName(name)));
    ref.invalidate(coachChoiceProvider);
    if (mounted) _say(l.profileSaved);
  }

  Future<ClockTime?> _pickTime(ClockTime current) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    return t == null ? null : ClockTime(t.hour, t.minute);
  }

  Future<void> _editTouchpoint(TouchpointKind k, QuietHours quiet) async {
    if (!_signedIn) return;
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
    await _reschedule();
    if (mounted) setState(() {});
  }

  Future<void> _editQuiet(QuietHours quiet, {required bool start}) async {
    if (!_signedIn) return;
    final t = await _pickTime(start ? quiet.start : quiet.end);
    if (t == null) return;
    final next = start
        ? QuietHours(start: t, end: quiet.end)
        : QuietHours(start: quiet.start, end: t);
    await ref.read(profileRepositoryProvider).updateSettings(_uid, {
      ProfileSettings.quietHours: next.toMap(),
    });
    ref.invalidate(currentProfileProvider);
    await _reschedule();
  }

  /// "Routine reminders per day" (T-GOL-03d): 0 (off) to 10.
  Future<void> _setRoutinePerDay(int n) async {
    if (!_signedIn) return;
    await ref.read(profileRepositoryProvider).updateSettings(_uid, {
      ProfileSettings.routineRemindersPerDay: n,
    });
    ref.invalidate(currentProfileProvider);
    await _reschedule();
  }

  Future<void> _toggleCategory(
    Set<TouchpointKind> enabled,
    TouchpointKind k,
    bool on,
  ) async {
    if (!_signedIn) return;
    final next = {...enabled};
    on ? next.add(k) : next.remove(k);
    await ref.read(profileRepositoryProvider).updateSettings(_uid, {
      ProfileSettings.notificationCategories: enabledToMap(next),
    });
    ref.invalidate(currentProfileProvider);
    await _reschedule();
  }

  Future<void> _delete(String what) async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    final (title, body) = switch (what) {
      'avatar' => (l.profileDeleteAvatar, l.profileDeleteAvatarBody),
      'voice' => (l.profileDeleteVoice, l.profileDeleteVoiceBody),
      _ => (l.profileDeleteAccount, l.profileDeleteAccountBody),
    };
    if (!await _confirm(title, body, l.profileDeleteConfirm)) return;
    try {
      switch (what) {
        case 'avatar':
          await ref.read(deletionsProvider).deleteAvatar();
        case 'voice':
          await ref.read(deletionsProvider).deleteVoice();
        default:
          await ref.read(accountActionsProvider).deleteAccount();
          if (mounted) context.go('/welcome');
          return;
      }
      if (mounted) _say(l.profileDeleted);
    } catch (_) {
      if (mounted) _say(l.profileDeleteFailed);
    }
  }

  String _fmt(ClockTime c) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay(hour: c.hour, minute: c.minute));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final user = _user;
    final profile = ref.watch(currentProfileProvider).value;
    final settings = profile?.settings ?? const <String, dynamic>{};
    final appearance = ref.watch(appearanceProvider);
    final quiet = QuietHours.fromMap(
      settings[ProfileSettings.quietHours] as Map<String, dynamic>?,
    );
    final enabled = enabledFromMap(
      settings[ProfileSettings.notificationCategories] as Map<String, dynamic>?,
    );
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    final providers = user?.providers ?? const <String>[];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: LwSpacing.lg, bottom: LwSpacing.xs),
      child: Semantics(header: true, child: Text(text, style: t.titleSmall)),
    );

    Widget soon(String key, String title, IconData icon) => ListTile(
      key: Key(key),
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(l.profileSoon),
    );

    final moments = [
      (TouchpointKind.greeting, l.planMorning),
      (TouchpointKind.nudge, l.planMidday),
      (TouchpointKind.reflection, l.planEvening),
    ];

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          LwPageTitle(l.profileTitle),
          // ---- Header ----
          Row(
            children: [
              const ProfilePicture(radius: LwSize.avatarSm),
              const SizedBox(width: LwSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.watch(firstNameProvider) ?? l.profileAddName,
                      key: const Key('profile-name'),
                      style: ref.watch(firstNameProvider) == null
                          ? t.titleLarge?.copyWith(
                              color: LwPalette.of(context).textSecondary,
                            )
                          : t.titleLarge,
                    ),
                    // One line, ending in "..." rather than breaking the
                    // address mid-word (T-UI-02 phone bug).
                    if (user?.email != null)
                      Text(
                        user!.email!,
                        key: const Key('profile-email'),
                        style: t.bodySmall,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (user?.phoneNumber != null)
                      Text(user!.phoneNumber!, style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LwSpacing.sm),
          Text(l.profileSignedInWith, style: t.labelSmall),
          const SizedBox(height: LwSpacing.xxs),
          Wrap(
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xxs,
            children: [
              for (final (id, label) in [
                ('password', l.profileMethodEmail),
                ('phone', l.profileMethodPhone),
                ('google.com', 'Google'),
                ('apple.com', 'Apple'),
              ])
                if (providers.contains(id))
                  Chip(key: Key('method-$id'), label: Text(label)),
            ],
          ),

          // ---- Account ----
          header(l.profileAccount),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('profile-photo'),
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(l.profileChangePhoto),
                  subtitle: Text(l.profilePhotoNote),
                  onTap: _photo,
                ),
                ListTile(
                  key: const Key('profile-edit-name'),
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l.profileEditName),
                  subtitle: Text(
                    ref.watch(firstNameProvider) ?? l.profileAddName,
                  ),
                  onTap: _editName,
                ),
                for (final sp in SocialProvider.values)
                  ListTile(
                    key: Key('profile-link-${sp.name}'),
                    leading: Icon(
                      providers.contains(sp.providerId)
                          ? Icons.link
                          : Icons.add_link,
                    ),
                    title: Text(
                      providers.contains(sp.providerId)
                          ? l.profileUnlink(sp.brandName)
                          : l.profileLink(sp.brandName),
                    ),
                    onTap: () =>
                        _toggleLink(sp, providers.contains(sp.providerId)),
                  ),
                if (!providers.contains('phone'))
                  soon(
                    'profile-link-phone',
                    // "Coming soon" is the subtitle; never twice (phone bug).
                    l.profileLinkPhone,
                    Icons.phone_iphone,
                  ),
                ListTile(
                  key: const Key('profile-switch'),
                  leading: const Icon(Icons.switch_account_outlined),
                  title: Text(l.profileSwitch),
                  onTap: _logOut,
                ),
                ListTile(
                  key: const Key('profile-logout'),
                  leading: const Icon(Icons.logout),
                  title: Text(l.profileLogOut),
                  onTap: _logOut,
                ),
              ],
            ),
          ),

          // ---- My coach ----
          header(l.profileMyCoach),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('profile-avatar'),
                  leading: const Icon(Icons.face_outlined),
                  title: Text(l.profileChangeAvatar),
                  onTap: () => _openStudio(StudioTab.coaches),
                ),
                ListTile(
                  key: const Key('profile-voice'),
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text(l.profileChangeVoice),
                  onTap: () => _openStudio(StudioTab.voice),
                ),
                ListTile(
                  key: const Key('profile-coach-name'),
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.profileCoachName),
                  subtitle: Text(
                    ref.watch(coachNameProvider) ?? l.homeCoachDefaultName,
                  ),
                  onTap: _coachName,
                ),
              ],
            ),
          ),

          // ---- Appearance ----
          header(l.profileAppearance),
          SegmentedButton<ThemeMode>(
            key: const Key('profile-theme'),
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l.profileThemeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l.profileThemeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l.profileThemeDark),
              ),
            ],
            selected: {appearance.theme},
            onSelectionChanged: (s) => ref
                .read(appearanceProvider.notifier)
                .set(appearance.copyWith(theme: s.single)),
          ),
          const SizedBox(height: LwSpacing.sm),
          Text(l.profileTextSize, style: t.labelMedium),
          const SizedBox(height: LwSpacing.xxs),
          SegmentedButton<double>(
            key: const Key('profile-text-size'),
            segments: [
              ButtonSegment(value: 1.0, label: Text(l.profileTextNormal)),
              ButtonSegment(value: 1.15, label: Text(l.profileTextLarger)),
              ButtonSegment(value: 1.3, label: Text(l.profileTextLargest)),
            ],
            selected: {appearance.textScale},
            onSelectionChanged: (s) => ref
                .read(appearanceProvider.notifier)
                .set(appearance.copyWith(textScale: s.single)),
          ),

          // ---- Daily plan ----
          header(l.profileDailyPlan),
          Card(
            child: FutureBuilder<TouchpointTimes>(
              future: ref.read(planRepositoryProvider).loadTimes(),
              builder: (context, snap) {
                final times = snap.data ?? const TouchpointTimes();
                return Column(
                  children: [
                    for (final (k, name) in moments)
                      SwitchListTile(
                        key: Key('profile-touchpoint-${k.name}'),
                        title: Text(name),
                        subtitle: InkWell(
                          onTap: () => _editTouchpoint(k, quiet),
                          child: Text(
                            _fmt(times.of(k)),
                            style: t.labelLarge?.copyWith(
                              color: p.accentStrong,
                            ),
                          ),
                        ),
                        value: enabled.contains(k),
                        onChanged: (on) => _toggleCategory(enabled, k, on),
                      ),
                    ListTile(
                      key: const Key('profile-quiet-start'),
                      leading: const Icon(Icons.bedtime_outlined),
                      title: Text(l.profileQuietStart),
                      trailing: Text(_fmt(quiet.start), style: t.labelLarge),
                      onTap: () => _editQuiet(quiet, start: true),
                    ),
                    ListTile(
                      key: const Key('profile-quiet-end'),
                      leading: const Icon(Icons.wb_twilight_outlined),
                      title: Text(l.profileQuietEnd),
                      trailing: Text(_fmt(quiet.end), style: t.labelLarge),
                      onTap: () => _editQuiet(quiet, start: false),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: Text(l.profileRoutineReminders),
                      trailing: DropdownButton<int>(
                        key: const Key('profile-routine-reminders'),
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
                );
              },
            ),
          ),

          // ---- Privacy & data ----
          header(l.profilePrivacy),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('profile-consents'),
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(l.profileConsents),
                  onTap: () => context.push('/settings/consents'),
                ),
                soon(
                  'profile-memory',
                  l.profileMemory,
                  Icons.psychology_outlined,
                ),
                soon(
                  'profile-export',
                  l.profileExport,
                  Icons.download_outlined,
                ),
                ListTile(
                  key: const Key('profile-delete-avatar'),
                  leading: const Icon(Icons.no_accounts_outlined),
                  title: Text(l.profileDeleteAvatar),
                  onTap: () => _delete('avatar'),
                ),
                ListTile(
                  key: const Key('profile-delete-voice'),
                  leading: const Icon(Icons.voice_over_off_outlined),
                  title: Text(l.profileDeleteVoice),
                  onTap: () => _delete('voice'),
                ),
                ListTile(
                  key: const Key('profile-delete-account'),
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: p.emergency,
                  ),
                  title: Text(
                    l.profileDeleteAccount,
                    style: t.bodyLarge?.copyWith(color: p.textPrimary),
                  ),
                  onTap: () => _delete('account'),
                ),
              ],
            ),
          ),

          // ---- Help & about ----
          header(l.profileHelp),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('profile-help-now'),
                  leading: Icon(Icons.support_outlined, color: p.emergency),
                  title: Text(l.careHelpNow),
                  onTap: () => context.push('/help'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l.profileTerms),
                  onTap: () => context.push('/onboarding/legal/terms'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.profilePrivacyPolicy),
                  onTap: () => context.push('/onboarding/legal/privacy'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    l.profileVersion(ref.watch(_versionProvider).value ?? ''),
                  ),
                ),
              ],
            ),
          ),

          // ---- Developer: dev flavour only (AGENTS.md) ----
          if (isDev) ...[
            header(l.profileDeveloper),
            Card(
              child: ListTile(
                key: const Key('dev-design-tokens'),
                leading: const Icon(Icons.palette_outlined),
                title: Text(l.devDesignTokens),
                subtitle: Text(l.settingsDeveloperBody),
                onTap: () => context.push('/dev/tokens'),
              ),
            ),
            const SizedBox(height: LwSpacing.xs),
            Card(
              child: ListTile(
                key: const Key('dev-illustrations'),
                leading: const Icon(Icons.image_outlined),
                title: Text(l.devIllustrations),
                onTap: () => context.push('/dev/illustrations'),
              ),
            ),
            const SizedBox(height: LwSpacing.xs),
            Card(
              child: ListTile(
                key: const Key('dev-moments'),
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(l.devMoments),
                onTap: () => context.push('/dev/moments'),
              ),
            ),
            const SizedBox(height: LwSpacing.xs),
            Card(
              child: ListTile(
                key: const Key('dev-avatar-frames'),
                leading: const Icon(Icons.face_retouching_natural_outlined),
                title: Text(l.devAvatarFrames),
                onTap: () => context.push('/dev/avatar-frames'),
              ),
            ),
          ],
          const SizedBox(height: LwSpacing.xl),
        ],
      ),
    );
  }
}
