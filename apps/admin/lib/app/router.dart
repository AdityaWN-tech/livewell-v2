import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_repository.dart';
import '../core/auth/staff.dart';
import '../features/auth/presentation/no_access_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/portal_offers/domain/portal_offer.dart';
import '../features/portal_offers/presentation/offer_detail_screen.dart';
import '../features/portal_offers/presentation/offer_form_screen.dart';
import '../features/portal_offers/presentation/offers_list_screen.dart';
import '../core/widgets/loading_screen.dart';
import '../features/content/presentation/content_screens.dart';
import '../features/staff/data/staff_access_repository.dart';
import '../features/staff/domain/staff_access.dart';
import '../features/staff/presentation/access_screens.dart';
import '../features/staff/presentation/superadmin_screen.dart';

/// The role gate (T-PRT-02, D-92). Pure, so it is unit-tested. Signed out:
/// sign-in. Signed in without a staff role or without MFA: no-access.
/// Editing routes need an editing role. The Core API checks again on every
/// call; this only keeps people off screens they can't use.
String? adminRedirect(
  AsyncValue<StaffSession?> session,
  Uri uri, {
  AsyncValue<StaffAccess?> access = const AsyncData(null),
}) {
  final path = uri.path;
  if (session.isLoading && !session.hasValue) {
    return path == '/loading'
        ? null
        : Uri(
            path: '/loading',
            queryParameters: {'from': uri.toString()},
          ).toString();
  }
  final s = session.value;
  if (s == null) return path == '/sign-in' ? null : '/sign-in';
  const entry = {
    '/',
    '/sign-in',
    '/no-access',
    '/loading',
    '/request-access',
    '/pending',
  };
  // Superadmin (D-112): everything, starting at the Superadmin portal.
  if (s.superadmin) {
    if (!entry.contains(path)) return null;
    final from = uri.queryParameters['from'];
    return from != null && !entry.contains(Uri.parse(from).path)
        ? from
        : '/superadmin';
  }
  // Admin: approved by a Superadmin (free plan), or the earlier staff
  // claims with two-step sign-in (T-PRT-02).
  final a = access.value;
  if (!s.canUseConsole && a != StaffAccess.active) {
    if (access.isLoading && !access.hasValue) {
      return path == '/loading' ? null : '/loading';
    }
    final target = s.isStaff
        ? '/no-access'
        : switch (a) {
            StaffAccess.pending => '/pending',
            StaffAccess.removed => '/no-access',
            _ => '/request-access',
          };
    return path == target ? null : target;
  }
  // Approved on the free plan: start at Content (D-113/D-114); staff with
  // the earlier claims keep the catalog.
  final home = s.canUseConsole ? '/offers' : '/content';
  if (path.startsWith('/superadmin')) return home;
  if (entry.contains(path)) {
    final from = uri.queryParameters['from'];
    return from != null &&
            (from.startsWith('/offers') || from.startsWith('/content'))
        ? from
        : home;
  }
  final editing = path == '/offers/new' || path.endsWith('/edit');
  if (editing && !s.hasAny(editRoles)) return '/offers';
  return null;
}

class _SessionListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable();
  ref.listen(sessionProvider, (_, _) => refresh.ping());
  ref.listen(staffAccessProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    // '/' sends each person to their own start page (D-112).
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => adminRedirect(
      ref.read(sessionProvider),
      state.uri,
      access: ref.read(staffAccessProvider),
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/offers'),
      GoRoute(path: '/loading', builder: (_, _) => const LoadingScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessScreen()),
      // Staff access (D-112).
      GoRoute(
        path: '/request-access',
        builder: (_, _) => const RequestAccessScreen(),
      ),
      GoRoute(path: '/pending', builder: (_, _) => const PendingScreen()),
      // Lessons and courses (D-113/D-114).
      GoRoute(
        path: '/content',
        builder: (_, _) => const ContentScreen(),
        routes: [
          GoRoute(
            path: 'lessons/new',
            builder: (_, _) => const LessonEditorScreen(),
          ),
          GoRoute(
            path: 'lessons/:id',
            builder: (_, s) => LessonEditorScreen(id: s.pathParameters['id']),
          ),
          GoRoute(
            path: 'courses/new',
            builder: (_, _) => const CourseEditorScreen(),
          ),
          GoRoute(
            path: 'courses/:id',
            builder: (_, s) => CourseEditorScreen(id: s.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(path: '/superadmin', builder: (_, _) => const SuperadminScreen()),
      GoRoute(
        path: '/offers',
        builder: (_, _) => const OffersListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const OfferFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                OfferDetailScreen(offerId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) =>
                    OfferFormScreen(offerId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
