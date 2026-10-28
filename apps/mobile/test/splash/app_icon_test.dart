import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/tokens.dart';

/// Step 2: the Live Well app icon, native splash and app name. The icon, the
/// native splash and the in-app reveal share one teal, so opening the app
/// never flashes a different colour.

String read(String path) => File(path).readAsStringSync();

/// The PNG colour type (byte 25): 2 = RGB, 6 = RGBA.
int pngColourType(String path) {
  final b = File(path).readAsBytesSync();
  expect(b.sublist(1, 4), 'PNG'.codeUnits, reason: path);
  return b[25];
}

(int, int) pngSize(String path) {
  final d = ByteData.sublistView(File(path).readAsBytesSync());
  return (d.getUint32(16), d.getUint32(20));
}

String hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final teal = hex(LwBrand.deepTeal.toARGB32());

  test('the icon, native splash and reveal use the same teal', () {
    expect(teal, '#0B3A4E');
    final pubspec = read('pubspec.yaml');
    expect(pubspec, contains('adaptive_icon_background: "$teal"'));
    expect(RegExp('color: "$teal"').allMatches(pubspec).length, 2);
    expect(
      read('android/app/src/main/res/values/colors.xml'),
      contains('<color name="ic_launcher_background">$teal</color>'),
    );
  });

  test('Android: adaptive icon with a themed (monochrome) layer', () {
    final xml = read(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    expect(xml, contains('@color/ic_launcher_background'));
    expect(xml, contains('@drawable/ic_launcher_foreground'));
    expect(xml, contains('@drawable/ic_launcher_monochrome'));
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final res = 'android/app/src/main/res';
      for (final f in [
        '$res/mipmap-$d/ic_launcher.png',
        '$res/drawable-$d/ic_launcher_foreground.png',
        '$res/drawable-$d/ic_launcher_monochrome.png',
      ]) {
        expect(File(f).existsSync(), isTrue, reason: f);
      }
    }
    // Not Flutter's default icon (1.4 KB at xxxhdpi).
    expect(
      File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png')
          .lengthSync(),
      greaterThan(4000),
    );
    expect(
      read('android/app/src/main/AndroidManifest.xml'),
      contains('android:icon="@mipmap/ic_launcher"'),
    );
  });

  test('iOS: 1024 px store icon without transparency', () {
    const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const store = '$dir/Icon-App-1024x1024@1x.png';
    expect(pngSize(store), (1024, 1024));
    expect(pngColourType(store), 2, reason: 'the App Store rejects alpha');
    for (final f in Directory(dir).listSync().whereType<File>()) {
      if (f.path.endsWith('.png')) {
        expect(pngColourType(f.path), 2, reason: f.path);
      }
    }
  });

  test('the app is called "Live Well" (flavours add Dev / Staging)', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('resValue("string", "app_name", "Live Well")'));
    expect(gradle, contains('"Live Well Dev"'));
    expect(gradle, contains('"Live Well Staging"'));
    final plist = read('ios/Runner/Info.plist');
    expect(plist, contains(r'<string>$(APP_DISPLAY_NAME)</string>'));
    expect(
      RegExp(r'<key>CFBundleName</key>\s*<string>Live Well</string>')
          .hasMatch(plist),
      isTrue,
    );
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(pbx, contains('APP_DISPLAY_NAME = "Live Well";'));
  });
}
