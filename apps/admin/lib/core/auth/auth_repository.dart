import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'staff.dart';

/// Sign-in for staff. Email and password accounts made by the owner; MFA is
/// enforced by the Core API (D-92). No self sign-up.
abstract class AuthRepository {
  /// The current session, again whenever the user or their token changes.
  Stream<StaffSession?> sessions();

  Future<void> signIn({required String email, required String password});

  /// Google sign-in (D-112): how staff and Superadmins sign in.
  Future<void> signInWithGoogle();

  /// Gets a fresh token, so roles the owner just changed apply.
  Future<void> refresh();

  Future<void> signOut();
}

/// Why sign-in failed, in words staff can act on. No details are logged.
class SignInFailure implements Exception {
  const SignInFailure(this.message);
  final String message;
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<StaffSession?> sessions() => _auth.idTokenChanges().asyncMap(
    (user) async => user == null ? null : _session(user),
  );

  Future<StaffSession> _session(User user, {bool force = false}) async {
    final token = await user.getIdTokenResult(force);
    return StaffSession.fromClaims(
      uid: user.uid,
      email: user.email,
      claims: Map<String, Object?>.from(token.claims ?? const {}),
      now: DateTime.now(),
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthMultiFactorException {
      // TODO(D-92): second-factor sign-in once the owner picks the MFA method.
      throw const SignInFailure(
        'This account uses two-step sign-in, which this console does not '
        'support yet. Ask the owner.',
      );
    } on FirebaseAuthException catch (e) {
      throw SignInFailure(switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account is turned off.',
        'too-many-requests' => 'Too many tries. Wait a few minutes.',
        'network-request-failed' => 'No connection. Check your network.',
        _ => 'Email or password is not right.',
      });
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _auth.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      throw SignInFailure(switch (e.code) {
        'popup-blocked' => 'Your browser blocked the sign-in window. Allow pop-ups and try again.',
        'network-request-failed' => 'No connection. Check your network.',
        _ => 'Google sign-in did not work. Try again.',
      });
    }
  }

  @override
  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user != null) await user.getIdToken(true);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Overridden in main.dart (Firebase) and in tests (fakes).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider not overridden'),
);

final sessionProvider = StreamProvider<StaffSession?>(
  (ref) => ref.watch(authRepositoryProvider).sessions(),
);
