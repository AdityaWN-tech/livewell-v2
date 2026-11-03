import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/auth/domain/auth.dart';

void main() {
  test('phone sign-in offers US (+1) only (D-66)', () {
    expect(PhoneCountry.values, [PhoneCountry.us]);
    expect(PhoneCountry.us.toE164('+91 98765 43210'), isNull);
  });

  group('PhoneCountry.us', () {
    const c = PhoneCountry.us;
    test('accepts valid North American numbers', () {
      expect(c.toE164('(212) 555-0123'), '+12125550123');
      expect(c.toE164('+1 212 555 0123'), '+12125550123');
    });
    test('rejects area codes or exchanges starting with 0 or 1', () {
      expect(c.toE164('112 555 0123'), isNull);
      expect(c.toE164('212 155 0123'), isNull);
      expect(c.toE164('212 555 012'), isNull);
    });
  });

  group('inferRegion (D-03: never guess)', () {
    // Kept although new phone numbers are +1 only (D-66): any +91 account
    // must still get India's emergency and crisis numbers.
    test('+91 is India', () {
      expect(inferRegion(phoneE164: '+919876543210'), 'IN');
    });
    test('+1 is US only when the device is set to the US', () {
      expect(inferRegion(phoneE164: '+12125550123', deviceCountry: 'US'), 'US');
      expect(
        inferRegion(phoneE164: '+12125550123', deviceCountry: 'CA'),
        isNull,
      );
      expect(inferRegion(phoneE164: '+12125550123'), isNull);
    });
    test('without a phone, the device country decides if it is IN or US', () {
      expect(inferRegion(deviceCountry: 'in'), 'IN');
      expect(inferRegion(deviceCountry: 'US'), 'US');
      expect(inferRegion(deviceCountry: 'GB'), isNull);
      expect(inferRegion(), isNull);
    });
    test('other phone codes are left for the user to choose', () {
      expect(
        inferRegion(phoneE164: '+447700900123', deviceCountry: 'US'),
        isNull,
      );
    });
  });

  test('Firebase error codes map to actionable failures', () {
    expect(authFailureFromCode('wrong-password'), AuthFailure.wrongCredentials);
    expect(
      authFailureFromCode('invalid-credential'),
      AuthFailure.wrongCredentials,
    );
    expect(authFailureFromCode('email-already-in-use'), AuthFailure.emailInUse);
    expect(
      authFailureFromCode('invalid-verification-code'),
      AuthFailure.wrongCode,
    );
    expect(authFailureFromCode('session-expired'), AuthFailure.codeExpired);
    expect(authFailureFromCode('network-request-failed'), AuthFailure.network);
    expect(
      authFailureFromCode('operation-not-allowed'),
      AuthFailure.methodDisabled,
    );
    expect(authFailureFromCode('web-context-canceled'), AuthFailure.cancelled);
    expect(authFailureFromCode('something-new'), AuthFailure.unknown);
  });

  test('app-verification failures in phone sign-in say so (D-58)', () {
    for (final code in [
      'app-not-authorized',
      'invalid-app-credential',
      'missing-client-identifier',
      'captcha-check-failed',
      'web-internal-error',
    ]) {
      expect(
        authFailureFromCode(code),
        AuthFailure.appNotVerified,
        reason: code,
      );
    }
    // The native Google picker reports a cancel as "cancelled".
    expect(authFailureFromCode('cancelled'), AuthFailure.cancelled);
  });
}
