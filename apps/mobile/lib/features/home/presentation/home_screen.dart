import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/flavor.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';

/// Home tab. Will hold: avatar (tap to talk), morning briefing player, today's
/// next step, quick check-in, streak, at most one secondary card (spec 14.2,
/// T-DLY-01).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    return LwScreen(
      actions: const [SettingsAction()],
      title: l10n.tabHome,
      children: [
        LwEmptyState(
          icon: Icons.wb_sunny_outlined,
          title: l10n.homeEmptyTitle,
          body: l10n.homeEmptyBody,
        ),
        if (isDev)
          OutlinedButton(
            onPressed: () => context.push('/dev/tokens'),
            child: Text(l10n.devDesignTokens),
          ),
      ],
    );
  }
}
