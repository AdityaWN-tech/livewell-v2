import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show voicePath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../data/avatar_repository.dart';
import '../domain/avatar_config.dart';
import 'coach_avatar.dart';

/// "Meet your coach" (T-ONB-03b), the first step after sign-up. The
/// cartoon creator is gone (T-AVT-08a); the ready-made 3D coaches, "Make me
/// from my photo" and "Build my own" arrive with the Avatar Studio
/// (T-AVT-08b, 08e). Until then the person continues with the default coach;
/// nothing blocks.
class AvatarScreen extends ConsumerStatefulWidget {
  const AvatarScreen({super.key});

  @override
  ConsumerState<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends ConsumerState<AvatarScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(avatarRepositoryProvider).save(AvatarConfig.fallback);
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(profileRepositoryProvider).setStep(uid, ProfileStep.voice);
      if (mounted) context.go(voicePath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.avatarSaveError)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            children: [
              Text(l.studioTitle.toUpperCase(), style: t.labelSmall),
              Semantics(
                header: true,
                child: Text(l.avatarTitle, style: t.headlineSmall),
              ),
              const SizedBox(height: LwSpacing.xs),
              Text(l.avatarBody, style: t.bodyMedium),
              const SizedBox(height: LwSpacing.lg),
              const Center(
                child: CoachAvatar(
                  key: Key('avatar-preview'),
                  expression: AvatarExpression.waving,
                  size: 180,
                ),
              ),
              const SizedBox(height: LwSpacing.md),
              Text(
                l.avatarMoreSoon,
                key: const Key('avatar-more-soon'),
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LwSpacing.lg),
              FilledButton(
                key: const Key('avatar-use'),
                onPressed: _continue,
                child: Text(l.avatarContinue),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: LwSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
