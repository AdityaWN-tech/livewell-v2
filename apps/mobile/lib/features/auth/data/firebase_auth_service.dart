import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' as fb show Firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth.dart';

/// Opens a provider's sign-in. Replaced in Auth-emulator tests, which can't
/// drive a browser.
typedef ProviderSignIn = Future<fb.UserCredential> Function(
  fb.AuthProvider provider,
);

/// Firebase Auth implementation of [AuthService]. Google and Apple use
/// Firebase's built-in provider flow (no extra SDK): native Sign in with
/// Apple on iOS, Firebase's web OAuth flow on Android.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([fb.FirebaseAuth? auth, this._providerSignIn])
    : _injected = auth;

  final fb.FirebaseAuth? _injected;
  final ProviderSignIn? _providerSignIn;

  PendingLink? _pending;
  fb.AuthCredential? _pendingCredential;

  /// Looked up on first use, so creating the service never needs Firebase.
  fb.FirebaseAuth get _auth => _injected ?? fb.FirebaseAuth.instance;

  static AuthUser toAuthUser(fb.User u) => _user(u);

  static AuthUser _user(fb.User u) => AuthUser(
    uid: u.uid,
    email: u.email,
    phoneNumber: u.phoneNumber,
    displayName: u.displayName,
    providers: [for (final p in u.providerData) p.providerId],
  );

  Future<AuthUser> _guard(Future<fb.UserCredential> Function() call) async {
    try {
      final cred = await call();
      return _user(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    }
  }

  @override
  AuthUser? get currentUser {
    // No Firebase app yet (widget tests, a failed startup): nobody signed in.
    if (fb.Firebase.apps.isEmpty && _injected == null) return null;
    final u = _auth.currentUser;
    return u == null ? null : _user(u);
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<AuthUser> createAccountWithEmail(String email, String password) async {
    final user = await _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    // A verified email is how the portal account is matched later (A-08).
    // Best effort: sign-up never fails because this email didn't go out.
    unawaited(_auth.currentUser?.sendEmailVerification().catchError((_) {}));
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<PhoneVerification> startPhoneSignIn(
    String phoneE164, {
    int? resendToken,
  }) => _verifyPhone(
    phoneE164,
    resendToken,
    (credential) => _auth.signInWithCredential(credential),
  );

  @override
  Future<PhoneVerification> startPhoneLink(
    String phoneE164, {
    int? resendToken,
  }) => _verifyPhone(
    phoneE164,
    resendToken,
    (credential) => _auth.currentUser!.linkWithCredential(credential),
  );

  /// Sends the SMS code. Android may read it by itself: then [onAuto] signs
  /// in or adds the number; the code screen still works if not.
  Future<PhoneVerification> _verifyPhone(
    String phoneE164,
    int? resendToken,
    Future<fb.UserCredential> Function(fb.PhoneAuthCredential) onAuto,
  ) {
    final result = Completer<PhoneVerification>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await onAuto(credential);
        } on fb.FirebaseAuthException {
          // The user can still type the code.
        }
      },
      verificationFailed: (e) {
        if (!result.isCompleted) {
          result.completeError(
            AuthException(authFailureFromCode(e.code), e.message),
          );
        }
      },
      codeSent: (verificationId, token) {
        if (!result.isCompleted) {
          result.complete(
            PhoneVerification(
              phoneNumber: phoneE164,
              verificationId: verificationId,
              resendToken: token,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return result.future;
  }

  @override
  Future<AuthUser> confirmPhoneCode(PhoneVerification v, String code) {
    // Auto-retrieval may already have signed the user in.
    final current = _auth.currentUser;
    if (current != null && current.phoneNumber == v.phoneNumber) {
      return Future.value(_user(current));
    }
    return _guard(
      () => _auth.signInWithCredential(
        fb.PhoneAuthProvider.credential(
          verificationId: v.verificationId,
          smsCode: code.trim(),
        ),
      ),
    );
  }

  static fb.AuthProvider _provider(SocialProvider p) => switch (p) {
    SocialProvider.google => fb.GoogleAuthProvider(),
    // Apple may hide the email (private relay); that is accepted.
    SocialProvider.apple =>
      fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name'),
  };

  Future<AuthUser> _social(SocialProvider p) async {
    try {
      final signIn = _providerSignIn ?? _auth.signInWithProvider;
      final cred = await signIn(_provider(p));
      final user = cred.user!;
      // Apple shares the name only on the first sign-in, and Firebase
      // doesn't copy it to the account: keep it there (T-UI-02c).
      if ((user.displayName?.trim().isEmpty ?? true) &&
          p == SocialProvider.apple) {
        final given = appleGivenName(cred.additionalUserInfo?.profile);
        if (given != null) {
          try {
            await user.updateDisplayName(given);
            await user.reload();
          } catch (_) {
            // Best effort; the person can add a name in Profile.
          }
          return _user(_auth.currentUser ?? user);
        }
      }
      return _user(user);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _pending = PendingLink(provider: p, email: e.email);
        _pendingCredential = e.credential;
      }
      throw AuthException(authFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() => _social(SocialProvider.google);

  @override
  Future<AuthUser> signInWithApple() => _social(SocialProvider.apple);

  @override
  PendingLink? get pendingLink => _pending;

  @override
  void clearPendingLink() {
    _pending = null;
    _pendingCredential = null;
  }

  @override
  Future<void> linkPending() async {
    final pending = _pending;
    final user = _auth.currentUser;
    if (pending == null || user == null) return;
    try {
      final credential = _pendingCredential;
      if (credential != null) {
        await user.linkWithCredential(credential);
      } else {
        // Some platforms don't return the credential: ask the provider again.
        await user.linkWithProvider(_provider(pending.provider));
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    } finally {
      clearPendingLink();
    }
  }

  @override
  Future<AuthUser> link(SocialProvider p) async {
    final user = _auth.currentUser!;
    try {
      final cred = await user.linkWithProvider(_provider(p));
      return _user(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<AuthUser> unlink(SocialProvider p) async {
    final user = _auth.currentUser!;
    if (user.providerData.length <= 1) {
      throw const AuthException(AuthFailure.lastMethod);
    }
    try {
      return _user(await user.unlink(p.providerId));
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<AuthUser> confirmPhoneLink(PhoneVerification v, String code) {
    final user = _auth.currentUser!;
    // Auto-retrieval may already have added it.
    if (user.phoneNumber == v.phoneNumber) return Future.value(_user(user));
    return _guard(
      () => user.linkWithCredential(
        fb.PhoneAuthProvider.credential(
          verificationId: v.verificationId,
          smsCode: code.trim(),
        ),
      ),
    );
  }

  @override
  Future<AuthUser> unlinkPhone() async {
    final user = _auth.currentUser!;
    if (user.providerData.length <= 1) {
      throw const AuthException(AuthFailure.lastMethod);
    }
    try {
      return _user(await user.unlink(fb.PhoneAuthProvider.PROVIDER_ID));
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
    await _auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(),
);

/// The first name in Apple's sign-in profile, if it sent one.
String? appleGivenName(Map<String, dynamic>? profile) {
  final name = profile?['name'];
  final candidates = [
    if (name is Map) name['firstName'],
    profile?['given_name'],
    profile?['firstName'],
  ];
  for (final c in candidates) {
    if (c is String && c.trim().isNotEmpty) return c.trim();
  }
  return null;
}

/// The signed-in account's uid, as a value providers can watch (T-ONB-03g).
/// [AuthService.currentUser] is a plain getter, so a provider that read it
/// while nobody was signed in (the theme reads the profile at startup) kept
/// "signed out" after a first sign-up until the app restarted: Home showed
/// no name, Why or Day. Sign-in completion and log out call [refresh].
class SignedInUid extends Notifier<String?> {
  @override
  String? build() => ref.read(authServiceProvider).currentUser?.uid;

  void refresh() => state = ref.read(authServiceProvider).currentUser?.uid;
}

final signedInUidProvider = NotifierProvider<SignedInUid, String?>(
  SignedInUid.new,
);
