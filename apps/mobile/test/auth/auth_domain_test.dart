import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/auth/domain/auth.dart';

void main() {
  group('PhoneCountry: any country (D-99)', () {
    test('covers every country, including the US and India', () {
      expect(PhoneCountry.all.length, greaterThan(240));
      expect(PhoneCountry.byIso('us'), PhoneCountry.us);
      expect(PhoneCountry.us.dialCode, '+1');
      expect(PhoneCountry.india.dialCode, '+91');
      expect(PhoneCountry.byIso('GB')!.dialCode, '+44');
      expect(PhoneCountry.byIso('NP')!.dialCode, '+977');
      expect(PhoneCountry.byIso('ZZ'), isNull);
      expect(PhoneCountry.byIso(null), isNull);
      expect(PhoneCountry.us.flag, '\u{1F1FA}\u{1F1F8}');
    });

    test('pre-selects the device country, else the US', () {
      expect(PhoneCountry.initial('IN'), PhoneCountry.india);
      expect(PhoneCountry.initial('gb').isoCode, 'GB');
      expect(PhoneCountry.initial(null), PhoneCountry.us);
      expect(PhoneCountry.initial('ZZ'), PhoneCountry.us);
    });

    test('US: valid North American numbers, in any common format', () {
      final c = PhoneCountry.us;
      expect(c.toE164('(212) 555-0123'), '+12125550123');
      expect(c.toE164('212.555.0123'), '+12125550123');
      expect(c.toE164('+1 212 555 0123'), '+12125550123');
      expect(c.toE164('1 212 555 0123'), '+12125550123');
    });

    test('US: area codes or exchanges starting with 0 or 1, wrong lengths', () {
      final c = PhoneCountry.us;
      expect(c.toE164('112 555 0123'), isNull);
      expect(c.toE164('212 155 0123'), isNull);
      expect(c.toE164('212 555 012'), isNull);
      expect(c.toE164('212 555 01234'), isNull);
    });

    test('India: 10-digit mobiles, with or without 0 or 91 in front', () {
      final c = PhoneCountry.india;
      expect(c.toE164('98765 43210'), '+919876543210');
      expect(c.toE164('098765 43210'), '+919876543210');
      expect(c.toE164('+91 98765 43210'), '+919876543210');
      expect(c.toE164('91 98765 43210'), '+919876543210');
      expect(c.toE164('98765 4321'), isNull, reason: 'too short');
      expect(c.toE164('98765 432100'), isNull, reason: 'too long');
      expect(c.toE164('12345 67890'), isNull, reason: 'not a mobile range');
    });

    test('other countries normalise to E.164 and reject wrong lengths', () {
      final cases = {
        'GB': ('07400 123456', '+447400123456', '07400 12345'),
        'AU': ('0412 345 678', '+61412345678', '0412 345 67'),
        'AE': ('050 123 4567', '+971501234567', '050 123 456'),
        'NP': ('984 1234567', '+9779841234567', '984 123456'),
        'CA': ('416 555 0123', '+14165550123', '416 555 012'),
      };
      for (final MapEntry(key: iso, value: (input, e164, short))
          in cases.entries) {
        final c = PhoneCountry.byIso(iso)!;
        expect(c.toE164(input), e164, reason: iso);
        expect(c.toE164(short), isNull, reason: '$iso short');
        // Typed with its own +code, the same number comes out.
        expect(
          c.toE164('${c.dialCode} ${input.replaceFirst(RegExp('^0'), '')}'),
          e164,
        );
      }
    });

    test('a typed +code is read as international, whatever is selected', () {
      expect(PhoneCountry.us.toE164('+44 7400 123456'), '+447400123456');
      expect(PhoneCountry.india.toE164('+1 212 555 0123'), '+12125550123');
      // Without the +, the digits belong to the selected country.
      expect(PhoneCountry.us.toE164('91 98765 43210'), isNull);
    });

    test('rejects letters, empty input, a lone + and unknown codes', () {
      final c = PhoneCountry.us;
      expect(c.toE164(''), isNull);
      expect(c.toE164('+'), isNull);
      expect(c.toE164('abc'), isNull);
      expect(c.toE164('212-555-01ab'), isNull);
      expect(c.toE164('212+555+0123'), isNull);
      expect(c.toE164('+999 123 456 789'), isNull);
      expect(c.toE164('1234567890123456'), isNull, reason: 'over 15 digits');
    });

    test('a landline is not accepted (a code needs a mobile)', () {
      // London fixed line.
      expect(PhoneCountry.byIso('GB')!.toE164('020 7946 0018'), isNull);
    });
  });

  group('inferRegion (D-03: never guess)', () {
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
    // D-99: phone sign-in now accepts any country. The phone code must
    // never set a region other than IN or US, whatever the device says.
    test('non-IN/US phone codes stay null on any device (D-99)', () {
      for (final phone in [
        '+447400123456', // UK
        '+61412345678', // Australia
        '+971501234567', // UAE
        '+9779841234567', // Nepal
        '+14165550123', // Canada (+1) on a non-US device
      ]) {
        for (final device in [null, 'US', 'IN', 'GB', 'AU', 'AE', 'NP', 'CA']) {
          if (phone.startsWith('+1') && device == 'US') continue;
          expect(
            inferRegion(phoneE164: phone, deviceCountry: device),
            isNull,
            reason: '$phone on $device',
          );
        }
      }
    });
    test('the picked country never feeds the region: only the number does', () {
      // A Nepali number entered with India picked is still +977: null.
      final e164 = PhoneCountry.india.toE164('+977 984 1234567')!;
      expect(inferRegion(phoneE164: e164, deviceCountry: 'IN'), isNull);
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
