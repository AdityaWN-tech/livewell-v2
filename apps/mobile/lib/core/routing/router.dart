import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/consent/presentation/consents_screen.dart';
import '../../features/dev/presentation/design_gallery.dart';
import '../../features/care/presentation/care_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/domain/splash_timing.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/track/presentation/track_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../config/flavor.dart';
import 'app_shell.dart';

/// App routes. The app always opens on the splash, which goes to Welcome
/// (new users) or the 5-tab shell at /home (signed in).
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
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) =>
            _fadeFromSplash(state, AppShell(navigationShell: shell)),
        branches: [
          for (final (path, screen) in _tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(path: path, builder: (context, state) => screen),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'consents',
            builder: (context, state) => const ConsentsScreen(),
          ),
        ],
      ),
      if (flavor == Flavor.dev)
        GoRoute(
          path: '/dev/tokens',
          builder: (context, state) => const DesignGallery(),
        ),
    ],
  );
});

const _tabs = <(String, Widget)>[
  ('/home', HomeScreen()),
  ('/plan', PlanScreen()),
  ('/track', TrackScreen()),
  ('/learn', LearnScreen()),
  ('/care', CareScreen()),
];

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
