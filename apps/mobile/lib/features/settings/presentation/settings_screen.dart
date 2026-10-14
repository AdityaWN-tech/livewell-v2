import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';

/// Settings home (spec 14.3). More sections (profile, avatar, voice,
/// notifications, accessibility, my data, linked portal) arrive with their tasks.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LwScreen(
      title: l.settingsTitle,
      children: [
        LwCard(
          title: l.settingsPrivacy,
          body: l.settingsPrivacyBody,
          onTap: () => context.push('/settings/consents'),
        ),
      ],
    );
  }
}

/// Settings entry shown in the tab screens' app bar.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).settingsTitle,
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push('/settings'),
  );
}
