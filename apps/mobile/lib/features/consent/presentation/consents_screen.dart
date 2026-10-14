import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/consent_repository.dart';
import '../domain/consent.dart';
import 'consent_copy.dart';

/// "Privacy and consents" in Settings (FR-ONB-03, FR-SET-02). Each switch adds
/// a new consent record; nothing is overwritten.
class ConsentsScreen extends ConsumerWidget {
  const ConsentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final consents = ref.watch(currentConsentsProvider);
    return LwScreen(
      title: l.settingsPrivacy,
      children: switch (consents) {
        AsyncData(:final value) => _content(context, ref, l, value),
        AsyncError() => [Text(l.consentLoadError)],
        _ => const [Center(child: CircularProgressIndicator())],
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    Map<ConsentType, ConsentRecord> current,
  ) {
    final t = Theme.of(context).textTheme;
    return [
      Text(l.consentsIntro, style: t.bodyMedium),
      if (ConsentTexts.draftVersion.contains('draft')) ...[
        const SizedBox(height: LwSpacing.xs),
        Text(
          l.consentsDraftNote,
          style: t.labelSmall?.copyWith(color: LwPalette.of(context).caution),
        ),
      ],
      LwSectionHeader(l.consentsOptionalHeader),
      for (final type in ConsentType.granular)
        _ConsentSwitch(type: type, granted: isGranted(current, type)),
      LwSectionHeader(l.consentsLegalHeader),
      for (final type in ConsentType.values.where((t) => t.required))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(type.title(l), style: t.titleMedium),
          subtitle: Text(
            isGranted(current, type)
                ? l.consentLegalAccepted(current[type]!.docVersion)
                : l.consentLegalNotAccepted,
            style: t.bodySmall,
          ),
        ),
      Text(l.consentLegalWithdrawNote, style: t.bodySmall),
    ];
  }
}

class _ConsentSwitch extends ConsumerWidget {
  const _ConsentSwitch({required this.type, required this.granted});

  final ConsentType type;
  final bool granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: granted,
      title: Text(type.title(l), style: t.titleMedium),
      subtitle: Text(type.body(l)!, style: t.bodySmall),
      onChanged: (value) async {
        try {
          await ref
              .read(consentRepositoryProvider)
              .record(type, granted: value);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l.consentSaveError)));
          }
        }
      },
    );
  }
}
