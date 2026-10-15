import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/consent/presentation/consents_screen.dart';
import '../../features/dev/presentation/design_gallery.dart';
import '../../features/auth/presentation/email_sign_in_screen.dart';
import '../../features/auth/presentation/phone_sign_in_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/care/presentation/care_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/onboarding/presentation/about_screen.dart';
import '../../features/onboarding/presentation/age_gate_screen.dart';
import '../../features/onboarding/presentation/legal_screen.dart';
import '../../features/onboarding/presentation/why_screen.dart';
import '../../features/account/application/account_setup.dart'
    show avatarPath, checkinPath, focusPath, voicePath, whyPath;
import '../../features/avatar/presentation/avatar_screen.dart';
import '../../features/voice/presentation/voice_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/focus/presentation/onboarding_checkin_screen.dart';
import '../../features/learn/presentation/library_screen.dart';
import '../../features/safety/presentation/help_now_screen.dart';
import '../../features/plan/presentation/framework_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/domain/splash_timing.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/track/presentation/track_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../../features/consent/domain/consent.dart';
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
      // Onboarding before an account exists (spec 5.2, D-19).
      GoRoute(
        path: '/onboarding/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/onboarding/age',
        builder: (context, state) => const AgeGateScreen(),
      ),
      GoRoute(
        path: '/onboarding/under-18',
        builder: (context, state) => const Under18Screen(),
      ),
      GoRoute(
        path: '/onboarding/legal',
        builder: (context, state) => const LegalScreen(),
        routes: [
          GoRoute(
            path: ':doc',
            builder: (context, state) => LegalDocumentScreen(
              type:
                  ConsentType.fromKey(state.pathParameters['doc']!) ??
                  ConsentType.terms,
            ),
          ),
        ],
      ),
      // After sign-up: create your coach (T-ONB-03b), then the Why.
      GoRoute(
        path: avatarPath,
        builder: (context, state) => const AvatarScreen(),
      ),
      GoRoute(
        path: voicePath,
        builder: (context, state) => const VoiceScreen(),
      ),
      GoRoute(path: whyPath, builder: (context, state) => const WhyScreen()),
      // After the Why: first check-in, then the focus (T-ONB-03d).
      GoRoute(
        path: checkinPath,
        builder: (context, state) => const OnboardingCheckInScreen(),
      ),
      GoRoute(
        path: focusPath,
        builder: (context, state) => const FocusScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            path: 'phone',
            builder: (context, state) => const PhoneSignInScreen(),
          ),
          GoRoute(
            path: 'email',
            builder: (context, state) => const EmailSignInScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) =>
            _fadeFromSplash(state, AppShell(navigationShell: shell)),
        branches: [
          for (final (path, screen) in _tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => screen,
                  routes: [
                    // MY GOAL DO IT under Plan (FR-GOL-06).
                    if (path == '/plan')
                      GoRoute(
                        path: 'framework',
                        builder: (context, state) => const FrameworkScreen(),
                      ),
                    if (path == '/learn')
                      GoRoute(
                        path: 'library',
                        builder: (context, state) => const LibraryScreen(),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
      // Safety resources, always reachable from Care (spec 14.2).
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpNowScreen(),
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
