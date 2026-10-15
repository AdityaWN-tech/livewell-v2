import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/voice_repository.dart';
import '../domain/voice.dart';
import 'voice_screen.dart' show AiVoiceLabel;

/// The voice library (FR-VOC-01): preview each voice, pick calm or
/// energetic, and a speed from 0.8x to 1.2x. Choices are kept as a draft so
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
    final p = LwPalette.of(context);
    String name(LibraryVoice v) => switch (v.id) {
      'lw-warm' => l.voiceNameWarm,
      'lw-bright' => l.voiceNameBright,
      'lw-steady' => l.voiceNameSteady,
      'lw-deep' => l.voiceNameDeep,
      'lw-gentle' => l.voiceNameGentle,
      _ => l.voiceNameClear,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.voiceLibraryTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
                  for (final v in VoiceLibrary.all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LwSpacing.xs),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: LwRadius.mdAll,
                          side: BorderSide(
                            color: _c.voiceId == v.id
                                ? p.primary
                                : p.outlineSoft,
                            width: _c.voiceId == v.id ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          key: Key('voice-${v.id}'),
                          selected: _c.voiceId == v.id,
                          leading: Icon(
                            _c.voiceId == v.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: p.primary,
                          ),
                          title: Text(name(v), style: t.titleMedium),
                          subtitle: Text(
                            v.accent == VoiceAccent.us
                                ? l.voiceAccentUs
                                : l.voiceAccentUk,
                          ),
                          trailing: IconButton(
                            key: Key('voice-play-${v.id}'),
                            tooltip: l.voicePreview(name(v)),
                            icon: const Icon(Icons.play_circle_outline),
                            onPressed: () {
                              _set(_c.copyWith(voiceId: v.id));
                              _preview(v);
                            },
                          ),
                          onTap: () {
                            _set(_c.copyWith(voiceId: v.id));
                            _preview(v);
                          },
                        ),
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
