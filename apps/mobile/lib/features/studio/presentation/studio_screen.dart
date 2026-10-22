import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/data/selfie_service.dart';
import '../../avatar/domain/avatar_config.dart';
import '../../avatar/domain/characters.dart';
import '../../avatar/presentation/avatar_creator_screen.dart';
import '../../avatar/presentation/coach_avatar.dart'
    show coachAvatarConfigProvider, defaultCoach;
import '../../avatar/presentation/selfie_consent.dart';
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
/// voice and background, each saved with its own button.
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

  void _step(int by) {
    final n = CoachCharacters.all.length;
    final i = CoachCharacters.indexOf(_avatar);
    final next = i < 0 ? (by > 0 ? 0 : n - 1) : (i + by) % n;
    _pick(next);
  }

  void _pick(int i) => setState(
    () => _avatar = CoachCharacters.all[i].config.copyWith(
      background: _avatar.background,
    ),
  );

  Future<void> _customize({bool suggested = false, AvatarConfig? start}) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final chosen = await Navigator.of(context).push<AvatarConfig>(
      MaterialPageRoute(
        builder: (_) => AvatarCreatorScreen(
          initial: start ?? _avatar,
          suggested: suggested,
        ),
      ),
    );
    await ref.read(avatarDraftStoreProvider).clear();
    if (chosen != null && mounted) setState(() => _avatar = chosen);
  }

  /// The selfie suggests skin tone and hair colour on the phone, then the
  /// creator opens; the photo is never kept (T-ONB-03b, D-28).
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
      _say(l.avatarSelfieFailed);
      await _customize();
      return;
    }
    if (suggestion == null) return;
    await _customize(suggested: true, start: suggestion.applyTo(_avatar));
  }

  Future<void> _preview(LibraryVoice v) => ref
      .read(voicePreviewPlayerProvider)
      .play(v.previewAsset(_voice.style), speed: _voice.speed);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final flags = ref.watch(featureFlagsProvider);
    final index = CoachCharacters.indexOf(_avatar);
    final anime = _avatar.style == AvatarStyle.anime;
    // The characters are Illustrated: no stepping through them in Anime.
    final stage = AvatarStage(
      config: _avatar,
      index: index,
      onStep: anime ? null : _step,
    );
    final children = switch (_tab) {
      StudioTab.avatar => [
        AvatarStyleSwitch(
          style: _avatar.style,
          onChanged: (s) => setState(() => _avatar = _avatar.withStyle(s)),
        ),
        const SizedBox(height: LwSpacing.sm),
        stage,
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
            selected: index,
            onPick: _pick,
            background: _avatar.background,
          ),
        ],
        const SizedBox(height: LwSpacing.md),
        OutlinedButton.icon(
          key: const Key('studio-customize'),
          icon: const Icon(Icons.tune),
          onPressed: _customize,
          label: Text(l.studioCustomize),
        ),
        const SizedBox(height: LwSpacing.xs),
        OutlinedButton.icon(
          key: const Key('studio-selfie'),
          icon: const Icon(Icons.photo_camera_outlined),
          onPressed: _selfie,
          label: Text(l.avatarUseSelfie),
        ),
        const SizedBox(height: LwSpacing.xs),
        Text(l.avatarSelfieNote, style: t.bodySmall),
        const SizedBox(height: LwSpacing.md),
        FilledButton(
          key: const Key('studio-save-avatar'),
          onPressed: _busy ? null : _saveAvatar,
          child: Text(l.studioUseLook),
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
        stage,
        const SizedBox(height: LwSpacing.md),
        BackgroundChoices(
          config: _avatar,
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
