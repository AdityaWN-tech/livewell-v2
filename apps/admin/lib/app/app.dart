import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/theme.dart';
import 'router.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Live Well Admin',
    debugShowCheckedModeBanner: false,
    theme: LwTheme.light(),
    darkTheme: LwTheme.dark(),
    routerConfig: ref.watch(routerProvider),
  );
}

/// Shown when the build has no Firebase config (see apps/admin/README.md).
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Live Well Admin',
    theme: LwTheme.light(),
    home: const Scaffold(
      body: Center(
        child: Text(
          'This build has no Firebase settings. See apps/admin/README.md.',
        ),
      ),
    ),
  );
}
