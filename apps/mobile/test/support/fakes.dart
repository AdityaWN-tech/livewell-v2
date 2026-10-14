import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';

/// In-memory sign-in for widget tests.
class FakeAuthService implements AuthService {
  FakeAuthService({this.signedIn});

  AuthUser? signedIn;
  final emailAccounts = <String, String>{}; // email -> password
  String validCode = '123456';
  int codesSent = 0;
  bool deleted = false;
  AuthFailure? googleFailure;

  @override
  AuthUser? get currentUser => signedIn;

  AuthUser _signIn(AuthUser u) => signedIn = u;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    if (emailAccounts[email.trim()] != password) {
      throw const AuthException(AuthFailure.wrongCredentials);
    }
    return _signIn(AuthUser(uid: 'email:$email', email: email.trim()));
  }

  @override
  Future<AuthUser> createAccountWithEmail(String email, String password) async {
    if (emailAccounts.containsKey(email.trim())) {
      throw const AuthException(AuthFailure.emailInUse);
    }
    emailAccounts[email.trim()] = password;
    return _signIn(AuthUser(uid: 'email:$email', email: email.trim()));
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<PhoneVerification> startPhoneSignIn(
    String phoneE164, {
    int? resendToken,
  }) async {
    codesSent++;
    return PhoneVerification(
      phoneNumber: phoneE164,
      verificationId: 'v$codesSent',
      resendToken: codesSent,
    );
  }

  @override
  Future<AuthUser> confirmPhoneCode(PhoneVerification v, String code) async {
    if (code != validCode) throw const AuthException(AuthFailure.wrongCode);
    return _signIn(
      AuthUser(uid: 'phone:${v.phoneNumber}', phoneNumber: v.phoneNumber),
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (googleFailure != null) throw AuthException(googleFailure!);
    return _signIn(
      const AuthUser(
        uid: 'google:1',
        email: 'priya@example.com',
        displayName: 'Priya',
      ),
    );
  }

  @override
  Future<AuthUser> signInWithApple() async =>
      _signIn(const AuthUser(uid: 'apple:1'));

  @override
  Future<void> signOut() async => signedIn = null;

  @override
  Future<void> deleteCurrentUser() async {
    deleted = true;
    signedIn = null;
  }
}

/// In-memory profiles.
class FakeProfileRepository implements ProfileRepository {
  final created = <String, NewProfile>{};
  final existing = <String>{};
  final log = <String>[];

  @override
  Future<bool> exists(String uid) async =>
      existing.contains(uid) || created.containsKey(uid);

  @override
  Future<void> create(String uid, NewProfile profile) async {
    log.add('profile:$uid');
    created[uid] = profile;
  }
}
