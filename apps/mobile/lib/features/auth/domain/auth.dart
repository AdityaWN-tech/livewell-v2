/// Sign-in domain (FR-ONB-01, D-02): email, phone OTP, Google, Apple.
library;

/// The signed-in person, as the app needs them.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
  });

  final String uid;
  final String? email;

  /// E.164, e.g. +919876543210.
  final String? phoneNumber;
  final String? displayName;
}

/// Why sign-in failed, in terms the user can act on.
enum AuthFailure {
  invalidEmail,
  wrongCredentials,
  emailInUse,
  weakPassword,
  invalidPhone,
  wrongCode,
  codeExpired,
  tooManyRequests,
  network,
  methodDisabled,
  cancelled,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure, [this.detail]);

  final AuthFailure failure;
  final String? detail;

  @override
  String toString() => 'AuthException($failure, $detail)';
}

/// Maps Firebase Auth error codes to [AuthFailure].
AuthFailure authFailureFromCode(String code) => switch (code) {
  'invalid-email' => AuthFailure.invalidEmail,
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => AuthFailure.wrongCredentials,
  'email-already-in-use' ||
  'account-exists-with-different-credential' => AuthFailure.emailInUse,
  'weak-password' => AuthFailure.weakPassword,
  'invalid-phone-number' || 'missing-phone-number' => AuthFailure.invalidPhone,
  'invalid-verification-code' ||
  'missing-verification-code' => AuthFailure.wrongCode,
  'session-expired' || 'code-expired' => AuthFailure.codeExpired,
  'too-many-requests' || 'quota-exceeded' => AuthFailure.tooManyRequests,
  'network-request-failed' => AuthFailure.network,
  'operation-not-allowed' => AuthFailure.methodDisabled,
  'web-context-canceled' ||
  'canceled' ||
  'cancelled' ||
  'web-context-cancelled' => AuthFailure.cancelled,
  _ => AuthFailure.unknown,
};

/// A phone number sent a code, waiting for the user to type it.
class PhoneVerification {
  const PhoneVerification({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
}

/// Countries offered for phone sign-in (markets India and US, D-03).
enum PhoneCountry {
  india('IN', '+91', 10),
  us('US', '+1', 10);

  const PhoneCountry(this.isoCode, this.dialCode, this.nationalLength);

  final String isoCode;
  final String dialCode;
  final int nationalLength;

  /// Digits only, without the country code; null if it can't be a valid
  /// number for this country.
  String? normalise(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    // Allow people to type the country code or a leading trunk 0.
    final cc = dialCode.substring(1);
    if (digits.length == nationalLength + cc.length && digits.startsWith(cc)) {
      digits = digits.substring(cc.length);
    }
    if (this == PhoneCountry.india &&
        digits.length == 11 &&
        digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != nationalLength) return null;
    return switch (this) {
      // Indian mobile numbers start with 6-9.
      PhoneCountry.india => RegExp(r'^[6-9]').hasMatch(digits) ? digits : null,
      // NANP: area code and exchange can't start with 0 or 1.
      PhoneCountry.us =>
        RegExp(r'^[2-9][0-9]{2}[2-9]').hasMatch(digits) ? digits : null,
    };
  }

  /// E.164 form, or null if invalid.
  String? toE164(String input) {
    final national = normalise(input);
    return national == null ? null : '$dialCode$national';
  }
}

/// Region for safety numbers and legal texts (D-03). Never guessed: +1 is
/// shared with Canada and the Caribbean, so it means US only when the device
/// is also set to the US. Null means "ask the user later".
String? inferRegion({String? phoneE164, String? deviceCountry}) {
  final country = deviceCountry?.toUpperCase();
  if (phoneE164 != null) {
    if (phoneE164.startsWith('+91')) return 'IN';
    if (phoneE164.startsWith('+1')) return country == 'US' ? 'US' : null;
    return null;
  }
  return switch (country) {
    'IN' => 'IN',
    'US' => 'US',
    _ => null,
  };
}

/// Sign-in operations. Firebase implementation in data/; fakes in tests.
abstract class AuthService {
  AuthUser? get currentUser;

  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> createAccountWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);

  /// Sends a code by SMS. Throws [AuthException] on failure.
  Future<PhoneVerification> startPhoneSignIn(
    String phoneE164, {
    int? resendToken,
  });
  Future<AuthUser> confirmPhoneCode(
    PhoneVerification verification,
    String code,
  );

  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();

  Future<void> signOut();

  /// Deletes the signed-in account (used when someone under 18 signed in
  /// before the age check, FR-ONB-04).
  Future<void> deleteCurrentUser();
}
