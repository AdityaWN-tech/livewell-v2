import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/application/avatar_deletion.dart';
import '../../avatar/data/avatar_maker_api.dart';
import '../../avatar/domain/coach_choice.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../home/application/home_data.dart' show coachNameProvider;
import '../../starter_plan/application/plan_scheduler.dart';
import '../../starter_plan/presentation/plan_preview_screen.dart'
    show reminderTexts;
import '../../studio/presentation/studio_widgets.dart' show StudioTab;

/// Profile > My coach (T-AVT-08h, FR-SET-01/03): the coach's preview and
/// name, "Choose another coach", "Remake from a new photo" (only with the
/// `avatarFromPhoto` flag), "Build my own" and "Adjust" (only with the
/// `avatarMaker` flag), the voice, the coach's name and "Delete my avatar".
/// The ways that need the Media Service show only when it is set up, the
/// same as the Studio's tabs (never a dead end, D-50).
class MyCoachSection extends ConsumerStatefulWidget {
  const MyCoachSection({
    super.key,
    required this.openStudio,
    required this.editCoachName,
  });

  /// Opens the Avatar & Voice Studio on a tab.
  final Future<void> Function(StudioTab tab) openStudio;

  /// Asks for and saves the coach's name.
  final Future<void> Function() editCoachName;

  @override
  ConsumerState<MyCoachSection> createState() => _MyCoachSectionState();
}

class _MyCoachSectionState extends ConsumerState<MyCoachSection> {
  bool _deleting = false;

  void _say(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
        // Only the latest message: "Deleting…" never delays the result.
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text), action: action));

  /// The confirmation: what goes, that it can't be undone, and that a
  /// ready-made coach takes over. "Keep it" is the safe default.
  Future<bool> _confirmDelete() async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const Key('delete-avatar-dialog'),
            title: Text(l.profileDeleteAvatarTitle),
            content: Text(l.profileDeleteAvatarBody),
            actions: [
              TextButton(
                key: const Key('delete-avatar-keep'),
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.profileDeleteAvatarKeep),
              ),
              FilledButton(
                key: const Key('confirm-action'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.profileDeleteAvatar),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _delete() async {
    if (_deleting) return;
    if (!await _confirmDelete() || !mounted) return;
    await _runDelete();
  }

  /// Also the snack bar's "Try again" (already confirmed once).
  Future<void> _runDelete() async {
    final l = AppLocalizations.of(context);
    setState(() => _deleting = true);
    _say(l.profileDeletingAvatar);
    try {
      await ref.read(avatarDeletionProvider).run();
    } catch (_) {
      // Not deleted: say so plainly and offer to try again.
      if (!mounted) return;
      setState(() => _deleting = false);
      _say(
        l.profileAvatarDeleteFailed,
        action: SnackBarAction(
          key: const Key('delete-avatar-retry'),
          label: l.profileTryAgain,
          onPressed: _runDelete,
        ),
      );
      return;
    }
    try {
      // The reminders' pictures fall back to the ready-made coach.
      await ref.read(planSchedulerProvider).reschedule(reminderTexts(l));
    } catch (_) {
      // Best effort; the deletion is done.
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    _say(l.profileAvatarDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final flags = ref.watch(featureFlagsProvider);
    final makerReady = ref.watch(avatarMakerApiProvider).available;
    final canPhoto = flags.avatarFromPhoto && makerReady;
    final canBuild = flags.avatarMaker && makerReady;
    final choice = ref.watch(coachChoiceProvider).value ?? CoachChoice.fallback;
    final source = switch (choice.source) {
      CoachSource.readyMade => l.profileCoachReadyMade,
      CoachSource.selfie => l.profileCoachFromPhoto,
      CoachSource.built => l.profileCoachBuilt,
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            key: const Key('profile-coach-preview'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: LwSpacing.md,
              vertical: LwSpacing.xs,
            ),
            leading: const CoachAvatar(
              size: LwSize.coachPreview,
              animate: false,
            ),
            title: Text(ref.watch(coachNameProvider) ?? l.homeCoachDefaultName),
            subtitle: Text(source),
            onTap: () => widget.openStudio(StudioTab.coaches),
          ),
          ListTile(
            key: const Key('profile-avatar'),
            leading: const Icon(Icons.face_outlined),
            title: Text(l.profileChangeAvatar),
            onTap: () => widget.openStudio(StudioTab.coaches),
          ),
          if (canPhoto)
            ListTile(
              key: const Key('profile-avatar-photo'),
              leading: const Icon(Icons.photo_camera_front_outlined),
              title: Text(l.profileRemakeFromPhoto),
              onTap: () => widget.openStudio(StudioTab.photo),
            ),
          if (canBuild) ...[
            ListTile(
              key: const Key('profile-avatar-build'),
              leading: const Icon(Icons.brush_outlined),
              title: Text(l.profileBuildMyOwn),
              onTap: () => widget.openStudio(StudioTab.build),
            ),
            ListTile(
              key: const Key('profile-avatar-adjust'),
              leading: const Icon(Icons.tune_outlined),
              title: Text(l.profileAdjustCoach),
              onTap: () => widget.openStudio(StudioTab.adjust),
            ),
          ],
          ListTile(
            key: const Key('profile-voice'),
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(l.profileChangeVoice),
            onTap: () => widget.openStudio(StudioTab.voice),
          ),
          ListTile(
            key: const Key('profile-coach-name'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.profileCoachName),
            subtitle: Text(
              ref.watch(coachNameProvider) ?? l.homeCoachDefaultName,
            ),
            onTap: widget.editCoachName,
          ),
          ListTile(
            key: const Key('profile-delete-avatar'),
            leading: const Icon(Icons.no_accounts_outlined),
            title: Text(l.profileDeleteAvatar),
            trailing: _deleting
                ? const SizedBox.square(
                    dimension: LwSize.iconSm,
                    child: CircularProgressIndicator(),
                  )
                : null,
            enabled: !_deleting,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}
