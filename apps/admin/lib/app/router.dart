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

/// The role gate (T-PRT-02, D-92). Pure, so it is unit-tested. Signed out:
/// sign-in. Signed in without a staff role or without MFA: no-access.
/// Editing routes need an editing role. The Core API checks again on every
/// call; this only keeps people off screens they can't use.
String? adminRedirect(AsyncValue<StaffSession?> session, Uri uri) {
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
  if (!s.canUseConsole) return path == '/no-access' ? null : '/no-access';
  if (path == '/sign-in' || path == '/no-access' || path == '/loading') {
    final from = uri.queryParameters['from'];
    return from != null && from.startsWith('/offers') ? from : '/offers';
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
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    initialLocation: '/offers',
    refreshListenable: refresh,
    redirect: (context, state) =>
        adminRedirect(ref.read(sessionProvider), state.uri),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/offers'),
      GoRoute(path: '/loading', builder: (_, _) => const LoadingScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessScreen()),
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
