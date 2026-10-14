import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev/presentation/design_gallery.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/splash/domain/splash_timing.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../config/flavor.dart';

/// App routes. The app always opens on the splash, which goes to Welcome
/// (new users) or Home (signed in). The 5-tab shell replaces /home in T-FND-04.
final routerProvider = Provider<GoRouter>((ref) {
  final flavor = ref.watch(flavorProvider);
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) =>
            _fadeFromSplash(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            _fadeFromSplash(state, const HomeScreen()),
      ),
      if (flavor == Flavor.dev)
        GoRoute(
          path: '/dev/tokens',
          builder: (context, state) => const DesignGallery(),
        ),
    ],
  );
});

/// The splash cross-fades into the next screen (also the reduce-motion path:
/// a fade, no movement).
Page<void> _fadeFromSplash(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: SplashTiming.exitFade,
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    );
