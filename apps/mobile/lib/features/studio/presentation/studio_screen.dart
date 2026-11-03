import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/application/coach_job_watcher.dart';
import '../../avatar/data/avatar_maker_api.dart';
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
import 'avatar_options_picker.dart';
import 'studio_widgets.dart';

/// Whether a cloned voice with valid consent exists (the consent banner).
/// Cloned voices and their consents are server-only and not built yet
/// (FR-VOC-02, spec 7.4), so never yet.
/// TODO(T-VOC-02): read the cloned voice's consent status.
final clonedVoiceConsentProvider = Provider<bool>((ref) => false);

/// The Avatar Studio (T-AVT-08b), from onboarding and Profile > My coach:
/// a large live preview of the coach (it breathes and blinks) with its name,
/// then tabs: the 8 ready-made coaches, "Make me from my photo", "Build my
/// own" and "Adjust" (made by the Media Service), the background, and the
/// voice. The look is saved with "Use this coach"; the voice with its own
/// button. The ways that need the Media Service show only when it is set up
/// and their flag is on; never a "coming soon" dead end (Step 1, D-50).
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

  /// Build my own: one option per category (filled with defaults once the
  /// lists load). Adjust: only the options that change.
  Map<String, String>? _build;
  final _changes = <String, String>{};

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

  /// The ways that need the Media Service (T-AVT-08c-e): shown only when it
  /// is set up and the flag is on.
  bool get _makerReady => ref.read(avatarMakerApiProvider).available;
  bool get _canBuild =>
      ref.read(featureFlagsProvider).avatarMaker && _makerReady;
  bool get _canPhoto =>
      ref.read(featureFlagsProvider).avatarFromPhoto && _makerReady;

  /// The tabs this person can use now.
  List<StudioTab> get _tabs => [
    for (final x in StudioTab.values)
      if ((!widget.onboarding || x != StudioTab.voice) &&
          (x != StudioTab.photo || _canPhoto) &&
          ((x != StudioTab.build && x != StudioTab.adjust) || _canBuild))
        x,
  ];

  CoachNoticeTexts _notice(AppLocalizations l) => CoachNoticeTexts(
    readyTitle: l.coachNoticeReadyTitle,
    readyBody: l.coachNoticeReadyBody,
    notMadeTitle: l.coachNoticeNotMadeTitle,
    notMadeBody: l.coachNoticeNotMadeBody,
    channelName: l.coachNoticeChannel,
  );

  String _makerError(AppLocalizations l, String id) => switch (id) {
    'avatar_daily_limit' => l.photoErrLimit,
    'network' => l.photoErrNetwork,
    'not_configured' || 'feature_off' => l.studioErrUnavailable,
    _ => l.studioErrNotMade,
  };

  /// Starts a Build my own or Adjust job; the watcher follows it and says
  /// when the coach is ready (it takes a few minutes, D-39).
  Future<void> _startJob(
    Future<String> Function(AvatarMakerApi api, String key) start,
  ) async {
    final l = AppLocalizations.of(context);
    final watcher = ref.read(coachJobWatcherProvider.notifier);
    final key = '${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _busy = true);
    try {
      final jobId = await start(ref.read(avatarMakerApiProvider), key);
      watcher.clear();
      watcher.follow(jobId, _notice(l));
      if (mounted) setState(_changes.clear);
    } on AvatarMakerError catch (e) {
      if (mounted) _say(_makerError(l, e.messageId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
  /// live selfie. The Media Service writes the new coach (selfie source,
  /// frames version) minutes later; [CoachJobWatcher] says when, and it is
  /// loaded here ([_loadMade]) if the Studio is still open.
  Future<void> _fromPhoto() async {
    if (!await ensurePhotoConsent(context, ref)) {
      if (mounted) setState(() => _photoDeclined = true);
      return;
    }
    if (!mounted) return;
    setState(() => _photoDeclined = false);
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const SelfieScreen()));
  }

  Future<void> _loadMade() async {
    final l = AppLocalizations.of(context);
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
    final tabs = _tabs;
    // A tab that isn't available (e.g. opened from a link) falls back to
    // the coaches.
    if (!tabs.contains(_tab)) _tab = StudioTab.coaches;
    final options = ref.watch(avatarOptionsProvider).value;
    final build = _build ??= options?.defaults;
    final job = ref.watch(coachJobWatcherProvider);
    final madeForYou = _saved.source != CoachSource.readyMade;
    ref.listen(coachJobWatcherProvider, (_, job) {
      if (job.stage == CoachJobStage.ready) _loadMade();
    });
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
      // Shown only with its flag on (counsel review, T-CMP-02) and the
      // Media Service set up; then the live selfie (08e).
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
              if (_canBuild)
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
        LwCard(
          key: const Key('studio-build-intro'),
          title: l.studioBuildTitle,
          body: l.studioBuildBody,
        ),
        const SizedBox(height: LwSpacing.md),
        if (options == null || build == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          AvatarOptionsPicker(
            key: const Key('studio-build-options'),
            categories: options.forBuild,
            chosen: build,
            onChanged: (c, o) => setState(() {
              if (o != null) build[c] = o;
            }),
          ),
          FilledButton.icon(
            key: const Key('studio-build-make'),
            onPressed: _busy || job.stage == CoachJobStage.making
                ? null
                : () => _startJob(
                    (api, key) => api.startBuilt(
                      options: options.valid(build),
                      idempotencyKey: key,
                    ),
                  ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l.studioBuildMake),
          ),
        ],
      ],
      // Adjust changes a made-for-you coach. A ready-made coach has no
      // portrait to change: offer Build my own instead of a dead end.
      StudioTab.adjust when !madeForYou => [
        LwCard(
          key: const Key('studio-adjust-ready-made'),
          title: l.studioAdjustTitle,
          body: l.studioAdjustReadyMade,
        ),
        const SizedBox(height: LwSpacing.sm),
        FilledButton(
          key: const Key('studio-adjust-to-build'),
          onPressed: () => setState(() => _tab = StudioTab.build),
          child: Text(l.studioBuildTitle),
        ),
      ],
      StudioTab.adjust => [
        LwCard(
          key: const Key('studio-adjust-intro'),
          title: l.studioAdjustTitle,
          body: l.studioAdjustBody,
        ),
        const SizedBox(height: LwSpacing.md),
        if (options == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          AvatarOptionsPicker(
            key: const Key('studio-adjust-options'),
            categories: options.forAdjust,
            chosen: _changes,
            allowNone: true,
            onChanged: (c, o) => setState(() {
              if (o == null) {
                _changes.remove(c);
              } else {
                _changes[c] = o;
              }
            }),
          ),
          FilledButton.icon(
            key: const Key('studio-adjust-make'),
            onPressed:
                _busy || _changes.isEmpty || job.stage == CoachJobStage.making
                ? null
                : () => _startJob(
                    (api, key) => api.startAdjust(
                      changes: options.valid(_changes),
                      idempotencyKey: key,
                    ),
                  ),
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: Text(l.studioAdjustMake),
          ),
        ],
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
              // A coach being made from a photo or from choices.
              if (job.stage == CoachJobStage.making) ...[
                LwCard(
                  key: const Key('studio-making'),
                  title: l.studioMakingTitle,
                  body: l.studioMakingBody,
                ),
                const SizedBox(height: LwSpacing.sm),
              ] else if (job.stage == CoachJobStage.notMade) ...[
                LwCard(
                  key: const Key('studio-not-made'),
                  title: l.coachNoticeNotMadeTitle,
                  body: _makerError(l, job.messageId ?? ''),
                ),
                const SizedBox(height: LwSpacing.sm),
              ],
              StudioTabs(
                tab: _tab,
                tabs: tabs,
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
