import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../data/safety_rules_provider.dart';
import '../domain/safety_rules.dart';
import 'safety_screens.dart';

/// "Get help now" (spec 14.2 Care tab): emergency and support numbers for
/// the person's region, or both regions when it isn't known (D-03).
class HelpNowScreen extends ConsumerWidget {
  const HelpNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final rules = ref.watch(safetyRulesProvider).value;
    final region = ref.watch(currentProfileProvider).value?.region;
    final contacts = rules?.contactsFor(region) ?? const <SafetyContacts>[];
    final both = contacts.length > 1;
    String country(SafetyContacts c) =>
        c.region == 'IN' ? l.countryIndiaName : l.countryUsName;

    Future<void> dial(String number, {bool sms = false}) async {
      final launcher = ref.read(phoneLauncherProvider);
      final ok = sms
          ? await launcher.text(number)
          : await launcher.call(number);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.safetyCallFailed(number))));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.helpNowTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(l.helpNowBody, style: t.bodyLarge),
          const SizedBox(height: LwSpacing.lg),
          Semantics(
            header: true,
            child: Text(l.helpNowEmergency, style: t.titleMedium),
          ),
          const SizedBox(height: LwSpacing.xs),
          for (final c in contacts) ...[
            FilledButton.icon(
              key: Key('help-emergency-${c.region}'),
              style: FilledButton.styleFrom(
                backgroundColor: p.emergency,
                foregroundColor: p.onEmergency,
              ),
              icon: const Icon(Icons.call),
              onPressed: () => dial(c.emergency),
              label: Text(
                both
                    ? l.safetyCallNumberIn(c.emergency, country(c))
                    : l.safetyCallNumber(c.emergency),
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
          ],
          const SizedBox(height: LwSpacing.md),
          Semantics(
            header: true,
            child: Text(l.helpNowSupport, style: t.titleMedium),
          ),
          const SizedBox(height: LwSpacing.xs),
          for (final c in contacts) ...[
            if (both)
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.xs),
                child: Text(country(c), style: t.titleSmall),
              ),
            OutlinedButton.icon(
              key: Key('help-support-${c.region}'),
              icon: const Icon(Icons.call),
              onPressed: () => dial(c.crisisCall),
              label: Text(l.safetyCrisisCall(c.crisisName, c.crisisCall)),
            ),
            if (c.crisisText != null) ...[
              const SizedBox(height: LwSpacing.xs),
              OutlinedButton.icon(
                icon: const Icon(Icons.sms_outlined),
                onPressed: () => dial(c.crisisText!, sms: true),
                label: Text(l.safetyCrisisText(c.crisisText!)),
              ),
            ],
            const SizedBox(height: LwSpacing.md),
          ],
        ],
      ),
    );
  }
}
