import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show voicePath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../data/avatar_repository.dart';
import '../data/selfie_service.dart';
import '../domain/avatar_config.dart';
import 'avatar_creator_screen.dart';
import 'selfie_consent.dart';

/// "Create your coach" (T-ONB-03b, FR-AVT-01/02), the first step after
/// sign-up. Three ways: a starting look, the cartoon creator, or a selfie
/// that suggests features on the phone. "Skip, use default" never blocks.
class AvatarScreen extends ConsumerStatefulWidget {
  const AvatarScreen({super.key});

  @override
  ConsumerState<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends ConsumerState<AvatarScreen> {
  AvatarLook? _look;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Resume where the person left off (FR-ONB-06).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final draft = await ref.read(avatarDraftStoreProvider).load();
      if (!mounted || draft == null) return;
      if (draft.config.look != null) setState(() => _look = draft.config.look);
      if (draft.inCreator) await _openCreator(draft.config);
    });
  }

  AvatarConfig get _preview =>
      _look == null ? AvatarConfig.fallback : AvatarConfig.forLook(_look!);

  Future<void> _save(AvatarConfig config) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(avatarRepositoryProvider).save(config);
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(profileRepositoryProvider).setStep(uid, ProfileStep.voice);
      await ref.read(avatarDraftStoreProvider).clear();
      if (mounted) context.go(voicePath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.avatarSaveError)));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openCreator(
    AvatarConfig start, {
    bool suggested = false,
  }) async {
    final drafts = ref.read(avatarDraftStoreProvider);
    await drafts.save(AvatarDraft(config: start, inCreator: true));
    if (!mounted) return;
    final chosen = await Navigator.of(context).push<AvatarConfig>(
      MaterialPageRoute(
        builder: (_) =>
            AvatarCreatorScreen(initial: start, suggested: suggested),
      ),
    );
    if (chosen == null) {
      // Back from the creator: keep the choices, not the creator.
      final draft = await drafts.load();
      await drafts.save(
        AvatarDraft(config: draft?.config ?? start, inCreator: false),
      );
      return;
    }
    await _save(chosen);
  }

  Future<void> _selfie() async {
    final l = AppLocalizations.of(context);
    if (!await ensureSelfieConsent(context, ref) || !mounted) return;
    setState(() => _busy = true);
    SelfieSuggestion? suggestion;
    var failed = false;
    try {
      suggestion = await ref.read(selfieAnalyzerProvider).takeAndSuggest();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.avatarSelfieFailed)));
      await _openCreator(_preview);
      return;
    }
    if (suggestion == null) return; // cancelled the camera
    await _openCreator(suggestion.applyTo(_preview), suggested: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final looks = [
      (AvatarLook.woman, l.avatarLookWoman),
      (AvatarLook.man, l.avatarLookMan),
      (AvatarLook.neutral, l.avatarLookNeutral),
    ];
    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            children: [
              Semantics(
                header: true,
                child: Text(l.avatarTitle, style: t.displaySmall),
              ),
              const SizedBox(height: LwSpacing.xs),
              Text(l.avatarBody, style: t.bodyMedium),
              const SizedBox(height: LwSpacing.lg),
              Center(
                child: AvatarView(
                  key: const Key('avatar-preview'),
                  config: _preview,
                  semanticLabel: l.avatarPreviewLabel,
                ),
              ),
              const SizedBox(height: LwSpacing.lg),
              Text(l.avatarPickLook, style: t.titleSmall),
              const SizedBox(height: LwSpacing.xs),
              Wrap(
                spacing: LwSpacing.xs,
                runSpacing: LwSpacing.xs,
                children: [
                  for (final (look, label) in looks)
                    ChoiceChip(
                      key: Key('avatar-look-${look.name}'),
                      label: Text(label),
                      selected: _look == look,
                      onSelected: (_) {
                        setState(() => _look = look);
                        ref
                            .read(avatarDraftStoreProvider)
                            .save(
                              AvatarDraft(
                                config: AvatarConfig.forLook(look),
                                inCreator: false,
                              ),
                            );
                      },
                    ),
                ],
              ),
              const SizedBox(height: LwSpacing.lg),
              FilledButton(
                key: const Key('avatar-use'),
                onPressed: _look == null ? null : () => _save(_preview),
                child: Text(l.avatarUseThis),
              ),
              const SizedBox(height: LwSpacing.sm),
              OutlinedButton.icon(
                key: const Key('avatar-cartoon'),
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => _openCreator(_preview),
                label: Text(l.avatarMakeCartoon),
              ),
              const SizedBox(height: LwSpacing.sm),
              OutlinedButton.icon(
                key: const Key('avatar-selfie'),
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: _selfie,
                label: Text(l.avatarUseSelfie),
              ),
              const SizedBox(height: LwSpacing.xs),
              Text(l.avatarSelfieNote, style: t.bodySmall),
              Text(l.avatarPhotorealSoon, style: t.bodySmall),
              const SizedBox(height: LwSpacing.md),
              Center(
                child: TextButton(
                  key: const Key('avatar-skip'),
                  onPressed: () => _save(AvatarConfig.fallback),
                  child: Text(l.avatarSkip),
                ),
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
