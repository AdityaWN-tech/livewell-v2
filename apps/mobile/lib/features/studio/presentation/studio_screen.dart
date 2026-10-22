import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/domain/avatar_config.dart';
import '../../avatar/presentation/coach_avatar.dart'
    show coachAvatarConfigProvider, defaultCoach;
import '../../voice/data/voice_repository.dart';
import '../../voice/domain/voice.dart';
import '../../voice/presentation/voice_screen.dart'
    show AiVoiceLabel, showOwnVoiceSheet;
import 'studio_widgets.dart';

/// Whether a cloned voice with valid consent exists (the consent banner).
/// Cloned voices and their consents are server-only and not built yet
/// (FR-VOC-02, spec 7.4), so never yet.
/// TODO(T-VOC-02): read the cloned voice's consent status.
final clonedVoiceConsentProvider = Provider<bool>((ref) => false);

/// The Avatar & Voice Studio (T-UI-02h), from Profile: the coach's look,
/// voice and background, each saved with its own button. The look tab shows
/// the coach until the 3D Avatar Studio replaces it (T-AVT-08b).
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key, this.initialTab = StudioTab.avatar});

  final StudioTab initialTab;

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  late StudioTab _tab = widget.initialTab;
  AvatarConfig _avatar = defaultCoach;
  VoiceChoice _voice = VoiceChoice.fallback;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AvatarConfig? saved;
      VoiceChoice? voice;
      try {
        saved = await ref.read(avatarRepositoryProvider).load();
      } catch (_) {}
      try {
        voice = await ref.read(voiceRepositoryProvider).current();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        if (saved != null) _avatar = saved;
        if (voice != null) _voice = voice;
      });
    });
  }

  @override
  void deactivate() {
    ref.read(voicePreviewPlayerProvider).stop();
    super.deactivate();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveAvatar() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(avatarRepositoryProvider).save(_avatar);
      ref.invalidate(coachAvatarConfigProvider);
      if (mounted) _say(l.profileSaved);
    } catch (_) {
      if (mounted) _say(l.avatarSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveVoice() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    await ref.read(voicePreviewPlayerProvider).stop();
    try {
      await ref.read(voiceRepositoryProvider).choose(_voice);
      if (mounted) _say(l.profileSaved);
    } catch (_) {
      if (mounted) _say(l.voiceSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(LibraryVoice v) => ref
      .read(voicePreviewPlayerProvider)
      .play(v.previewAsset(_voice.style), speed: _voice.speed);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final flags = ref.watch(featureFlagsProvider);
    final children = switch (_tab) {
      // Choosing a coach comes with the Avatar Studio (T-AVT-08b); the
      // cartoon creator and its selfie suggestion are gone (T-AVT-08a).
      StudioTab.avatar => [
        const AvatarStage(),
        const SizedBox(height: LwSpacing.md),
        Text(
          l.avatarMoreSoon,
          key: const Key('avatar-more-soon'),
          style: t.bodySmall,
        ),
      ],
      StudioTab.voice => [
        const Align(alignment: Alignment.centerLeft, child: AiVoiceLabel()),
        const SizedBox(height: LwSpacing.sm),
        Text(l.voiceStyle, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        SegmentedButton<VoiceStyle>(
          key: const Key('voice-style'),
          segments: [
            ButtonSegment(
              value: VoiceStyle.calm,
              label: Text(l.voiceStyleCalm),
            ),
            ButtonSegment(
              value: VoiceStyle.energetic,
              label: Text(l.voiceStyleEnergetic),
            ),
          ],
          selected: {_voice.style},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              setState(() => _voice = _voice.copyWith(style: s.single)),
        ),
        const SizedBox(height: LwSpacing.sm),
        Row(
          children: [
            Expanded(child: Text(l.voiceSpeed, style: t.titleSmall)),
            Text(
              l.voiceSpeedValue(_voice.speed.toStringAsFixed(1)),
              key: const Key('voice-speed-value'),
              style: t.labelLarge,
            ),
          ],
        ),
        Slider(
          key: const Key('voice-speed'),
          min: VoiceChoice.minSpeed,
          max: VoiceChoice.maxSpeed,
          divisions: 4,
          value: _voice.speed,
          label: l.voiceSpeedValue(_voice.speed.toStringAsFixed(1)),
          onChanged: (v) => setState(() => _voice = _voice.copyWith(speed: v)),
        ),
        const SizedBox(height: LwSpacing.xs),
        VoiceChoices(
          selectedId: _voice.voiceId,
          flags: flags,
          hasClonedVoiceConsent: ref.watch(clonedVoiceConsentProvider),
          onSelect: (v) {
            setState(() => _voice = _voice.copyWith(voiceId: v.id));
            _preview(v);
          },
          onPreview: (v) {
            setState(() => _voice = _voice.copyWith(voiceId: v.id));
            _preview(v);
          },
          onOwnVoice: () => showOwnVoiceSheet(context),
        ),
        const SizedBox(height: LwSpacing.md),
        FilledButton(
          key: const Key('studio-save-voice'),
          onPressed: _busy ? null : _saveVoice,
          child: Text(l.studioUseVoice),
        ),
      ],
      StudioTab.background => [
        AvatarStage(background: _avatar.background),
        const SizedBox(height: LwSpacing.md),
        BackgroundChoices(
          selected: _avatar.background,
          onPick: (i) =>
              setState(() => _avatar = _avatar.copyWith(background: i)),
        ),
        const SizedBox(height: LwSpacing.md),
        FilledButton(
          key: const Key('studio-save-background'),
          onPressed: _busy ? null : _saveAvatar,
          child: Text(l.studioUseBackground),
        ),
      ],
    };
    return Scaffold(
      // Back arrow only: the title is in the page so it wraps at large text
      // sizes instead of being cut off.
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('studio'),
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            LwPageTitle(l.studioTitle),
            StudioTabs(
              tab: _tab,
              onChanged: (x) {
                ref.read(voicePreviewPlayerProvider).stop();
                setState(() => _tab = x);
              },
            ),
            const SizedBox(height: LwSpacing.md),
            ...children,
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: LwSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
