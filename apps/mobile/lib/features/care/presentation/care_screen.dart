import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../dev/application/preview_mode.dart';
import '../../dev/application/preview_samples.dart';
import '../../home/application/home_data.dart';
import '../../learn/application/learn_data.dart';
import '../../learn/domain/lesson.dart';
import '../../learn/presentation/learn_screen.dart' show openLesson;
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/domain/safety_rules.dart';
import '../../safety/presentation/help_now_screen.dart';
import '../../safety/presentation/safety_screens.dart';
import '../../profile/presentation/profile_button.dart';
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

/// Care's tabs (T-UI-02g).
enum CareTab { chat, voice, saved, safety }

/// Care tab (T-UI-02g, illustrated design): history button, Chat / Voice /
/// Saved / Safety tabs, the coach listening with a speech bubble, quick
/// prompts, "Tap to speak" (coming soon), the message box and helpful
/// resources. Everything scrolls together, so nothing hides behind the
/// message box at any text size (phone bug).
///
/// The AI coach isn't built yet, so nothing is answered: a typed message or
/// prompt is still checked for red flags first (FR-SAF-01/02), then a kind
/// "your coach is coming soon" line. Nothing is saved or sent.
class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});

  static const helpPath = '/help';

  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  final _text = TextEditingController();
  CareTab _tab = CareTab.chat;

  /// This visit's lines only; not stored.
  final _session = <ChatMessage>[];
  bool _sending = false;

  /// After a safety reply the coach looks calm (task spec correction).
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send([String? prompt]) async {
    final l = AppLocalizations.of(context);
    final text = (prompt ?? _text.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    final rules = await ref.read(safetyRulesProvider.future);
    final result = rules.check(text);
    if (!result.isClear) {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      final region = uid == null
          ? null
          : (await ref.read(profileRepositoryProvider).get(uid))?.region;
      if (!mounted) return;
      setState(() => _calm = true);
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
        ..add(ChatMessage(author: ChatAuthor.system, text: l.careReplySoon));
      if (prompt == null) _text.clear();
      _sending = false;
    });
  }

  Future<void> _sheet(Key key, String title, String body) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          key: key,
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.lg,
            0,
            LwSpacing.lg,
            LwSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: t.titleLarge),
              const SizedBox(height: LwSpacing.xs),
              Text(body, style: t.bodyMedium),
              const SizedBox(height: LwSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.careGotIt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final coach = ref.watch(coachNameProvider) ?? l.homeCoachDefaultName;
    final messages = [...ref.watch(coachHistoryProvider), ..._session];
    return LwScreen(
      eyebrow: l.careEyebrow,
      title: l.tabCare,
      icons: [
        IconButton(
          key: const Key('care-history'),
          tooltip: l.careHistory,
          onPressed: () => _sheet(
            const Key('care-history-sheet'),
            l.careHistory,
            l.careHistoryEmpty,
          ),
          icon: Icon(Icons.history, color: p.textPrimary),
        ),
      ],
      profile: const ProfileButton(),
      actions: [
        // Always visible (spec 14.2 Care tab). Red is kept for safety only;
        // white on it passes AA in both modes.
        FilledButton.icon(
          key: const Key('care-help-now'),
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
        _StatusPill(voiceOn: ref.watch(coachVoiceOnProvider)),
      ],
      children: [
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final (x, name) in [
              (CareTab.chat, l.careTabChat),
              (CareTab.voice, l.careTabVoice),
              (CareTab.saved, l.careTabSaved),
              (CareTab.safety, l.careTabSafety),
            ])
              ChoiceChip(
                key: Key('care-tab-${x.name}'),
                label: Text(name),
                selected: _tab == x,
                onSelected: (_) => setState(() => _tab = x),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.md),
        ...switch (_tab) {
          CareTab.chat => _chat(context, coach, messages),
          CareTab.voice => [
            LwEmptyState(
              icon: Icons.record_voice_over_outlined,
              title: l.careVoiceSoonTitle,
              body: l.careVoiceSoonBody,
            ),
          ],
          CareTab.saved => [
            LwEmptyState(
              icon: Icons.bookmark_border,
              title: l.careSavedEmptyTitle,
              body: l.careSavedEmptyBody,
            ),
          ],
          CareTab.safety => [
            const HelpContacts(key: Key('care-safety')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(LwSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.careClinicianTitle, style: t.titleSmall),
                    const SizedBox(height: LwSpacing.xxs),
                    Text(l.careClinicianBody, style: t.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        },
        const SizedBox(height: LwSpacing.md),
        Text(
          l.careDisclaimer,
          key: const Key('care-disclaimer'),
          textAlign: TextAlign.center,
          style: t.labelSmall,
        ),
        const SizedBox(height: LwSpacing.md),
      ],
    );
  }

  List<Widget> _chat(
    BuildContext context,
    String coach,
    List<ChatMessage> messages,
  ) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final resources = [
      for (final x in ref.watch(lessonsProvider).value ?? const <Lesson>[])
        if (x.kind == LessonKind.lesson) x,
    ].take(2).toList();
    return [
      // The coach listening, or calm after a safety reply.
      Container(
        key: const Key('care-hero'),
        padding: const EdgeInsets.all(LwSpacing.cardPadding),
        decoration: BoxDecoration(color: p.mint, borderRadius: LwRadius.lgAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              coach,
              style: t.labelMedium?.copyWith(color: p.onTintSecondary),
            ),
            const SizedBox(height: LwSpacing.xs),
            CoachAvatar(
              expression: _calm
                  ? AvatarExpression.calm
                  : AvatarExpression.listening,
              bubble: _calm ? l.careHeroCalm : l.careHeroBubble,
              size: 96,
            ),
          ],
        ),
      ),
      const SizedBox(height: LwSpacing.sm),
      Semantics(
        container: true,
        label: l.carePromptsLabel,
        child: Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final (i, prompt) in [
              l.carePrompt1,
              l.carePrompt2,
              l.carePrompt3,
              l.carePrompt4,
            ].indexed)
              ActionChip(
                key: Key('care-prompt-$i'),
                label: Text(prompt),
                onPressed: _sending ? null : () => _send(prompt),
              ),
          ],
        ),
      ),
      if (messages.isNotEmpty) ...[
        const SizedBox(height: LwSpacing.md),
        for (final m in messages) ...[
          _Bubble(message: m, coach: coach),
          const SizedBox(height: LwSpacing.sm),
        ],
      ],
      const SizedBox(height: LwSpacing.md),
      const _TapToSpeak(),
      const SizedBox(height: LwSpacing.md),
      TextField(
        key: const Key('care-input'),
        controller: _text,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: l.careTypeHint,
          suffixIcon: IconButton(
            key: const Key('care-send'),
            tooltip: l.careSend,
            onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ),
      if (resources.isNotEmpty) ...[
        LwSectionHeader(l.careResourcesTitle),
        for (final r in resources)
          Padding(
            padding: const EdgeInsets.only(bottom: LwSpacing.sm),
            child: _ResourceCard(r),
          ),
      ],
    ];
  }
}

