import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/data/firebase_auth_service.dart';
import 'package:livewell/features/auth/domain/auth.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

/// T-UI-02c: Google or Apple names are used, so Home can say
/// "Hi, {first name}" without asking.
void main() {
  Harness withProfile({String? profileName, String? googleName}) {
    final h = Harness(
      auth: FakeAuthService(
        signedIn: AuthUser(uid: 'u1', displayName: googleName),
      ),
      namePrompt: FakeNamePromptStore(wasAsked: false),
    );
    h.profiles.existing['u1'] = ProfileStep.assessment;
    if (profileName != null) h.profiles.names['u1'] = profileName;
    return h;
  }

  testWidgets('no name yet, Google has one: it is saved and used', (
    tester,
  ) async {
    final h = withProfile(googleName: 'Asha Rao');
    await h.boot(tester);
    expect(h.profiles.names['u1'], 'Asha Rao');
    expect(find.textContaining('Good morning, Asha!'), findsOneWidget);
    expect(find.text('What should your coach call you?'), findsNothing);
  });

  testWidgets('a name the person chose is never replaced', (tester) async {
    final h = withProfile(profileName: 'Ash', googleName: 'Asha Rao');
    await h.boot(tester);
    expect(h.profiles.names['u1'], 'Ash');
    expect(find.textContaining('Good morning, Ash!'), findsOneWidget);
  });

  testWidgets('no name anywhere: Home asks once', (tester) async {
    await withProfile().boot(tester);
    expect(find.text('What should your coach call you?'), findsOneWidget);
  });

  test('Apple\'s first-sign-in name is read from its profile', () {
    expect(
      appleGivenName({
        'name': {'firstName': 'Asha', 'lastName': 'Rao'},
      }),
      'Asha',
    );
    expect(appleGivenName({'given_name': ' Ravi '}), 'Ravi');
    expect(appleGivenName({'email': 'x@privaterelay.appleid.com'}), isNull);
    expect(appleGivenName(null), isNull);
  });
}
