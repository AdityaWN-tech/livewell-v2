import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/voice/domain/device_voice.dart';
import 'package:livewell/features/voice/domain/voice.dart';

/// D-49: the phone voice closest to the library voice the person chose.

DeviceVoice v(String name, String locale, {String? gender}) =>
    DeviceVoice(name: name, locale: locale, gender: gender);

/// What Google's speech engine typically offers on Android.
final google = [
  v('en-us-x-sfg-local', 'en-US'),
  v('en-us-x-sfg-network', 'en-US'),
  v('en-us-x-iom-local', 'en-US'),
  v('en-us-x-iom-network', 'en-US'),
  v('en-gb-x-gba-local', 'en-GB'),
  v('en-gb-x-gbd-local', 'en-GB'),
  v('en-in-x-ahp-local', 'en-IN'),
  v('hi-in-x-hia-local', 'hi-IN'),
];

({DeviceVoice? voice, double pitch}) pick(String id, List<DeviceVoice> vs) =>
    pickDeviceVoice(vs, profileFor(VoiceLibrary.byId(id)));

void main() {
  test('every library voice has its own profile', () {
    final profiles = {for (final lv in VoiceLibrary.all) lv.id: profileFor(lv)};
    final kinds = {
      for (final p in profiles.values) '${p.locale}/${p.female}/${p.pitch}',
    };
    expect(kinds, hasLength(VoiceLibrary.all.length));
    expect(profiles['lw-gentle']!.locale, 'en-GB');
    expect(profiles['lw-deep']!.female, isFalse);
    expect(profiles['lw-deep']!.pitch, lessThan(1));
    expect(profiles['lw-bright']!.pitch, greaterThan(1));
  });

  group('on Google speech (Android)', () {
    test('accent and voice match; offline voices first', () {
      expect(pick('lw-warm', google).voice!.name, 'en-us-x-sfg-local');
      expect(pick('lw-steady', google).voice!.name, 'en-us-x-iom-local');
      expect(pick('lw-gentle', google).voice!.name, 'en-gb-x-gba-local');
      expect(pick('lw-clear', google).voice!.name, 'en-gb-x-gbd-local');
    });

    test('each choice sounds different (voice or pitch)', () {
      final results = {
        for (final lv in VoiceLibrary.all)
          '${pick(lv.id, google).voice!.name}@${pick(lv.id, google).pitch}',
      };
      expect(results, hasLength(VoiceLibrary.all.length));
    });

    test('Deep is lower than Steady, Bright higher than Warm', () {
      expect(
        pick('lw-deep', google).pitch,
        lessThan(pick('lw-steady', google).pitch),
      );
      expect(
        pick('lw-bright', google).pitch,
        greaterThan(pick('lw-warm', google).pitch),
      );
    });
  });

  test('engines that say the gender (iOS, Samsung) are used too', () {
    final ios = [
      v('Samantha', 'en-US', gender: 'female'),
      v('Fred', 'en-US', gender: 'male'),
      v('Daniel', 'en-GB', gender: 'male'),
    ];
    expect(pick('lw-steady', ios).voice!.name, 'Fred');
    expect(pick('lw-warm', ios).voice!.name, 'Samantha');
    final samsung = [
      v('en-US-SMTf00', 'en_US'),
      v('en-us#female_2-local', 'en_US'),
      v('en-us#male_1-local', 'en_US'),
    ];
    expect(pick('lw-steady', samsung).voice!.name, 'en-us#male_1-local');
    expect(pick('lw-warm', samsung).voice!.name, 'en-us#female_2-local');
  });

  test("no voice of the right kind: the pitch still tells them apart", () {
    final onlyWomen = [v('en-us-x-sfg-local', 'en-US')];
    final steady = pick('lw-steady', onlyWomen);
    expect(steady.voice!.name, 'en-us-x-sfg-local');
    expect(steady.pitch, lessThan(0.9));
    // No UK voice: another English voice, not silence.
    expect(pick('lw-gentle', onlyWomen).voice, isNotNull);
  });

  test('no English voice at all: the default voice, with the pitch', () {
    final r = pick('lw-deep', [v('hi-in-x-hia-local', 'hi-IN')]);
    expect(r.voice, isNull);
    expect(r.pitch, lessThan(1));
  });

  test('reading the engine list skips malformed entries', () {
    expect(DeviceVoice.fromMap({'name': 'a', 'locale': 'en-US'}), isNotNull);
    expect(DeviceVoice.fromMap({'name': 'a'}), isNull);
    expect(DeviceVoice.fromMap('x'), isNull);
    expect(
      DeviceVoice.fromMap({'name': 'a', 'locale': 'en-US', 'gender': 'male'})!
          .gender,
      'male',
    );
  });
}
