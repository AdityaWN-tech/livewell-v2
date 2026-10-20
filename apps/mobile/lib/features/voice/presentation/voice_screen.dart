import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show whyPath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/domain/avatar_config.dart';
import '../../home/application/home_data.dart';
import '../data/voice_repository.dart';
import '../domain/voice.dart';
import 'voice_library_screen.dart';

/// "Choose your coach's voice" (T-ONB-03c, FR-VOC-01/08). The coach greets
/// the person in the default voice; "Sounds good" keeps it. Only bundled
/// recordings of approved text are played (closed script, FR-VOC-05).
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  AvatarConfig _avatar = AvatarConfig.fallback;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await ref
          .read(avatarRepositoryProvider)
          .load()
          .catchError((_) => null);
      if (mounted && saved != null) setState(() => _avatar = saved);
      // Resume in the library if the person was there (FR-ONB-06).
      final draft = await ref.read(voiceDraftStoreProvider).load();
      if (!mounted) return;
      if (draft != null && draft.inLibrary) {
        await _openLibrary(draft.choice);
      } else {
        await _greet();
      }
    });
  }

  @override
  void deactivate() {
    ref.read(voicePreviewPlayerProvider).stop();
    super.deactivate();
  }

  Future<void> _greet() =>
      ref.read(voicePreviewPlayerProvider).play(VoiceLibrary.greetingAsset);

  Future<void> _save(VoiceChoice choice) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    await ref.read(voicePreviewPlayerProvider).stop();
    try {
      await ref.read(voiceRepositoryProvider).choose(choice);
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(profileRepositoryProvider).setStep(uid, ProfileStep.why);
      await ref.read(voiceDraftStoreProvider).clear();
      if (mounted) context.go(whyPath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.voiceSaveError)));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openLibrary(VoiceChoice start) async {
    final drafts = ref.read(voiceDraftStoreProvider);
    await ref.read(voicePreviewPlayerProvider).stop();
    await drafts.save(VoiceDraft(choice: start, inLibrary: true));
    if (!mounted) return;
    final chosen = await Navigator.of(context).push<VoiceChoice>(
      MaterialPageRoute(builder: (_) => VoiceLibraryScreen(initial: start)),
    );
    if (chosen == null) {
      final draft = await drafts.load();
      await drafts.save(
        VoiceDraft(choice: draft?.choice ?? start, inLibrary: false),
      );
      return;
    }
    await _save(chosen);
  }

  void _ownVoice() => showOwnVoiceSheet(context);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final name = ref.watch(firstNameProvider);
    final cloneOn = ref.watch(featureFlagsProvider).voiceClone;
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
                child: Text(l.voiceTitle, style: t.headlineSmall),
              ),
              const SizedBox(height: LwSpacing.md),
              // The coach talking on their own background (Studio design).
              Container(
                padding: const EdgeInsets.all(LwSpacing.md),
                decoration: BoxDecoration(
                  color: AvatarColours.background[_avatar.background],
                  borderRadius: LwRadius.lgAll,
                  boxShadow: LwShadow.of(context),
                ),
                child: Column(
                  children: [
                    AvatarView(
                      config: _avatar,
                      expression: AvatarExpression.talking,
                      semanticLabel: l.avatarPreviewLabel,
                    ),
                    const SizedBox(height: LwSpacing.sm),
                    const AiVoiceLabel(),
                    const SizedBox(height: LwSpacing.sm),
                    Text(
                      name == null
                          ? l.voiceGreeting
                          : l.voiceGreetingNamed(name),
                      key: const Key('voice-greeting'),
                      textAlign: TextAlign.center,
                      // The art colours are light in both modes.
                      style: t.titleLarge?.copyWith(
                        color: LwPalette.light.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: TextButton.icon(
                  key: const Key('voice-replay'),
                  onPressed: _greet,
                  icon: const Icon(Icons.replay),
                  label: Text(l.voicePlayAgain),
                ),
              ),
              const SizedBox(height: LwSpacing.md),
              FilledButton(
                key: const Key('voice-ok'),
                onPressed: () => _save(VoiceChoice.fallback),
                child: Text(l.voiceSoundsGood),
              ),
              const SizedBox(height: LwSpacing.sm),
              OutlinedButton(
                key: const Key('voice-another'),
                onPressed: () => _openLibrary(VoiceChoice.fallback),
                child: Text(l.voiceChooseAnother),
              ),
              const SizedBox(height: LwSpacing.sm),
              Card(
                child: ListTile(
                  key: const Key('voice-own'),
                  enabled: cloneOn,
                  leading: Icon(
                    Icons.record_voice_over_outlined,
                    color: p.textSecondary,
                  ),
                  title: Text(l.voiceOwnTitle),
                  subtitle: cloneOn ? null : Text(l.voiceOwnSoon),
                  trailing: cloneOn ? const Icon(Icons.chevron_right) : null,
                  onTap: cloneOn ? _ownVoice : null,
                ),
              ),
              const SizedBox(height: LwSpacing.sm),
              Center(
                child: TextButton(
                  key: const Key('voice-skip'),
                  onPressed: () => _save(VoiceChoice.fallback),
                  child: Text(l.voiceSkip),
                ),
              ),
              if (_busy) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Use my own voice" with the clone flag on: an explanation only, nothing
/// is recorded or built (FR-VOC-02, spec 7.4).
Future<void> showOwnVoiceSheet(BuildContext context) {
  final l = AppLocalizations.of(context);
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        key: const Key('voice-own-sheet'),
        padding: const EdgeInsets.fromLTRB(
          LwSpacing.lg,
          0,
          LwSpacing.lg,
          LwSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.voiceOwnTitle, style: t.titleLarge),
            const SizedBox(height: LwSpacing.xs),
            Text(l.voiceOwnBody, style: t.bodyMedium),
            const SizedBox(height: LwSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.voiceGotIt),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The "AI voice" label (FR-VOC-08), shown wherever the coach's voice plays.
class AiVoiceLabel extends StatelessWidget {
  const AiVoiceLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l.voiceAiLabelLong,
      excludeSemantics: true,
      child: Container(
        key: const Key('ai-voice-label'),
        padding: const EdgeInsets.symmetric(
          horizontal: LwSpacing.sm,
          vertical: LwSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: p.heroSurface,
          borderRadius: LwRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, size: LwSize.iconSm, color: p.onHeroSurface),
            const SizedBox(width: LwSpacing.xxs),
            Text(
              l.voiceAiLabel,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: p.onHeroSurface),
            ),
          ],
        ),
      ),
    );
  }
}
