import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/flavor.dart';
import 'core/design/theme.dart';
import 'core/routing/router.dart';
import 'features/profile/data/appearance.dart';
import 'l10n/app_localizations.dart';

class LiveWellApp extends ConsumerWidget {
  const LiveWellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    final appearance = ref.watch(appearanceProvider);
    final app = MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: LwTheme.light(),
      darkTheme: LwTheme.dark(),
      // Profile > Appearance (T-ONB-03f); System by default.
      themeMode: appearance.theme,
      routerConfig: ref.watch(routerProvider),
      // In-app text size on top of the phone's own setting.
      builder: (context, child) {
        if (appearance.textScale == 1.0) return child!;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              mq.textScaler.scale(1) * appearance.textScale,
            ),
          ),
          child: child!,
        );
      },
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
