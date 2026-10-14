import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev/presentation/design_gallery.dart';
import '../config/flavor.dart';

/// Placeholder routes. The splash, Welcome and the 5-tab shell (Home, Plan,
/// Track, Learn, Care) replace '/' in the next tasks (S-7, T-FND-04).
final routerProvider = Provider<GoRouter>((ref) {
  final flavor = ref.watch(flavorProvider);
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            flavor == Flavor.dev ? const DesignGallery() : const _Placeholder(),
      ),
    ],
  );
});

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Live Well\nHealth. Habit. Happiness.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
