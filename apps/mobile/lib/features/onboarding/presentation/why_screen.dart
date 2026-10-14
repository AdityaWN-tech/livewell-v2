import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/speech/dictation.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import 'about_screen.dart' show OnboardingScaffold;

/// Personal "Why" (FR-ONB-05, T-ONB-02): typed, picked from suggestions, or
/// spoken (with the microphone consent). Saved to the profile and shown on
/// Home. Safety screening of this text arrives with the rules engine
/// (T-ASM-02); until then nothing else reads it (D-21).
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
    if (!await _ensureMicConsent() || !mounted) return;
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

  /// The microphone is a separate, revocable consent (FR-ONB-03): ask in the
  /// app before the OS permission prompt, and record the answer.
  Future<bool> _ensureMicConsent() async {
    // One read straight from the store (an unwatched provider would pause).
    final records = await ref
        .read(consentRepositoryProvider)
        .watchRecords()
        .first;
    if (isGranted(currentConsents(records), ConsentType.microphone)) {
      return true;
    }
    if (!mounted) return false;
    final l = AppLocalizations.of(context);
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.whyMicTitle),
        content: Text(l.whyMicBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.whyMicNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.whyMicAllow),
          ),
        ],
      ),
    );
    if (allow != true) return false;
    await ref
        .read(consentRepositoryProvider)
        .record(ConsentType.microphone, granted: true);
    return true;
  }

  Future<void> _save() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      if (_listening) await _dictation.stop();
      await ref
          .read(profileRepositoryProvider)
          .saveWhy(uid, _text.text, nextStep: ProfileStep.assessment);
      if (mounted) context.go('/home');
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
