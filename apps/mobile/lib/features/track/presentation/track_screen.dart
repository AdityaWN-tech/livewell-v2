import 'package:flutter/material.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';

/// Track tab. Will hold: Check-in history, habit logs, steps, sleep, weight, BP, glucose, meals, progress charts (spec 14.2).
class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LwScreen(
      title: l10n.tabTrack,
      children: [
        LwEmptyState(
          icon: Icons.insights_outlined,
          title: l10n.trackEmptyTitle,
          body: l10n.trackEmptyBody,
        ),
      ],
    );
  }
}
