import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../studio/presentation/studio_widgets.dart' show voiceName;
import '../domain/voice.dart';

/// "How this voice is made" for the chosen voice (FR-VOC-08, D-75): an AI
/// voice, the model it comes from (docs/voices.md), not a copy of a real
/// person's voice, and, while the coach speaks with the phone's
/// text-to-speech (D-49), that it uses the phone's closest voice. Update
/// the copy when the coach's own voices arrive (T-VOC-01).
class VoiceHowMade extends StatelessWidget {
  const VoiceHowMade({super.key, required this.voiceId});

  /// The selected voice. One that isn't in the library gets the general
  /// text, never a claim about how it was made.
  final String voiceId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final voice = VoiceLibrary.all.where((v) => v.id == voiceId).firstOrNull;
    final body = voice == null
        ? l.voiceHowMadeBody
        : l.voiceHowMadeLibraryBody(voiceName(l, voice));
    return Semantics(
      container: true,
      child: Column(
        key: const Key('voice-how-made'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.voiceHowMadeTitle, style: t.titleSmall),
          const SizedBox(height: LwSpacing.xxs),
          Text(body, key: const Key('voice-how-made-body'), style: t.bodySmall),
        ],
      ),
    );
  }
}
