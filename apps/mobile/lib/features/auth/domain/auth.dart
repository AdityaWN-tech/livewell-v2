/// Sign-in domain (FR-ONB-01, D-02): email, phone OTP, Google, Apple.
library;

import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pn;

/// The signed-in person, as the app needs them.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.providers = const [],
  });

  final String uid;

  /// Sign-in methods on this account: 'password', 'phone', 'google.com',
  /// 'apple.com'.
  final List<String> providers;
  final String? email;

  /// E.164, e.g. +12125550123.
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

  /// The only sign-in method left can't be removed.
  lastMethod,

  /// Adding a phone number that another Live Well account already uses
  /// (Firebase credential-already-in-use).
  phoneInUse,

  /// This account already has a phone number.
  alreadyLinked,

  /// Google or Apple found a Live Well account with the same email that
  /// was made another way (Firebase account-exists-with-different-credential).
  accountExists,

  /// Firebase couldn't confirm this is the real app (Play Integrity or the
  /// reCAPTCHA check failed, or this build's signing key isn't registered;
  /// D-58). Phone codes can't be sent until it can.
  appNotVerified,
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
  'email-already-in-use' => AuthFailure.emailInUse,
  'credential-already-in-use' => AuthFailure.phoneInUse,
  'provider-already-linked' => AuthFailure.alreadyLinked,
  'account-exists-with-different-credential' => AuthFailure.accountExists,
  'weak-password' => AuthFailure.weakPassword,
  'invalid-phone-number' || 'missing-phone-number' => AuthFailure.invalidPhone,
  'invalid-verification-code' ||
  'missing-verification-code' => AuthFailure.wrongCode,
  'session-expired' || 'code-expired' => AuthFailure.codeExpired,
  'too-many-requests' || 'quota-exceeded' => AuthFailure.tooManyRequests,
  'network-request-failed' => AuthFailure.network,
  'operation-not-allowed' => AuthFailure.methodDisabled,
  'app-not-authorized' ||
  'invalid-app-credential' ||
  'missing-app-credential' ||
  'missing-client-identifier' ||
  'captcha-check-failed' ||
  'missing-recaptcha-token' ||
  'invalid-recaptcha-token' ||
  'web-internal-error' => AuthFailure.appNotVerified,
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

/// A country offered for phone sign-in and Profile > Add a phone number.
/// Any country (D-99, reverses D-66 for phone). Validation and E.164 come from
/// `phone_numbers_parser` (Google libphonenumber metadata, pure Dart).
///
/// The chosen country only shapes the number. It never sets the safety
/// region: that comes from [inferRegion] on the verified number (D-03).
class PhoneCountry {
  PhoneCountry._(this.iso)
    : dialCode = '+${pn.PhoneNumber(isoCode: iso, nsn: '').countryCode}';

  final pn.IsoCode iso;

  /// E.g. '+44'. Shared by several countries for +1, +7, +44 and others.
  final String dialCode;

  /// ISO 3166-1 alpha-2, e.g. 'GB'.
  String get isoCode => iso.name;

  /// Every country the phone metadata knows, in ISO code order.
  static final List<PhoneCountry> all = List.unmodifiable(
    pn.IsoCode.values.map(PhoneCountry._),
  );

  static final Map<String, PhoneCountry> _byIso = {
    for (final c in all) c.isoCode: c,
  };

  static final PhoneCountry us = _byIso['US']!;
  static final PhoneCountry india = _byIso['IN']!;

  /// The country for an ISO code (any case), or null if unknown.
  static PhoneCountry? byIso(String? isoCode) =>
      isoCode == null ? null : _byIso[isoCode.toUpperCase()];

  /// Pre-selected country: the device's country if known, else the US.
  /// Only a convenience for typing; the user can change it.
  static PhoneCountry initial(String? deviceCountry) =>
      byIso(deviceCountry) ?? us;

  /// Flag emoji from the ISO code (regional indicator letters).
  String get flag =>
      String.fromCharCodes(isoCode.codeUnits.map((c) => 0x1F1E6 + c - 0x41));

  /// E.164 form of a mobile number typed for this country, or null if it
  /// can't be a valid mobile number. A leading national prefix (e.g. the 0
  /// in 07400 123456) is accepted. A number typed with a leading
  /// `+<code>` is read as international and must be a valid mobile number
  /// for that code's country, which may differ from this one.
  String? toE164(String input) {
    final trimmed = input.trim();
    if (!RegExp(r'^\+?[0-9 ().\-]+$').hasMatch(trimmed)) return null;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4 || digits.length > 15) return null;
    try {
      final number = trimmed.startsWith('+')
          ? pn.PhoneNumber.parse('+$digits')
          : pn.PhoneNumber.parse(digits, destinationCountry: iso);
      if (!number.isValid(type: pn.PhoneNumberType.mobile)) return null;
      final e164 = number.international;
      return e164.length <= 16 ? e164 : null;
    } on Object {
      return null;
    }
  }

  @override
  String toString() => 'PhoneCountry($isoCode)';
}

/// Region for safety numbers and legal texts (D-03). Phone numbers from any
/// country are accepted (D-99), but only +91 maps to India. Never guessed:
/// +1 is shared with Canada and the Caribbean, so it means US only when the
/// device is also set to the US; every other code is null. Null means "ask
/// the user later" (and, until then, both IN and US numbers are shown).
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

/// One-tap sign-in providers.
enum SocialProvider {
  google('Google', 'google.com'),
  apple('Apple', 'apple.com');

  const SocialProvider(this.brandName, this.providerId);

  /// Brand name, never translated.
  final String brandName;

  /// Firebase provider id.
  final String providerId;
}

/// A Google or Apple sign-in that hit an existing account with the same
/// email. Offered for linking once the person signs in the original way.
class PendingLink {
  const PendingLink({required this.provider, this.email});

  final SocialProvider provider;
  final String? email;

  /// Only link into the account that owns the same email, never another.
  bool matches(AuthUser user) =>
      email != null &&
      user.email != null &&
      user.email!.trim().toLowerCase() == email!.trim().toLowerCase();
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

  /// One tap signs in, or signs up when no account exists yet.
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();

  /// Set when the last Google/Apple attempt failed with
  /// [AuthFailure.accountExists]; cleared by [clearPendingLink].
  PendingLink? get pendingLink;

  /// Adds the pending Google/Apple sign-in to the signed-in account.
  Future<void> linkPending();
  void clearPendingLink();

  /// Adds Google or Apple to the signed-in account (Profile).
  Future<AuthUser> link(SocialProvider provider);

  /// Removes Google or Apple; refuses to remove the last sign-in method.
  Future<AuthUser> unlink(SocialProvider provider);

  /// Adds a phone number to the signed-in account (Profile, Step 4c):
  /// sends a code like [startPhoneSignIn], but a code the phone reads by
  /// itself is added to this account, never used to sign in.
  Future<PhoneVerification> startPhoneLink(
    String phoneE164, {
    int? resendToken,
  });

  /// Adds the verified number to the signed-in account.
  Future<AuthUser> confirmPhoneLink(
    PhoneVerification verification,
    String code,
  );

  /// Removes the phone number; refuses to remove the last sign-in method.
  Future<AuthUser> unlinkPhone();

  Future<void> signOut();

  /// Deletes the signed-in account (used when someone under 18 signed in
  /// before the age check, FR-ONB-04).
  Future<void> deleteCurrentUser();
}
