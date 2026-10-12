import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/flavor.dart';

/// Placeholder route. The 5-tab shell (Home, Plan, Track, Learn, Care)
/// replaces it in T-FND-04.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _Placeholder()),
    ],
  );
});

class _Placeholder extends ConsumerWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    return Scaffold(
      body: Center(
        child: Text(
          'Live Well\nHealth. Habit. Happiness.\n(${flavor.name})',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
