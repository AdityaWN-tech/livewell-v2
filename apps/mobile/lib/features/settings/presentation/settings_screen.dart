import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/flavor.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Settings home (spec 14.3). More sections (profile, avatar, voice,
/// notifications, accessibility, my data, linked portal) arrive with their tasks.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Developer tools live here, dev flavour only (AGENTS.md, Developer-only UI).
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    return LwScreen(
      title: l.settingsTitle,
      children: [
        LwCard(
          title: l.settingsPrivacy,
          body: l.settingsPrivacyBody,
          onTap: () => context.push('/settings/consents'),
        ),
        if (isDev) ...[
          LwSectionHeader(l.settingsDeveloper),
          LwCard(
            key: const Key('dev-design-tokens'),
            title: l.devDesignTokens,
            body: l.settingsDeveloperBody,
            onTap: () => context.push('/dev/tokens'),
          ),
          const SizedBox(height: LwSpacing.md),
        ],
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
