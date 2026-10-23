import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/domain/coach_choice.dart';
import '../../avatar/domain/coaches.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../avatar/presentation/photo_consent.dart';
import '../../avatar/presentation/selfie_screen.dart';
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

/// The Avatar Studio (T-AVT-08b), from onboarding and Profile > My coach:
/// a large live preview of the coach (it breathes and blinks) with its name,
/// then tabs: the 8 ready-made coaches, "Make me from my photo", "Build my
/// own" and "Adjust" (made by the Media Service, coming with T-AVT-08c to
/// 08e), the background, and the voice. The look is saved with "Use this
/// coach"; the voice with its own button.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({
    super.key,
    this.initialTab = StudioTab.coaches,
    this.onboarding = false,
    this.onSaved,
  });

  final StudioTab initialTab;

  /// The first step after sign-up: no Voice tab (the voice step is next),
  /// "Use this coach" waits for a pick (never a guessed look, D-28), and
  /// "Skip" takes the default.
  final bool onboarding;

  /// Called after the look is saved (onboarding moves on).
  final Future<void> Function()? onSaved;

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  late StudioTab _tab = widget.initialTab;
  CoachChoice _saved = CoachChoice.fallback;
  CoachChoice _choice = CoachChoice.fallback;

  /// In onboarding, the coach the person picked (null: none yet).
  ReadyCoach? _picked;

  /// "Not now" to the photo consents: offer the other ways.
  bool _photoDeclined = false;
  final _name = TextEditingController();
  String? _nameError;
  VoiceChoice _voice = VoiceChoice.fallback;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      CoachChoice? saved;
      VoiceChoice? voice;
      try {
        saved = await ref.read(avatarRepositoryProvider).load();
      } catch (_) {}
      try {
        voice = await ref.read(voiceRepositoryProvider).current();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        if (saved != null) {
          _saved = _choice = saved;
          _name.text = saved.coachName ?? '';
        }
        if (voice != null) _voice = voice;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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

  void _pick(ReadyCoach c) => setState(() {
    _picked = c;
    _choice = _choice.copyWith(coach: c);
  });

  void _rename(String value) {
    final l = AppLocalizations.of(context);
    setState(() {
      _nameError = CoachChoice.validName(value)
          ? null
          : l.profileCoachNameError;
      if (_nameError == null) {
        final name = CoachChoice.cleanName(value);
        _choice = name == null
            ? _choice.copyWith(clearName: true)
            : _choice.copyWith(coachName: name);
      }
    });
  }

  Future<void> _saveAvatar([CoachChoice? choice]) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(avatarRepositoryProvider).save(choice ?? _choice);
      ref.invalidate(coachChoiceProvider);
      _saved = choice ?? _choice;
      if (widget.onSaved != null) {
        await widget.onSaved!();
      } else if (mounted) {
        _say(l.profileSaved);
      }
    } catch (_) {
      if (mounted) _say(l.avatarSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Make me from my photo": the two consents first (FR-ONB-03), then the
  /// live selfie; the Media Service writes the new coach (selfie source,
  /// frames version), which is loaded here.
  Future<void> _fromPhoto() async {
    final l = AppLocalizations.of(context);
    if (!await ensurePhotoConsent(context, ref)) {
      if (mounted) setState(() => _photoDeclined = true);
      return;
    }
    if (!mounted) return;
    setState(() => _photoDeclined = false);
    final made = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const SelfieScreen()));
    if (made != true || !mounted) return;
    ref.invalidate(coachChoiceProvider);
    try {
      final saved = await ref.read(avatarRepositoryProvider).load();
      if (saved != null && mounted) {
        setState(() {
          _saved = _choice = saved.copyWith(
            coachName: CoachChoice.cleanName(_name.text),
          );
        });
      }
    } catch (_) {}
    if (mounted) _say(l.photoReady);
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

  /// The coach shown: a made-for-you set while it is still the saved one,
  /// else the ready-made coach being chosen.
  AvatarImages? _previewImages() {
    final own = _choice == _saved && _choice.source != CoachSource.readyMade;
    return own
        ? ref.watch(coachImagesProvider).value
        : ref.watch(readyCoachFramesProvider(_choice.coach)).value;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final flags = ref.watch(featureFlagsProvider);
    final images = _previewImages();
    final background = AvatarColours.background[_choice.background];
    final canSave =
        !_busy && _nameError == null && (!widget.onboarding || _picked != null);
    final look = [
      AvatarStage(images: images, background: background),
      const SizedBox(height: LwSpacing.sm),
      TextField(
        key: const Key('studio-coach-name'),
        controller: _name,
        maxLength: CoachChoice.maxNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l.profileCoachName,
          hintText: l.homeCoachDefaultName,
          errorText: _nameError,
        ),
        onChanged: _rename,
      ),
      const SizedBox(height: LwSpacing.xs),
    ];
    final save = [
      const SizedBox(height: LwSpacing.md),
      FilledButton(
        key: const Key('studio-save-avatar'),
        onPressed: canSave ? _saveAvatar : null,
        child: Text(l.studioUseCoach),
      ),
      if (widget.onboarding) ...[
        const SizedBox(height: LwSpacing.xs),
        Center(
          child: TextButton(
            key: const Key('avatar-skip'),
            onPressed: _busy
                ? null
                : () => _saveAvatar(CoachChoice(coachName: _choice.coachName)),
            child: Text(l.avatarSkip),
          ),
        ),
      ],
    ];
    final children = switch (_tab) {
      StudioTab.coaches => [
        Text(l.studioPickCoach, style: t.titleSmall),
        const SizedBox(height: LwSpacing.xs),
        CoachGrid(
          selected: widget.onboarding ? _picked : _choice.coach,
          onPick: _pick,
        ),
        ...save,
      ],
      // Off until counsel review (T-CMP-02); then the live selfie (08e).
      StudioTab.photo when !flags.avatarFromPhoto => [
        StudioComingSoon(
          key: const Key('studio-photo-soon'),
          title: l.studioPhotoTitle,
          body: l.studioPhotoBody,
        ),
        ...save,
      ],
      StudioTab.photo => [
        LwCard(
          key: const Key('studio-photo-intro'),
          title: l.photoIntroTitle,
          body: l.photoIntroBody,
        ),
        const SizedBox(height: LwSpacing.sm),
        FilledButton.icon(
          key: const Key('photo-start'),
          onPressed: _busy ? null : _fromPhoto,
          icon: const Icon(Icons.photo_camera_front_outlined),
          label: Text(l.photoStart),
        ),
        if (_photoDeclined) ...[
          const SizedBox(height: LwSpacing.md),
          Text(
            l.photoDeclined,
            key: const Key('photo-declined'),
            style: t.bodyMedium,
          ),
          const SizedBox(height: LwSpacing.xs),
          Wrap(
            spacing: LwSpacing.xs,
            children: [
              OutlinedButton(
                key: const Key('photo-declined-coaches'),
                onPressed: () => setState(() => _tab = StudioTab.coaches),
                child: Text(l.studioTabCoaches),
              ),
              OutlinedButton(
                key: const Key('photo-declined-build'),
                onPressed: () => setState(() => _tab = StudioTab.build),
                child: Text(l.studioTabBuild),
              ),
            ],
          ),
        ],
      ],
      StudioTab.build => [
        StudioComingSoon(
          key: const Key('studio-build-soon'),
          title: l.studioBuildTitle,
          body: l.studioBuildBody,
        ),
        ...save,
      ],
      StudioTab.adjust => [
        StudioComingSoon(
          key: const Key('studio-adjust-soon'),
          title: l.studioAdjustTitle,
          body: l.studioAdjustBody,
        ),
        ...save,
      ],
      StudioTab.background => [
        BackgroundChoices(
          selected: _choice.background,
          images: images,
          onPick: (i) =>
              setState(() => _choice = _choice.copyWith(background: i)),
        ),
        ...save,
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
    };
    return Scaffold(
      // Back arrow only: the title is in the page so it wraps at large text
      // sizes instead of being cut off. Onboarding has no way back.
      appBar: widget.onboarding ? null : AppBar(),
      body: SafeArea(
        top: widget.onboarding,
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            key: const Key('studio'),
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            children: [
              if (widget.onboarding) ...[
                Text(l.studioTitle.toUpperCase(), style: t.labelSmall),
                Semantics(
                  header: true,
                  child: Text(l.avatarTitle, style: t.headlineSmall),
                ),
                const SizedBox(height: LwSpacing.xs),
                Text(l.avatarBody, style: t.bodyMedium),
                const SizedBox(height: LwSpacing.md),
              ] else
                LwPageTitle(l.studioTitle),
              if (_tab != StudioTab.voice) ...look,
              StudioTabs(
                tab: _tab,
                tabs: [
                  for (final x in StudioTab.values)
                    if (!widget.onboarding || x != StudioTab.voice) x,
                ],
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
      ),
    );
  }
}
