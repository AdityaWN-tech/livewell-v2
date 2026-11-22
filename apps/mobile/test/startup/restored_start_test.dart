import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

/// Cold start with a sign-in restored from the phone (NFR-01: Home fast).
/// The profile cached on the phone is enough: no server round trip.
void main() {
  Harness signedIn() {
    final h = Harness(
      auth: FakeAuthService(signedIn: const AuthUser(uid: 'u1')),
    );
    h.profiles.existing['u1'] = ProfileStep.assessment;
    return h;
  }

  testWidgets('cached profile: Home without reading the server', (
    tester,
  ) async {
    final h = signedIn();
    await h.boot(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(h.profiles.cacheReads, 1);
    // Startup itself made no server read (later screens may watch live).
    expect(h.profiles.created, isEmpty);
  });

  testWidgets('nothing cached (new phone): asks the server, still Home', (
    tester,
  ) async {
    final h = signedIn()..profiles.cacheEmpty = true;
    await h.boot(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(h.profiles.cacheReads, 1);
    expect(h.profiles.serverReads, greaterThanOrEqualTo(1));
  });

  testWidgets('no profile at all: onboarding, not Home', (tester) async {
    final h = Harness(
      auth: FakeAuthService(signedIn: const AuthUser(uid: 'u2')),
    );
    await h.boot(tester);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
