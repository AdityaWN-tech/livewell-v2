import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../auth/presentation/auth_copy.dart';
import '../../consent/domain/consent.dart';
import '../../consent/presentation/consent_copy.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_progress.dart';
import 'about_screen.dart' show OnboardingScaffold;

/// Accept the four legal documents with one checkbox (Step 3, D-52): "I agree
/// to the Terms of Service, Privacy Policy, Medical Disclaimer and AI
/// Disclosure", each name a link to its text. Continue stays disabled until
/// it is ticked. Each document is still its own version-stamped consent
/// record (FR-ONB-02, written at sign-in by AccountSetup); the optional
/// permissions stay separate (FR-ONB-03).
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key});

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  late final _links = {
    for (final type in legalDocuments)
      type: TapGestureRecognizer()
        ..onTap = () => context.push('/onboarding/legal/${type.key}'),
  };

  @override
  void dispose() {
    for (final r in _links.values) {
      r.dispose();
    }
    super.dispose();
  }

  /// The sentence with each document name as a link. The names are passed
  /// as markers so the translated sentence decides where they go.
  List<InlineSpan> _sentence(AppLocalizations l, TextStyle? link) {
    String mark(ConsentType type) => '\u0000${type.index}\u0000';
    final text = l.legalAgree(
      mark(ConsentType.terms),
      mark(ConsentType.privacy),
      mark(ConsentType.medicalDisclaimer),
      mark(ConsentType.aiDisclosure),
    );
    final parts = text.split('\u0000');
    return [
      for (var i = 0; i < parts.length; i++)
        if (i.isOdd)
          TextSpan(
            text: ConsentType.values[int.parse(parts[i])].title(l),
            style: link,
            recognizer: _links[ConsentType.values[int.parse(parts[i])]],
          )
        else if (parts[i].isNotEmpty)
          TextSpan(text: parts[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final progress = ref.watch(onboardingProvider).value;
    final allAccepted = progress?.allLegalAccepted ?? false;
    void setAccepted(bool value) => ref
        .read(onboardingProvider.notifier)
        .setAllLegalAccepted(accepted: value, now: DateTime.now());
    final link = t.bodyLarge?.copyWith(
      color: LwPalette.of(context).accentStrong,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    return OnboardingScaffold(
      title: l.legalTitle,
      primaryLabel: l.legalAcceptAll,
      footer: allAccepted
          ? null
          : Text(
              l.legalAcceptHint,
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
      onPrimary: allAccepted
          ? () async {
              // Already signed in (came via "I already have an account"):
              // create the account now. Otherwise sign in next.
              final user = ref.read(authServiceProvider).currentUser;
              if (user != null) {
                await runSignIn(context, ref, () async => user);
                return;
              }
              await ref
                  .read(onboardingProvider.notifier)
                  .goTo(OnboardingStep.signIn);
              if (context.mounted) context.push(OnboardingStep.signIn.path);
            }
          : null,
      children: [
        Text(l.legalBody, style: t.bodyMedium),
        const SizedBox(height: LwSpacing.xs),
        Text(
          l.consentsDraftNote,
          style: t.labelSmall?.copyWith(color: LwPalette.of(context).caution),
        ),
        const SizedBox(height: LwSpacing.md),
        // Tapping the box or the plain words ticks it; tapping a name opens
        // that document.
        InkWell(
          key: const Key('legal-agree'),
          borderRadius: BorderRadius.circular(LwRadius.sm),
          onTap: () => setAccepted(!allAccepted),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: LwSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: l.legalAgree(
                    ConsentType.terms.title(l),
                    ConsentType.privacy.title(l),
                    ConsentType.medicalDisclaimer.title(l),
                    ConsentType.aiDisclosure.title(l),
                  ),
                  child: Checkbox(
                    key: const Key('legal-agree-box'),
                    value: allAccepted,
                    onChanged: (value) => setAccepted(value ?? false),
                  ),
                ),
                const SizedBox(width: LwSpacing.xxs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: LwSpacing.xs),
                    child: Text.rich(
                      TextSpan(
                        style: t.bodyLarge,
                        children: _sentence(l, link),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: LwSpacing.xs),
        Text(l.legalVersion(ConsentTexts.draftVersion), style: t.labelSmall),
      ],
    );
  }
}

/// Bundled text for a legal document (`assets/legal/VERSION.md`).
String legalAssetPath(ConsentType type) =>
    'assets/legal/${ConsentTexts.versionOf(type)}.md';

final legalTextProvider = FutureProvider.family<String, ConsentType>(
  (ref, type) => rootBundle.loadString(legalAssetPath(type), cache: false),
);

/// Full text of one legal document.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.type});

  final ConsentType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final text = ref.watch(legalTextProvider(type));
    return Scaffold(
      appBar: AppBar(),
      body: switch (text) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            LwPageTitle(type.title(l)),
            Text(
              l.legalVersion(ConsentTexts.versionOf(type)),
              style: t.labelSmall,
            ),
            const SizedBox(height: LwSpacing.md),
            for (final block in _blocks(value))
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.sm),
                child: Text(
                  block.text,
                  style: block.heading ? t.titleLarge : t.bodyLarge,
                ),
              ),
          ],
        ),
        AsyncError() => Center(child: Text(l.legalLoadError)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Minimal Markdown: "# " lines are headings, blank lines split paragraphs.
  static List<({String text, bool heading})> _blocks(String md) => [
    for (final para in md.split(RegExp(r'\n\s*\n')))
      if (para.trim().isNotEmpty)
        para.trim().startsWith('# ')
            ? (text: para.trim().substring(2), heading: true)
            : (text: para.trim().replaceAll('\n', ' '), heading: false),
  ];
}
