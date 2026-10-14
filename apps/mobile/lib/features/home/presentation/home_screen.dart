import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/flavor.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Placeholder Home. The real Home (briefing, next step, check-in, streak)
/// arrives with the 5-tab shell (T-FND-04) and T-DLY-01.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDev)
              OutlinedButton(
                onPressed: () => context.push('/dev/tokens'),
                child: Text(l10n.devDesignTokens),
              ),
          ],
        ),
      ),
    );
  }
}
