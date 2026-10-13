import 'package:flutter/material.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';

/// Care tab. Will hold: Conversation with the avatar, "What my coach remembers", safety resources, "Talk to a clinician", portal services (spec 14.2).
class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LwScreen(
      title: l10n.tabCare,
      children: [
        LwEmptyState(
          icon: Icons.favorite_outline,
          title: l10n.careEmptyTitle,
          body: l10n.careEmptyBody,
        ),
      ],
    );
  }
}
