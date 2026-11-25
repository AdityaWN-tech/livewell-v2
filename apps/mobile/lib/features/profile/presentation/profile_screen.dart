import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/application/app_lock.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../studio/presentation/studio_screen.dart';
import '../../studio/presentation/studio_widgets.dart' show StudioTab;
import '../../../core/config/contact.dart';
import '../../../core/config/flavor.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../auth/domain/auth.dart';
import '../../auth/presentation/auth_copy.dart';
import '../../auth/presentation/phone_sign_in_screen.dart';
import '../../home/application/home_data.dart';
import '../../starter_plan/presentation/daily_plan_screen.dart';
import '../data/account_actions.dart';
import '../data/appearance.dart';
import 'my_coach_section.dart';
import 'profile_button.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/domain/coach_choice.dart';
import '../../avatar/presentation/coach_avatar.dart' show coachChoiceProvider;
import '../../memory/application/memory_enabled.dart';
import '../../memory/presentation/memory_screen.dart';

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

  /// Opens an email to ask for a copy of my data (FR-SET-02 by hand, within
  /// 72 hours, until the export function exists).
  Future<void> _requestData() async {
    final l = AppLocalizations.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: dataRequestEmail,
      queryParameters: {
        'subject': l.profileRequestDataSubject,
        'body': l.profileRequestDataBody(_uid),
      },
    );
    if (!await launchUrl(uri) && mounted) _say(l.profileRequestDataNoMail);
  }

  /// Add a phone number (one-time code), or remove it.
  Future<void> _phone(bool linked) async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    if (!linked) {
      final added = await context.push<bool>(PhoneSignInScreen.linkPath);
      if (!mounted) return;
      setState(() {});
      if (added ?? false) _say(l.profilePhoneAdded);
      return;
    }
    final phone = ref.read(authServiceProvider).currentUser?.phoneNumber ?? '';
    if (!await _confirm(
      l.profileRemovePhoneTitle,
      l.profileRemovePhoneBody(phone),
      l.profileRemovePhone,
    )) {
      return;
    }
    try {
      await ref.read(authServiceProvider).unlinkPhone();
      if (!mounted) return;
      setState(() {});
      _say(l.profilePhoneRemoved);
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

  Future<void> _delete(String what) async {
    if (!_signedIn) return;
    final l = AppLocalizations.of(context);
    // Delete my avatar is in My coach (my_coach_section.dart, D-78).
    final (title, body) = switch (what) {
      'voice' => (l.profileDeleteVoice, l.profileDeleteVoiceBody),
      _ => (l.profileDeleteAccount, l.profileDeleteAccountBody),
    };
    if (!await _confirm(title, body, l.profileDeleteConfirm)) return;
    try {
      switch (what) {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final user = _user;
    // Rebuilds when the profile (name, sign-in methods) changes.
    ref.watch(currentProfileProvider);
    final appearance = ref.watch(appearanceProvider);
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    final providers = user?.providers ?? const <String>[];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: LwSpacing.lg, bottom: LwSpacing.xs),
      child: Semantics(header: true, child: Text(text, style: t.titleSmall)),
    );

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
                ListTile(
                  key: const Key('profile-link-phone'),
                  leading: Icon(
                    providers.contains('phone')
                        ? Icons.phone_iphone
                        : Icons.add_call,
                  ),
                  title: Text(
                    providers.contains('phone')
                        ? l.profileRemovePhone
                        : l.profileLinkPhone,
                  ),
                  subtitle: providers.contains('phone')
                      ? Text(user?.phoneNumber ?? '')
                      : null,
                  onTap: () => _phone(providers.contains('phone')),
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

          // ---- My coach (T-AVT-08h) ----
          header(l.profileMyCoach),
          MyCoachSection(openStudio: _openStudio, editCoachName: _coachName),

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

          // ---- Daily plan: its own screen (T-DLY-03e) ----
          header(l.profileDailyPlan),
          Card(
            child: ListTile(
              key: const Key('profile-daily-plan'),
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l.profileDailyPlan),
              subtitle: Text(l.dailyPlanSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(DailyPlanScreen.path),
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
                // Optional fingerprint / face unlock (FR-ONB-01, D-62).
                SwitchListTile(
                  key: const Key('profile-app-lock'),
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(l.profileAppLock),
                  subtitle: Text(l.profileAppLockBody),
                  value: ref.watch(appLockProvider).value ?? false,
                  onChanged: (on) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref
                        .read(appLockProvider.notifier)
                        .set(on, l.appLockReason);
                    if (!ok && on) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.profileAppLockUnavailable)),
                      );
                    }
                  },
                ),
                // "What my coach remembers" (FR-CNV-05, D-101): only while
                // enabled (dev flavor, or the coachMemory flag).
                if (ref.watch(coachMemoryEnabledProvider))
                  ListTile(
                    key: const Key('profile-memory'),
                    leading: const Icon(Icons.bookmark_border),
                    title: Text(l.profileMemory),
                    onTap: () => context.push(MemoryScreen.path),
                  ),
                // Export by email
                // until the export function exists (FR-SET-02; needs Blaze),
                // only when an address is set (Step 4d, D-56).
                if (dataRequestEmail.isNotEmpty)
                  ListTile(
                    key: const Key('profile-export'),
                    leading: const Icon(Icons.download_outlined),
                    title: Text(l.profileRequestData),
                    subtitle: Text(l.profileRequestDataNote),
                    onTap: _requestData,
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
            const SizedBox(height: LwSpacing.xs),
            Card(
              child: ListTile(
                key: const Key('dev-crash-reporting'),
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l.devCrashReporting),
                onTap: () => context.push('/dev/crash-reporting'),
              ),
            ),
          ],
          const SizedBox(height: LwSpacing.xl),
        ],
      ),
    );
  }
}
