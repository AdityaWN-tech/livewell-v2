import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/safety_rules.dart';

/// Opens the phone dialer or SMS app. Behind an interface so tests can check
/// what would be called without dialling.
abstract class PhoneLauncher {
  Future<bool> call(String number);
  Future<bool> text(String number);
}

class UrlPhoneLauncher implements PhoneLauncher {
  @override
  Future<bool> call(String number) =>
      launchUrl(Uri(scheme: 'tel', path: number));

  @override
  Future<bool> text(String number) =>
      launchUrl(Uri(scheme: 'sms', path: number));
}

final phoneLauncherProvider = Provider<PhoneLauncher>(
  (ref) => UrlPhoneLauncher(),
);

/// Shows the right response for a red flag (FR-SAF-01..05). Returns true
/// only when the user chose to continue (medication / pregnancy notes);
/// emergency, crisis and disordered eating never continue.
Future<bool> showSafetyResponse(
  BuildContext context,
  SafetyResult result,
  List<SafetyContacts> contacts, {
  String? continueLabel,
}) async {
  final category = result.category;
  if (category == null) return true;
  if (category.interrupts) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            SafetyInterruptScreen(category: category, contacts: contacts),
      ),
    );
    return false;
  }
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        SafetyNoticeSheet(category: category, continueLabel: continueLabel),
  );
  return proceed ?? false;
}

/// Full-screen emergency or crisis card with one-tap calls. Calm and clear;
/// no coaching or portal content (FR-SAF-02).
class SafetyInterruptScreen extends ConsumerWidget {
  const SafetyInterruptScreen({
    super.key,
    required this.category,
    required this.contacts,
  });

  final SafetyCategory category;

  /// One region, or both when the region is unknown (D-03).
  final List<SafetyContacts> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final emergency = category == SafetyCategory.emergency;
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

    String emergencyLabel(SafetyContacts c) => both
        ? l.safetyCallNumberIn(c.emergency, country(c))
        : l.safetyCallNumber(c.emergency);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.safetyBack),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            Semantics(
              header: true,
              child: Text(
                emergency ? l.safetyEmergencyTitle : l.safetyCrisisTitle,
                style: t.displaySmall,
              ),
            ),
            const SizedBox(height: LwSpacing.md),
            Text(
              emergency ? l.safetyEmergencyBody : l.safetyCrisisBody,
              style: t.bodyLarge,
            ),
            const SizedBox(height: LwSpacing.xl),
            if (emergency)
              for (final c in contacts) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.emergency,
                    foregroundColor: p.onEmergency,
                  ),
                  icon: const Icon(Icons.call),
                  onPressed: () => dial(c.emergency),
                  label: Text(emergencyLabel(c)),
                ),
                const SizedBox(height: LwSpacing.sm),
              ]
            else ...[
              for (final c in contacts) ...[
                if (both)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LwSpacing.xs),
                    child: Text(country(c), style: t.titleSmall),
                  ),
                FilledButton.icon(
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
                const SizedBox(height: LwSpacing.lg),
              ],
              Text(l.safetyCrisisDanger, style: t.bodyMedium),
              const SizedBox(height: LwSpacing.xs),
              for (final c in contacts)
                TextButton.icon(
                  icon: const Icon(Icons.call),
                  onPressed: () => dial(c.emergency),
                  label: Text(emergencyLabel(c)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gentle, non-blocking note for disordered eating, medication and
/// pregnancy / medically complex topics (FR-SAF-03..05).
class SafetyNoticeSheet extends StatelessWidget {
  const SafetyNoticeSheet({
    super.key,
    required this.category,
    this.continueLabel,
  });

  final SafetyCategory category;

  /// Label of the "carry on" button; defaults to the Why screen's wording.
  final String? continueLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final (title, body) = switch (category) {
      SafetyCategory.disorderedEating => (l.safetyEdTitle, l.safetyEdBody),
      SafetyCategory.medication => (l.safetyMedTitle, l.safetyMedBody),
      _ => (l.safetyComplexTitle, l.safetyComplexBody),
    };
    // Disordered eating: the text is not kept (FR-SAF-04 suppresses
    // weight and calorie content); the others may continue.
    final canContinue = category != SafetyCategory.disorderedEating;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LwSpacing.screenGutter,
          0,
          LwSpacing.screenGutter,
          LwSpacing.screenGutter,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: t.titleLarge),
            const SizedBox(height: LwSpacing.sm),
            Text(body, style: t.bodyLarge),
            const SizedBox(height: LwSpacing.lg),
            if (canContinue)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(continueLabel ?? l.safetySaveAnyway),
              ),
            if (canContinue) const SizedBox(height: LwSpacing.xs),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.safetyChangeIt),
            ),
          ],
        ),
      ),
    );
  }
}
