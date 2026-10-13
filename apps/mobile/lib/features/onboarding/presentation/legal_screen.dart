import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../auth/presentation/auth_copy.dart';
import '../../consent/domain/consent.dart';
import '../../consent/presentation/consent_copy.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_progress.dart';
import 'about_screen.dart' show OnboardingScaffold;

/// Accept the four legal documents, each version-stamped (FR-ONB-02).
/// Continue stays disabled until all four are ticked.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final progress = ref.watch(onboardingProvider).value;
    final accepted = progress?.legalAcceptedAt ?? const {};
    final allAccepted = progress?.allLegalAccepted ?? false;

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
        for (final type in legalDocuments)
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: accepted.containsKey(type),
                  title: Text(type.title(l), style: t.titleMedium),
                  subtitle: Text(
                    l.legalVersion(ConsentTexts.versionOf(type)),
                    style: t.labelSmall,
                  ),
                  onChanged: (value) => ref
                      .read(onboardingProvider.notifier)
                      .setLegalAccepted(
                        type,
                        accepted: value ?? false,
                        now: DateTime.now(),
                      ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/onboarding/legal/${type.key}'),
                child: Text(l.legalRead),
              ),
            ],
          ),
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
      appBar: AppBar(title: Text(type.title(l))),
      body: switch (text) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
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