/// The big green mic with a waveform. Talking to the coach isn't built, so
/// it says "Coming soon" and does nothing (phone bug). The waveform is
/// still, so it is fine with reduced motion.
class _TapToSpeak extends StatelessWidget {
  const _TapToSpeak();

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    Widget wave(bool left) => ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in left ? _wave : _wave.reversed)
            Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: p.outlineStrong,
                borderRadius: LwRadius.pillAll,
              ),
            ),
        ],
      ),
    );
    return Semantics(
      key: const Key('care-talk'),
      container: true,
      excludeSemantics: true,
      label: l.careTalkSoonLabel,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              wave(true),
              const SizedBox(width: LwSpacing.sm),
              Container(
                width: LwSize.minTapTarget * 1.6,
                height: LwSize.minTapTarget * 1.6,
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.outlineStrong),
                ),
                child: Icon(
                  Icons.mic_none,
                  size: LwSize.iconMd,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(width: LwSpacing.sm),
              wave(false),
            ],
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(l.careTapToSpeak, style: t.titleSmall),
          Text(
            l.careStatusSoon,
            key: const Key('care-talk-soon'),
            style: t.labelMedium?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

const _wave = <double>[10, 18, 26, 14, 22];

/// An approved lesson as a helpful resource, with where it comes from.
class _ResourceCard extends StatelessWidget {
  const _ResourceCard(this.lesson);
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final x = lesson;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: l.careResourceLabel(x.title, x.category),
      child: Card(
        key: Key('care-resource-${x.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLesson(context, x),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.sm),
            child: Row(
              children: [
                Illustration(x.artId, width: 52, height: 52),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(x.title, style: t.titleSmall),
                      Text(l.careResourceFrom(x.category), style: t.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: p.textSecondary),
              ],
            ),
          ),
        ),
      ),
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
                  color: fromUser ? p.primary : p.surface,
                  borderRadius: LwRadius.lgAll,
                  boxShadow: fromUser ? null : LwShadow.of(context),
                ),
                child: Text(
                  m.text,
                  style: t.bodyLarge?.copyWith(
                    color: fromUser ? p.onPrimary : p.textPrimary,
                  ),
                ),
              ),
            ),
            if (m.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: LwSpacing.xxs),
                // A pill that wraps (a chip would cut long sources off at
                // large text sizes).
                child: Material(
                  key: const Key('care-sources'),
                  color: p.primaryTint,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showSources(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: LwSize.minTapTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LwSpacing.sm,
                          vertical: LwSpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: LwSize.iconSm,
                              color: p.onPrimaryTint,
                            ),
                            const SizedBox(width: LwSpacing.xs),
                            Flexible(
                              child: Text(
                                l.careSources(m.sources.join(', ')),
                                style: t.labelMedium?.copyWith(
                                  color: p.onPrimaryTint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
