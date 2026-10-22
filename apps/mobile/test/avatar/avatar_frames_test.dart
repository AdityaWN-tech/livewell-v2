import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/avatar/data/avatar_frames_store.dart';
import 'package:livewell/features/avatar/domain/avatar_frames.dart';
import 'package:livewell/features/avatar/domain/coach_face.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';

import '../support/app_harness.dart';

/// T-AVT-08a: the frame set, the kept face engine, the player, the cache
/// and the fallback chain.

const placeholder = 'assets/avatar/frames/placeholder';

AvatarFrameManifest placeholderManifest() => AvatarFrameManifest.fromJson(
  jsonDecode(File('$placeholder/avatar_frames.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Small solid images, one colour per frame, so tests never decode assets.
AvatarImages testImages() => AvatarImages({
  for (final (i, f) in AvatarFrame.values.indexed) f: MemoryImage(_png(i)),
});

// A 1x1 PNG; each copy is its own image (MemoryImage compares the bytes
// object), so frames can be told apart.
final _onePixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
);
Uint8List _png(int seed) => Uint8List.fromList(_onePixel);

AvatarFrame shown(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(of: find.byType(AvatarView), matching: find.byType(Image)),
  );
  return (image.key! as ValueKey<AvatarFrame>).value;
}

/// The placeholder frames load from the asset bundle (real IO): give it
/// real time until the coach on Home has them.
Future<void> waitForFrames(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    final views = tester.widgetList<AvatarView>(find.byType(AvatarView));
    if (views.isNotEmpty && views.every((v) => v.images != null)) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  fail('the placeholder frames never loaded');
}

Future<void> pumpView(WidgetTester tester, AvatarView view) =>
    tester.pumpWidget(MaterialApp(home: Center(child: view)));

void main() {
  // The asset bundle caches loads across tests; a load from an earlier
  // test's clock never finishes in the next one.
  setUp(() => rootBundle.evict('$placeholder/avatar_frames.json'));

  group('the frame set (avatar_frames.json)', () {
    test('14 frames, named as the task says', () {
      expect(
        [for (final f in AvatarFrame.values) f.id],
        [
          'neutral',
          'happy',
          'waving',
          'listening',
          'calm',
          'celebrating',
          'blink',
          'mouth_A',
          'mouth_I',
          'mouth_U',
          'mouth_E',
          'mouth_O',
          'mouth_closed',
          'thumb',
        ],
      );
    });

    test(
      'the placeholder set is complete, 3d_adult, and every file exists',
      () {
        final m = placeholderManifest();
        expect(m.style, '3d_adult');
        expect(m.complete, isTrue, reason: '${m.missing}');
        for (final f in AvatarFrame.values) {
          for (final size in m.sizes) {
            expect(
              File('$placeholder/${m.files[f]![size]}').existsSync(),
              true,
            );
          }
        }
        expect(
          File('pubspec.yaml').readAsStringSync(),
          contains('- $placeholder/'),
        );
      },
    );

    test('the schema lists the same frames', () {
      final schema = jsonDecode(
        File('../../packages/schemas/avatar_frames.schema.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final frames =
          (schema['properties'] as Map)['frames'] as Map<String, dynamic>;
      expect(frames['required'], [for (final f in AvatarFrame.values) f.id]);
    });

    test('round-trips; refuses other styles, broken files and paths', () {
      final m = placeholderManifest();
      expect(AvatarFrameManifest.fromJson(m.toJson()).toJson(), m.toJson());
      expect(
        () => AvatarFrameManifest.fromJson({...m.toJson(), 'style': 'anime'}),
        throwsFormatException,
      );
      expect(
        () => AvatarFrameManifest.fromJson({'avatar_id': 'x'}),
        throwsFormatException,
      );
      final sneaky = AvatarFrameManifest.fromJson({
        ...m.toJson(),
        'frames': {
          'neutral': {'2x': '../../secret.webp', '3x': 'neutral@3x.webp'},
        },
      });
      expect(sneaky.files[AvatarFrame.neutral], {'3x': 'neutral@3x.webp'});
      expect(sneaky.complete, isFalse);
    });

    test('picks the size nearest the screen', () {
      final m = placeholderManifest();
      expect(m.fileFor(AvatarFrame.calm, devicePixelRatio: 2), 'calm@2x.webp');
      expect(
        m.fileFor(AvatarFrame.calm, devicePixelRatio: 3.5),
        'calm@3x.webp',
      );
    });
  });

  group('the face engine (kept from T-AVT-06b)', () {
    test('each expression has its frame; talking is neutral', () {
      expect(
        {for (final e in AvatarExpression.values) e: frameFor(e)},
        {
          AvatarExpression.happy: AvatarFrame.happy,
          AvatarExpression.waving: AvatarFrame.waving,
          AvatarExpression.talking: AvatarFrame.neutral,
          AvatarExpression.listening: AvatarFrame.listening,
          AvatarExpression.calm: AvatarFrame.calm,
          AvatarExpression.celebrating: AvatarFrame.celebrating,
        },
      );
    });

    test('mouth shapes pick the mouth frames; blinks only where the eyes are '
        'neutral', () {
      expect(
        frameFor(AvatarExpression.talking, mouth: MouthShape.o),
        AvatarFrame.mouthO,
      );
      expect(
        frameFor(AvatarExpression.talking, mouth: MouthShape.a, blink: true),
        AvatarFrame.blink,
      );
      expect(
        frameFor(AvatarExpression.talking, blink: true),
        AvatarFrame.blink,
      );
      // A waving or celebrating face holds still rather than jump to neutral.
      expect(
        frameFor(AvatarExpression.waving, blink: true),
        AvatarFrame.waving,
      );
      expect(
        frameFor(AvatarExpression.celebrating, blink: true),
        AvatarFrame.celebrating,
      );
    });

    test('reduced motion: always the still neutral frame', () {
      for (final e in AvatarExpression.values) {
        expect(
          frameFor(e, still: true, blink: true, mouth: MouthShape.a),
          AvatarFrame.neutral,
        );
      }
    });

    test('lip shapes from the words, and from loudness', () {
      expect(visemesFor('morning'), [MouthShape.o, MouthShape.i]);
      expect(visemesFor('Priya'), [MouthShape.i, MouthShape.a]);
      expect(visemesFor('hmm'), [MouthShape.e]);
      expect(
        [for (var t = 0; t < 3; t++) visemeAt('Good morning', 6, t)],
        [MouthShape.o, MouthShape.i, MouthShape.closed],
      );
      expect(visemeForLoudness(0.02, 0), MouthShape.closed);
      expect(visemeForLoudness(0.9, 0), MouthShape.a);
      expect(visemeForLoudness(0.3, 1), MouthShape.i);
    });
  });

  group('the player', () {
    testWidgets('no frame set: the initial circle', (tester) async {
      await pumpView(tester, const AvatarView(images: null));
      expect(find.byKey(const Key('avatar-initial')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('expression changes cross-fade; mouth shapes swap at once', (
      tester,
    ) async {
      final images = testImages();
      await pumpView(tester, AvatarView(images: images));
      expect(shown(tester), AvatarFrame.happy);
      await pumpView(
        tester,
        AvatarView(images: images, expression: AvatarExpression.calm),
      );
      final fading = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(fading.duration, const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(shown(tester), AvatarFrame.calm);

      for (final m in [MouthShape.a, MouthShape.u, MouthShape.closed]) {
        await pumpView(
          tester,
          AvatarView(
            images: images,
            expression: AvatarExpression.talking,
            mouth: m,
          ),
        );
        // The first one leaves the calm face (a fade); then no fades.
        await tester.pumpAndSettle();
        expect(shown(tester), m.frame);
      }
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
    });

    testWidgets('blinks every 3 to 6 seconds and breathes, when animated', (
      tester,
    ) async {
      await pumpView(
        tester,
        AvatarView(
          images: testImages(),
          expression: AvatarExpression.talking,
          animate: true,
        ),
      );
      var blinked = false;
      final heights = <double>{};
      for (var ms = 0; ms < 6200; ms += 70) {
        await tester.pump(const Duration(milliseconds: 70));
        final frame = shown(tester);
        if (ms < 2900) expect(frame, AvatarFrame.neutral);
        blinked |= frame == AvatarFrame.blink;
        heights.add(
          tester.getTopLeft(find.byType(ClipOval)).dy.roundToDouble(),
        );
      }
      expect(blinked, isTrue);
      expect(heights.length, greaterThan(1), reason: 'breathing moves it');
      // Not animated: no timers or ticks left behind.
      await pumpView(tester, AvatarView(images: testImages()));
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: the still neutral frame, no blink or breath', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpView(
        tester,
        AvatarView(
          images: testImages(),
          expression: AvatarExpression.celebrating,
          mouth: MouthShape.a,
          animate: true,
        ),
      );
      final top = tester.getTopLeft(find.byType(ClipOval));
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(shown(tester), AvatarFrame.neutral);
        expect(tester.getTopLeft(find.byType(ClipOval)), top);
      }
      // Settles: nothing animating.
      await tester.pumpAndSettle();
    });

    testWidgets('only the neutral frame: shown for every expression', (
      tester,
    ) async {
      final neutral = MemoryImage(_png(0));
      final images = AvatarImages.neutral(neutral);
      for (final e in AvatarExpression.values) {
        await pumpView(tester, AvatarView(images: images, expression: e));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Image>(
                find.descendant(
                  of: find.byType(AvatarView),
                  matching: find.byType(Image),
                ),
              )
              .image,
          neutral,
        );
      }
    });
  });

  group('the fallback chain (FR-AVT-05)', () {
    final own = testImages();
    final neutral = AvatarImages.neutral(MemoryImage(_png(0)));
    final coach = AvatarImages({AvatarFrame.neutral: MemoryImage(_png(9))});

    test('frame set → neutral only → default coach → initial circle', () {
      expect(pickCoachImages(own: own, defaultCoach: coach), own);
      expect(pickCoachImages(own: neutral, defaultCoach: coach), neutral);
      expect(pickCoachImages(defaultCoach: coach), coach);
      expect(pickCoachImages(), isNull);
    });
  });

  group('the cache on the device', () {
    late Directory root;
    late _Source source;
    late Map<Uri, List<int>> served;
    late List<Uri> fetched;
    var offline = false;

    Uri url(String name) =>
        Uri.parse('https://storage.googleapis.com/b/avatars/u1/2/$name?sig=x');

    AvatarFrameCache cache() => AvatarFrameCache(
      root: () async => root,
      source: source,
      fetch: (u) async {
        fetched.add(u);
        if (offline) throw const SocketException('offline');
        final bytes = served[u];
        if (bytes == null) throw const HttpException('404');
        return bytes;
      },
    );

    setUp(() {
      root = Directory.systemTemp.createTempSync('frames');
      final m = placeholderManifest();
      final names = {for (final f in m.files.values) ...f.values};
      served = {
        url(AvatarFrameCache.manifestName): utf8.encode(jsonEncode(m.toJson())),
        for (final n in names) url(n): [1, 2, 3],
      };
      source = _Source({
        AvatarFrameCache.manifestName: url(AvatarFrameCache.manifestName),
        for (final n in names) n: url(n),
      });
      fetched = [];
      offline = false;
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('downloads the whole set once, then works offline', () async {
      final set = await cache().load('u1', 2);
      expect(set!.complete, isTrue);
      expect(cachedFrames(set)!.neutralOnly, isFalse);
      expect(Directory('${root.path}/avatars/u1/2').existsSync(), isTrue);
      fetched.clear();
      offline = true;
      final again = await cache().load('u1', 2);
      expect(again!.complete, isTrue);
      expect(fetched, isEmpty, reason: 'served from the device');
    });

    test('some frames failed: only the neutral face is used', () async {
      served.removeWhere(
        (u, _) => u.path.contains('happy') || u.path.contains('mouth_A'),
      );
      final set = await cache().load('u1', 2);
      expect(set!.complete, isFalse);
      final images = cachedFrames(set)!;
      expect(images.neutralOnly, isTrue);
    });

    test(
      'offline with nothing cached: nothing (the chain falls back)',
      () async {
        offline = true;
        expect(await cache().load('u1', 2), isNull);
        expect(cachedFrames(null), isNull);
      },
    );

    test('only HTTPS links to Cloud Storage are followed', () async {
      expect(
        AvatarFrameCache.allowed(Uri.parse('http://storage.googleapis.com/x')),
        isFalse,
      );
      expect(
        AvatarFrameCache.allowed(Uri.parse('https://evil.example.com/x')),
        isFalse,
      );
      source.urls[AvatarFrameCache.manifestName] = Uri.parse(
        'https://evil.example.com/avatar_frames.json',
      );
      expect(await cache().load('u1', 2), isNull);
      expect(fetched, isEmpty);
    });

    test('Delete my avatar clears the device copy', () async {
      await cache().load('u1', 2);
      await cache().clear('u1');
      expect(Directory('${root.path}/avatars/u1').existsSync(), isFalse);
    });

    test(
      'until the Media Service exists there is nothing to download',
      () async {
        expect(
          await UnavailableFrameSource().signedUrls(uid: 'u1', version: 1),
          isEmpty,
        );
      },
    );
  });

  testWidgets('dev preview: the placeholder frames play in the app', (
    tester,
  ) async {
    final h = Harness(flavor: Flavor.dev);
    await h.boot(tester);
    await tester.scrollUntilVisible(
      find.text('Preview the app (dev build only)'),
      200,
    );
    await tester.tap(find.text('Preview the app (dev build only)'));
    await tester.pumpAndSettle();
    await waitForFrames(tester);
    final view = tester.widget<AvatarView>(
      find.byKey(const Key('coach-avatar-waving')),
    );
    expect(view.images, isNotNull);
    expect(view.images![AvatarFrame.waving], isA<AssetImage>());
  });

  testWidgets('in an Avatar Moment the mouth frames follow the words, then '
      'rest', (tester) async {
    final h = Harness(flavor: Flavor.dev);
    await h.boot(tester);
    await tester.scrollUntilVisible(
      find.text('Preview the app (dev build only)'),
      200,
    );
    await tester.tap(find.text('Preview the app (dev build only)'));
    await tester.pumpAndSettle();
    await waitForFrames(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(MomentScreen.pathFor(Moment.morning));
    final frames = <AvatarFrame>{};
    for (var i = 0; i < 30; i++) {
      h.speaker.word(i * 4);
      await tester.pump(const Duration(milliseconds: 160));
      final view = tester.widget<AvatarView>(
        find.byKey(const Key('moment-avatar')),
      );
      expect(view.images, isNotNull);
      frames.add(view.frameNow());
    }
    final mouths = {for (final m in MouthShape.values) m.frame};
    expect(frames.intersection(mouths).length, greaterThan(2));
    h.speaker.finish();
    await tester.pumpAndSettle();
    final view = tester.widget<AvatarView>(
      find.byKey(const Key('moment-avatar')),
    );
    expect(view.mouth, isNull);
    expect(view.frameNow(), AvatarFrame.waving);
  });
}

class _Source implements AvatarFrameSource {
  _Source(this.urls);

  final Map<String, Uri> urls;

  @override
  Future<Map<String, Uri>> signedUrls({
    required String uid,
    required int version,
  }) async => urls;
}
