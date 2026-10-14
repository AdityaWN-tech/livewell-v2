import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/flavor.dart';
import 'core/design/theme.dart';
import 'core/routing/router.dart';
import 'l10n/app_localizations.dart';

class LiveWellApp extends ConsumerWidget {
  const LiveWellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    final app = MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: LwTheme.light(),
      darkTheme: LwTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
    final label = flavor.label;
    if (label == null) return app;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: label,
        location: BannerLocation.topEnd,
        child: app,
      ),
    );
  }
}
