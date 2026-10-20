import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/speech/dictation.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show checkinPath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../consent/presentation/microphone_consent.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/presentation/safety_screens.dart';
import 'about_screen.dart' show OnboardingScaffold;

/// Personal "Why" (FR-ONB-05, T-ONB-02): typed, picked from suggestions, or
/// spoken (with the microphone consent). Saved to the profile and shown on
/// Home. Checked by the red-flag rules before saving (T-ASM-02); nothing
/// but the user's own Home reads it until the agents' checks exist (D-21).
class WhyScreen extends ConsumerStatefulWidget {
  const WhyScreen({super.key});

  /// Long enough for a sentence or two; the rules allow up to 280.
  static const maxLength = 200;
  static const minLength = 3;

  @override
  ConsumerState<WhyScreen> createState() => _WhyScreenState();
}

class _WhyScreenState extends ConsumerState<WhyScreen> {
  final _text = TextEditingController();
  bool _listening = false;
  bool _saving = false;
  String _beforeDictation = '';

  /// Kept so dispose() can stop listening without using ref.
  late final Dictation _dictation = ref.read(dictationProvider);

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

  bool get _valid => _text.text.trim().length >= WhyScreen.minLength;

  void _setText(String value) {
    final clipped = value.length > WhyScreen.maxLength
        ? value.substring(0, WhyScreen.maxLength)
        : value;
    _text.value = TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }

  Future<void> _toggleDictation() async {
    final dictation = _dictation;
    if (_listening) {
      await dictation.stop();
      setState(() => _listening = false);
      return;
    }
    if (!await ensureMicrophoneConsent(context, ref) || !mounted) return;
    _beforeDictation = _text.text.trim();
    final started = await dictation.start((words, isFinal) {
      if (!mounted) return;
      _setText(_beforeDictation.isEmpty ? words : '$_beforeDictation $words');
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

  Future<void> _save() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      if (_listening) await _dictation.stop();

      // Red flags first (FR-SAF, D-21): emergency, crisis and disordered
      // eating are not saved; medication / pregnancy notes may continue.
      final rules = await ref.read(safetyRulesProvider.future);
      final result = rules.check(_text.text);
      if (!result.isClear) {
        final region = (await ref.read(profileRepositoryProvider).get(uid))
            ?.region;
        if (!mounted) return;
        final proceed = await showSafetyResponse(
          context,
          result,
          rules.contactsFor(region),
        );
        if (!proceed) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }

      await ref
          .read(profileRepositoryProvider)
          .saveWhy(uid, _text.text, nextStep: ProfileStep.checkin);
      // Next: the first check-in, then the focus (T-ONB-03d).
      if (mounted) context.go(checkinPath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).whySaveError)),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final suggestions = [
      l.whySuggestion1,
      l.whySuggestion2,
      l.whySuggestion3,
      l.whySuggestion4,
      l.whySuggestion5,
    ];
    return OnboardingScaffold(
      title: l.whyTitle,
      art: 'icon_goal',
      primaryLabel: l.whySave,
      onPrimary: _valid && !_saving ? _save : null,
      footer: _valid
          ? null
          : Text(
              l.whyTooShort,
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
      children: [
        Text(l.whyHeading, style: t.displaySmall),
        const SizedBox(height: LwSpacing.sm),
        Text(l.whyBody, style: t.bodyMedium),
        const SizedBox(height: LwSpacing.lg),
        TextField(
          key: const Key('why'),
          controller: _text,
          maxLength: WhyScreen.maxLength,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.whyFieldLabel,
            hintText: l.whyHint,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saving ? null : _toggleDictation,
            icon: Icon(
              _listening ? Icons.stop_circle_outlined : Icons.mic_none,
            ),
            label: Text(_listening ? l.whyListening : l.whyDictate),
          ),
        ),
        const SizedBox(height: LwSpacing.md),
        Text(l.whySuggestionsLabel, style: t.labelMedium),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final s in suggestions)
              ActionChip(label: Text(s), onPressed: () => _setText(s)),
          ],
        ),
      ],
    );
  }
}
