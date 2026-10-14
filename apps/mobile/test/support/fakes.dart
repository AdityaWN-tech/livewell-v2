import 'package:livewell/core/speech/dictation.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

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
class FakeProfileRepository extends ProfileRepository {
  final created = <String, NewProfile>{};

  /// Profiles that already existed, by uid -> onboarding step.
  final existing = <String, String>{};
  final whys = <String, String>{};

  /// Region for profiles in [existing] ('US' / 'IN').
  final regions = <String, String>{};
  final log = <String>[];

  String? _step(String uid) => existing[uid] ?? created[uid]?.onboardingStep;

  @override
  Future<Profile?> get(String uid) async {
    final step = _step(uid);
    if (step == null) return null;
    return Profile(
      uid: uid,
      onboardingStep: step,
      whyStatement: whys[uid],
      region: regions[uid] ?? created[uid]?.region,
    );
  }

  @override
  Stream<Profile?> watch(String uid) async* {
    yield await get(uid);
  }

  @override
  Future<void> create(String uid, NewProfile profile) async {
    log.add('profile:$uid');
    created[uid] = profile;
  }

  @override
  Future<void> saveWhy(
    String uid,
    String why, {
    required String nextStep,
  }) async {
    log.add('why:$uid');
    whys[uid] = why.trim();
    if (existing.containsKey(uid)) {
      existing[uid] = nextStep;
    } else {
      final p = created[uid]!;
      created[uid] = NewProfile(
        displayName: p.displayName,
        email: p.email,
        locale: p.locale,
        region: p.region,
        onboardingStep: nextStep,
      );
    }
  }
}

/// Voice typing stand-in: [available] decides whether it starts; [say]
/// delivers words as if spoken.
class FakeDictation implements Dictation {
  bool available = true;
  bool listening = false;
  void Function(String, bool)? _onText;

  @override
  Future<bool> start(void Function(String text, bool isFinal) onText) async {
    if (!available) return false;
    listening = true;
    _onText = onText;
    return true;
  }

  void say(String words, {bool isFinal = true}) {
    _onText?.call(words, isFinal);
    if (isFinal) listening = false;
  }

  @override
  Future<void> stop() async => listening = false;
}

/// Records the numbers the app tried to call or text.
class FakePhoneLauncher implements PhoneLauncher {
  final calls = <String>[];
  final texts = <String>[];

  @override
  Future<bool> call(String number) async {
    calls.add(number);
    return true;
  }

  @override
  Future<bool> text(String number) async {
    texts.add(number);
    return true;
  }
}
