import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// FR-GOL-03 quick safety screen before any movement plan. Pops true when
/// the person reports warning signs or a clinician's limit (then the plan
/// has no movement), false when not. Wording needs clinical review.
class ActivityCheckScreen extends StatelessWidget {
  const ActivityCheckScreen({super.key});

  Future<void> _yes(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ActivityLimitedScreen()),
    );
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    const size = Size.fromHeight(LwSize.buttonHeight);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            Semantics(
              header: true,
              child: Text(l.activityTitle, style: t.displaySmall),
            ),
            const SizedBox(height: LwSpacing.md),
            Text(l.activityQuestion, style: t.titleLarge),
            const SizedBox(height: LwSpacing.xl),
            // Two equal answers: neither is the "right" one.
            OutlinedButton(
              key: const Key('activity-yes'),
              style: OutlinedButton.styleFrom(minimumSize: size),
              onPressed: () => _yes(context),
              child: Text(l.activityYes),
            ),
            const SizedBox(height: LwSpacing.sm),
            OutlinedButton(
              key: const Key('activity-no'),
              style: OutlinedButton.styleFrom(minimumSize: size),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.activityNo),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Talk to your clinician first", with a way to get help right now.
class ActivityLimitedScreen extends StatelessWidget {
  const ActivityLimitedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            Semantics(
              header: true,
              child: Text(l.activityLimitedTitle, style: t.displaySmall),
            ),
            const SizedBox(height: LwSpacing.md),
            Text(l.activityLimitedBody, style: t.bodyLarge),
            const SizedBox(height: LwSpacing.lg),
            Container(
              padding: const EdgeInsets.all(LwSpacing.cardPadding),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: LwRadius.mdAll,
                border: Border.all(color: p.outlineSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.activityLimitedNow, style: t.bodyMedium),
                  const SizedBox(height: LwSpacing.sm),
                  FilledButton.icon(
                    key: const Key('activity-help-now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.emergency,
                      foregroundColor: p.onEmergency,
                    ),
                    onPressed: () => context.push('/help'),
                    icon: const Icon(Icons.support_outlined),
                    label: Text(l.careHelpNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LwSpacing.xl),
            FilledButton(
              key: const Key('activity-continue'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.activityContinue),
            ),
          ],
        ),
      ),
    );
  }
}
