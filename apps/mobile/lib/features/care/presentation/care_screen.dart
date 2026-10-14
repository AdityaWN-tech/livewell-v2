import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/speech/dictation.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../consent/presentation/microphone_consent.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/domain/safety_rules.dart';
import '../../safety/presentation/safety_screens.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/chat.dart';

/// Earlier conversation. Empty until the AI coach exists; the dev preview
/// shows a sample. TODO(T-CNV-01): users/{uid}/messages.
final coachHistoryProvider = Provider<List<ChatMessage>>(
  (ref) => ref.watch(previewModeProvider) ? PreviewSamples.chat : const [],
);

/// Whether the coach is speaking with an AI voice (FR-VOC-08 label).
/// TODO(T-VOC-01): from the voice settings.
final coachVoiceOnProvider = Provider<bool>(
  (ref) => ref.watch(previewModeProvider),
);

/// Care tab (T-UI-01f, Screen 5). The AI coach isn't built yet, so nothing
/// is answered: a typed or spoken message is still checked for red flags
/// (FR-SAF-01/02), then the person is told it wasn't sent. Nothing is saved.
class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});

  static const helpPath = '/help';

  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  final _text = TextEditingController();
  late final Dictation _dictation = ref.read(dictationProvider);

  /// This visit's lines only; not stored.
  final _session = <ChatMessage>[];
  bool _listening = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_listening) _dictation.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_listening || _sending) return;
    if (!await ensureMicrophoneConsent(context, ref) || !mounted) return;
    final before = _text.text.trim();
    final started = await _dictation.start((words, isFinal) {
      if (!mounted) return;
      _text.text = before.isEmpty ? words : '$before $words';
      if (isFinal) setState(() => _listening = false);
    });
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).whyDictationUnavailable),
        ),
      );
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    await _dictation.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await _stopListening();

    final rules = await ref.read(safetyRulesProvider.future);
    final result = rules.check(text);
    if (!result.isClear) {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      final region = uid == null
          ? null
          : (await ref.read(profileRepositoryProvider).get(uid))?.region;
      if (!mounted) return;
      final proceed = await showSafetyResponse(
        context,
        result,
        rules.contactsFor(region),
        continueLabel: l.careSend,
      );
      final distress =
          result.interrupts ||
          result.category == SafetyCategory.disorderedEating;
      if (distress || !proceed) {
        if (mounted) {
          setState(() => _sending = false);
          if (distress) _text.clear();
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _session
        ..add(ChatMessage(author: ChatAuthor.user, text: text))
        ..add(ChatMessage(author: ChatAuthor.system, text: l.careNotSent));
      _text.clear();
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final coach = ref.watch(coachNameProvider) ?? l.homeCoachDefaultName;
    final history = ref.watch(coachHistoryProvider);
    final messages = [...history, ..._session];
    return LwScreen(
      eyebrow: l.careEyebrow,
      title: l.careTitle,
      actions: [
        _StatusPill(voiceOn: ref.watch(coachVoiceOnProvider)),
        const SettingsAction(),
      ],
      bottom: _Composer(
        controller: _text,
        listening: _listening,
        sending: _sending,
        onSend: _send,
        onStart: _startListening,
        onStop: _stopListening,
      ),
      children: [
        // Always visible (spec 14.2 Care tab).
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('care-help-now'),
            // Red is kept for safety only; white on it passes AA in both
            // modes, red text on the dark background would not.
            style: FilledButton.styleFrom(
              backgroundColor: p.emergency,
              foregroundColor: p.onEmergency,
              shape: const StadiumBorder(),
              minimumSize: const Size(LwSize.minTapTarget, LwSize.minTapTarget),
            ),
            onPressed: () => context.push(CareScreen.helpPath),
            icon: const Icon(Icons.support_outlined),
            label: Text(l.careHelpNow),
          ),
        ),
        const SizedBox(height: LwSpacing.sm),
        if (messages.isEmpty)
          LwEmptyState(
            icon: Icons.forum_outlined,
            title: l.careSoonTitle,
            body: l.careSoonBody,
          )
        else
          for (final m in messages) ...[
            _Bubble(message: m, coach: coach),
            const SizedBox(height: LwSpacing.sm),
          ],
        Text(
          l.careDisclaimer,
          key: const Key('care-disclaimer'),
          textAlign: TextAlign.center,
          style: t.labelSmall,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.voiceOn});
  final bool voiceOn;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    final (text, fill, ink) = voiceOn
        ? (l.careStatusAiVoice, p.heroSurface, p.onHeroSurface)
        : (l.careStatusSoon, p.primaryTint, p.onPrimaryTint);
    return Semantics(
      container: true,
      label: voiceOn ? l.careStatusAiVoiceLabel : text,
      excludeSemantics: true,
      child: Container(
        key: const Key('care-status'),
        padding: const EdgeInsets.symmetric(
          horizontal: LwSpacing.sm,
          vertical: LwSpacing.xxs,
        ),
        decoration: BoxDecoration(color: fill, borderRadius: LwRadius.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (voiceOn) ...[
              Icon(Icons.graphic_eq, size: LwSize.iconSm, color: ink),
              const SizedBox(width: LwSpacing.xxs),
            ],
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.coach});
  final ChatMessage message;
  final String coach;

  void _showSources(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.lg,
            0,
            LwSpacing.lg,
            LwSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.careSourcesTitle, style: t.titleLarge),
              const SizedBox(height: LwSpacing.sm),
              for (final s in message.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: LwSpacing.xs),
                  child: Text('• $s', style: t.bodyLarge),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final m = message;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;

    if (m.author == ChatAuthor.system) {
      return Container(
        key: const Key('care-not-sent'),
        padding: const EdgeInsets.all(LwSpacing.sm),
        decoration: BoxDecoration(
          color: p.primaryTint,
          borderRadius: LwRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: p.onPrimaryTint),
            const SizedBox(width: LwSpacing.xs),
            Expanded(
              child: Text(
                m.text,
                style: t.bodySmall?.copyWith(color: p.onPrimaryTint),
              ),
            ),
          ],
        ),
      );
    }

    final fromUser = m.author == ChatAuthor.user;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: fromUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!fromUser)
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.xxs),
                child: Text(coach, style: t.labelMedium),
              ),
            Semantics(
              label: fromUser ? l.careYou : l.careCoachSaid(coach),
              child: Container(
                padding: const EdgeInsets.all(LwSpacing.sm),
                decoration: BoxDecoration(
                  color: fromUser ? p.surface : p.heroSurface,
                  border: fromUser ? Border.all(color: p.outlineSoft) : null,
                  borderRadius: LwRadius.lgAll,
                ),
                child: Text(
                  m.text,
                  style: t.bodyLarge?.copyWith(
                    color: fromUser ? p.textPrimary : p.onHeroSurface,
                  ),
                ),
              ),
            ),
            if (m.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: LwSpacing.xxs),
                child: ActionChip(
                  key: const Key('care-sources'),
                  avatar: Icon(
                    Icons.menu_book_outlined,
                    size: LwSize.iconSm,
                    color: p.onPrimaryTint,
                  ),
                  backgroundColor: p.primaryTint,
                  label: Text(
                    l.careSources(m.sources.join(', ')),
                    style: t.labelMedium?.copyWith(color: p.onPrimaryTint),
                  ),
                  onPressed: () => _showSources(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Text box with Send, and the big Hold to talk button. Holding listens until
/// release; a plain tap starts and stops it too, for screen readers and
/// switch users. Spoken words go into the box to check before sending.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.listening,
    required this.sending,
    required this.onSend,
    required this.onStart,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool listening;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    final empty = controller.text.trim().isEmpty;
    return Material(
      color: p.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.screenGutter,
            LwSpacing.xs,
            LwSpacing.screenGutter,
            LwSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('care-input'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l.careTypeHint,
                  suffixIcon: IconButton(
                    key: const Key('care-send'),
                    tooltip: l.careSend,
                    onPressed: empty || sending ? null : onSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
              ),
              const SizedBox(height: LwSpacing.xs),
              Semantics(
                hint: l.careTalkHint,
                child: GestureDetector(
                  // Screen readers use the button's tap (start / stop).
                  excludeFromSemantics: true,
                  onLongPressStart: (_) => onStart(),
                  onLongPressEnd: (_) => onStop(),
                  child: FilledButton.icon(
                    key: const Key('care-talk'),
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(LwSize.buttonHeight),
                    ),
                    onPressed: sending ? null : (listening ? onStop : onStart),
                    icon: Icon(listening ? Icons.graphic_eq : Icons.mic_none),
                    label: Text(listening ? l.careListening : l.careHoldToTalk),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
