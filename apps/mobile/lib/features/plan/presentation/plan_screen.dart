import 'package:flutter/material.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';

/// Plan tab. Will hold: Live Well Map, 30-day goal, microhabits, MY GOAL DO IT tabs, 8-driver wheel, Travel / Sick day / Busy week modes (spec 14.2).
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LwScreen(
      actions: const [SettingsAction()],
      title: l10n.tabPlan,
      children: [
        LwEmptyState(
          icon: Icons.flag_outlined,
          title: l10n.planEmptyTitle,
          body: l10n.planEmptyBody,
        ),
      ],
    );
  }
}
