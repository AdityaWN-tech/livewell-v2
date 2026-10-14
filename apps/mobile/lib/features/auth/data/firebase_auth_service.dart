import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth.dart';

/// Firebase Auth implementation of [AuthService]. Google and Apple use
/// Firebase's built-in provider flow (no extra SDK); Apple is offered on iOS
/// only (needs the Apple Developer account, see docs/setup).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final fb.FirebaseAuth _auth;

  static AuthUser toAuthUser(fb.User u) => _user(u);

  static AuthUser _user(fb.User u) => AuthUser(
    uid: u.uid,
    email: u.email,
    phoneNumber: u.phoneNumber,
    displayName: u.displayName,
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
  }) {
    final result = Completer<PhoneVerification>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      // Android may read the SMS itself; the code screen still works if not.
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
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

  @override
  Future<AuthUser> signInWithGoogle() =>
      _guard(() => _auth.signInWithProvider(fb.GoogleAuthProvider()));

  @override
  Future<AuthUser> signInWithApple() => _guard(
    () => _auth.signInWithProvider(
      fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name'),
    ),
  );

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
    await _auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(fb.FirebaseAuth.instance),
);
