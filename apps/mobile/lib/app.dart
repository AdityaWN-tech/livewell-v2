import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/flavor.dart';
import 'core/design/tokens.dart';
import 'core/routing/router.dart';

class LiveWellApp extends ConsumerWidget {
  const LiveWellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    final app = MaterialApp.router(
      title: 'Live Well',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: LwColors.deepTeal,
          primary: LwColors.deepTeal,
          secondary: LwColors.lime,
        ),
        scaffoldBackgroundColor: LwColors.background,
      ),
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
