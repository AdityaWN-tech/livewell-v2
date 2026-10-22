@Tags(['walkthrough'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/dev/presentation/avatar_frames_gallery.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';

import '../support/app_harness.dart';
import 'avatar_frames_test.dart' show placeholder, waitForFrames;

/// Frames every 100 ms of the frame player in Developer > Avatar frames
/// (T-AVT-08a), with the placeholder frames: breathing and blinking, each
/// expression (cross-fade), then talking with the mouth frames. For the
/// evidence video docs/evidence/T-AVT-08/frame_player.mp4. Only on demand:
///   flutter test --update-goldens --run-skipped --tags walkthrough test/avatar/avatar_frames_video_test.dart
void main() {
  testWidgets('frame player video frames', (tester) async {
    rootBundle.evict('$placeholder/avatar_frames.json');
    final h = Harness(flavor: Flavor.dev)..idleMotion = true;
    await h.boot(tester);
    await tester.scrollUntilVisible(
      find.text('Preview the app (dev build only)'),
      200,
    );
    await tester.tap(find.text('Preview the app (dev build only)'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(AvatarFramesGallery.path);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await waitForFrames(tester);
    // Let the images decode for real.
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });

    var n = 0;
    Future<void> film(int steps) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump();
        n++;
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('frames/f${n.toString().padLeft(4, '0')}.png'),
        );
      }
    }

    // Idle: breathing, and at least one blink (every 3 to 6 s).
    await film(65);
    for (final e in [
      'happy',
      'waving',
      'listening',
      'calm',
      'celebrating',
      'talking',
    ]) {
      await tester.tap(find.byKey(Key('dev-avatar-$e')));
      await film(10);
    }
    await tester.ensureVisible(find.byKey(const Key('dev-avatar-talk')));
    await tester.tap(find.byKey(const Key('dev-avatar-talk')));
    await film(48);
  });
}
