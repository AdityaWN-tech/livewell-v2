import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show voicePath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../data/avatar_repository.dart';
import '../data/selfie_service.dart';
import '../../studio/presentation/studio_widgets.dart';
import '../domain/avatar_config.dart';
import '../domain/characters.dart';
import 'avatar_creator_screen.dart';
import 'selfie_consent.dart';

/// "Create your coach" (T-ONB-03b, FR-AVT-01/02), the first step after
/// sign-up, in the Avatar & Voice Studio design (T-UI-02h): a large preview
/// with arrows and the default characters, the cartoon creator
/// ("Customize"), or a selfie that suggests features on the phone. Nothing
/// is guessed: "Use this" waits for the person's pick (D-28). "Skip, use
/// default" never blocks.
class AvatarScreen extends ConsumerStatefulWidget {
  const AvatarScreen({super.key});

  @override
  ConsumerState<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends ConsumerState<AvatarScreen> {
  /// The person's pick (a character, or their customized look).
  AvatarConfig? _picked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Resume where the person left off (FR-ONB-06).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final draft = await ref.read(avatarDraftStoreProvider).load();
      if (!mounted || draft == null) return;
      setState(() => _picked = draft.config);
      if (draft.inCreator) await _openCreator(draft.config);
    });
  }

  AvatarConfig get _preview => _picked ?? CoachCharacters.all.first.config;

  void _pick(int i) {
    final config = CoachCharacters.all[i].config;
    setState(() => _picked = config);
    ref
        .read(avatarDraftStoreProvider)
        .save(AvatarDraft(config: config, inCreator: false));
  }

  void _step(int by) {
    final n = CoachCharacters.all.length;
    final i = _picked == null ? -1 : CoachCharacters.indexOf(_picked!);
    _pick(i < 0 ? (by > 0 ? (_picked == null ? 1 : 0) : n - 1) : (i + by) % n);
  }

  /// Anime or Illustrated: the person's choice, kept as a draft.
  void _style(AvatarStyle style) {
    final config = _preview.withStyle(style);
    setState(() => _picked = config);
    ref
        .read(avatarDraftStoreProvider)
        .save(AvatarDraft(config: config, inCreator: false));
  }

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
      final kept = draft?.config ?? start;
      await drafts.save(AvatarDraft(config: kept, inCreator: false));
      if (mounted) setState(() => _picked = kept);
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
    final index = _picked == null ? 0 : CoachCharacters.indexOf(_picked!);
    final anime = _preview.style == AvatarStyle.anime;
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
              const SizedBox(height: LwSpacing.md),
              AvatarStyleSwitch(style: _preview.style, onChanged: _style),
              const SizedBox(height: LwSpacing.sm),
              AvatarStage(
                config: _preview,
                index: index,
                // The characters are Illustrated (T-AVT-06a).
                onStep: anime ? null : _step,
              ),
              const SizedBox(height: LwSpacing.md),
              if (anime)
                Text(
                  l.avatarAnimeSoon,
                  key: const Key('avatar-anime-soon'),
                  style: t.bodySmall,
                )
              else ...[
                Text(l.avatarPickCharacter, style: t.titleSmall),
                const SizedBox(height: LwSpacing.xs),
                CharacterStrip(
                  selected: _picked == null ? -1 : index,
                  onPick: _pick,
                ),
              ],
              const SizedBox(height: LwSpacing.lg),
              FilledButton(
                key: const Key('avatar-use'),
                onPressed: _picked == null ? null : () => _save(_preview),
                child: Text(l.avatarUseThis),
              ),
              const SizedBox(height: LwSpacing.sm),
              OutlinedButton.icon(
                key: const Key('avatar-cartoon'),
                icon: const Icon(Icons.tune),
                onPressed: () => _openCreator(_preview),
                label: Text(l.studioCustomize),
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
