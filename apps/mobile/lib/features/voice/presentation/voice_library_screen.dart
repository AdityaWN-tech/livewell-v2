import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/voice_repository.dart';
import '../domain/voice.dart';
import '../../../core/config/feature_flags.dart';
import '../../studio/presentation/studio_screen.dart'
    show clonedVoiceConsentProvider;
import '../../studio/presentation/studio_widgets.dart';
import 'voice_screen.dart' show AiVoiceLabel, showOwnVoiceSheet;

/// The voice library (FR-VOC-01), in the Studio's "Choose Your Voice"
/// design (T-UI-02h): preview each voice, pick calm or energetic, and a
/// speed from 0.8x to 1.2x. Choices are kept as a draft so
/// the step resumes here.
class VoiceLibraryScreen extends ConsumerStatefulWidget {
  const VoiceLibraryScreen({super.key, required this.initial});

  final VoiceChoice initial;

  @override
  ConsumerState<VoiceLibraryScreen> createState() => _VoiceLibraryScreenState();
}

class _VoiceLibraryScreenState extends ConsumerState<VoiceLibraryScreen> {
  late VoiceChoice _c = widget.initial;

  void _set(VoiceChoice next) {
    setState(() => _c = next);
    ref
        .read(voiceDraftStoreProvider)
        .save(VoiceDraft(choice: next, inLibrary: true));
  }

  Future<void> _preview(LibraryVoice v) => ref
      .read(voicePreviewPlayerProvider)
      .play(v.previewAsset(_c.style), speed: _c.speed);

  @override
  void deactivate() {
    ref.read(voicePreviewPlayerProvider).stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            LwPageTitle(l.voiceLibraryTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AiVoiceLabel(),
                  ),
                  const SizedBox(height: LwSpacing.md),
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
                    selected: {_c.style},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        _set(_c.copyWith(style: s.single)),
                  ),
                  const SizedBox(height: LwSpacing.md),
                  Row(
                    children: [
                      Expanded(child: Text(l.voiceSpeed, style: t.titleSmall)),
                      Text(
                        l.voiceSpeedValue(_c.speed.toStringAsFixed(1)),
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
                    value: _c.speed,
                    label: l.voiceSpeedValue(_c.speed.toStringAsFixed(1)),
                    onChanged: (v) => _set(_c.copyWith(speed: v)),
                  ),
                  const SizedBox(height: LwSpacing.sm),
                  VoiceChoices(
                    selectedId: _c.voiceId,
                    flags: ref.watch(featureFlagsProvider),
                    hasClonedVoiceConsent: ref.watch(
                      clonedVoiceConsentProvider,
                    ),
                    onSelect: (v) {
                      _set(_c.copyWith(voiceId: v.id));
                      _preview(v);
                    },
                    onPreview: (v) {
                      _set(_c.copyWith(voiceId: v.id));
                      _preview(v);
                    },
                    onOwnVoice: () => showOwnVoiceSheet(context),
                  ),
                  // How the voice is made (FR-VOC-08).
                  const SizedBox(height: LwSpacing.md),
                  Semantics(
                    container: true,
                    child: Column(
                      key: const Key('voice-how-made'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.voiceHowMadeTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: LwSpacing.xxs),
                        Text(
                          l.voiceHowMadeBody,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LwSpacing.screenGutter),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('voice-use'),
                  onPressed: () => Navigator.of(context).pop(_c),
                  child: Text(l.voiceUseThis),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
