import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/avatar/domain/anime_face.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';

import '../home/home_screen_test.dart' show previewLabel;
import '../support/app_harness.dart';

/// T-AVT-06b: the Anime coach's expressions, blinking and lip movement.

final anime = AvatarConfig.fallback.withStyle(AvatarStyle.anime);

final Map<String, dynamic> manifest = jsonDecode(
  File('assets/avatar/parts_anime.json').readAsStringSync(),
) as Map<String, dynamic>;

List<Map<String, dynamic>> options(String category) => [
  for (final c in (manifest['categories'] as List).cast<Map<String, dynamic>>())
    if (c['id'] == category)
      ...(c['options'] as List).cast<Map<String, dynamic>>(),
];

List<String> variants(Map<String, dynamic> option) => [
  for (final v in (option['variants'] as List).cast<Map<String, dynamic>>())
    v['id'] as String,
];

/// The dev preview with an Anime coach, opening [m].
Future<Harness> openAnime(WidgetTester tester, Moment m) async {
  final h = Harness(flavor: Flavor.dev)..avatars.saved = anime;
  await h.boot(tester);
  await tester.scrollUntilVisible(find.text(previewLabel), 200);
  await tester.tap(find.text(previewLabel));
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(HomeScreen)))
      .push(MomentScreen.pathFor(m));
  // Never settles: the Anime coach sways.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return h;
}

AvatarView avatar(WidgetTester tester) =>
    tester.widget<AvatarView>(find.byKey(const Key('moment-avatar')));

double tilt(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('moment-avatar')),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getRotation()
    .entry(1, 0);

void main() {
  group('every version exists for every part (manifest)', () {
    test('eyes, eyebrows and lips each have all their versions', () {
      for (final (category, ids) in [
        ('eyes', [for (final e in AnimeEyes.values) e.id]),
        ('eyebrows', [for (final b in AnimeBrows.values) b.id]),
        ('lips', [for (final m in AnimeMouth.values) m.id]),
      ]) {
        final opts = options(category);
        expect(opts, isNotEmpty);
        for (final o in opts) {
          expect(variants(o), ids, reason: '$category ${o['id']}');
        }
      }
      // The talking shapes are all there.
      expect(
        variants(options('lips').first),
        containsAll(['a', 'i', 'u', 'e', 'o', 'closed']),
      );
    });

    test('hair has back and front layers; the celebrating extras exist', () {
      for (final o in options('hair')) {
        if (o['id'] == 'none') continue;
        expect(o['layers'], ['back', 'front'], reason: o['id'] as String);
      }
      final extras = [
        for (final e
            in (manifest['extras'] as List).cast<Map<String, dynamic>>())
          e['id'],
      ];
      expect(extras, containsAll(['blush_celebrate', 'sparkles', 'hearts']));
    });

    test('the expression map is what the app shows', () {
      final map = (manifest['expression_map'] as Map).cast<String, dynamic>();
      expect(map.keys.toSet(), {
        for (final e in AvatarExpression.values) e.name,
      });
      for (final e in AvatarExpression.values) {
        final f = AnimeFace.of(e);
        final row = (map[e.name] as Map).cast<String, dynamic>();
        expect(
          (row['eyes'], row['eyebrows'], row['lips']),
          (f.eyes.id, f.brows.id, f.mouth.id),
          reason: e.name,
        );
        expect(
          row.containsKey('extras'),
          f.blush || f.sparkles,
          reason: e.name,
        );
      }
      final blink = (manifest['animation'] as Map)['blink_every_seconds'];
      expect(blink, [3, 6]);
    });
  });

  group('expressions', () {
    test('happy: closed-eye smile; celebrating: sparkle eyes with blush', () {
      expect(AnimeFace.of(AvatarExpression.happy).eyes, AnimeEyes.closedSmile);
      final c = AnimeFace.of(AvatarExpression.celebrating);
      expect((c.eyes, c.blush, c.sparkles), (AnimeEyes.sparkle, true, true));
      expect(AnimeFace.of(AvatarExpression.calm).eyes, AnimeEyes.soft);
      final l = AnimeFace.of(AvatarExpression.listening);
      expect((l.eyes, l.brows), (AnimeEyes.halfClosed, AnimeBrows.caring));
      expect(AnimeFace.of(AvatarExpression.waving).mouth, AnimeMouth.openSmile);
    });

    test('a blink closes the eyes; speaking sets the mouth', () {
      final f = AnimeFace.of(
        AvatarExpression.talking,
        blink: true,
        speaking: AnimeMouth.o,
      );
      expect((f.eyes, f.mouth), (AnimeEyes.blink, AnimeMouth.o));
    });

    test('reduced motion: no sparkles around the head', () {
      final f = AnimeFace.of(AvatarExpression.celebrating, reducedMotion: true);
      expect(f.sparkles, isFalse);
      expect(f.blush, isTrue);
    });
  });

  group('lip shapes from the words', () {
    test('the vowels of each word, repeats merged', () {
      expect(visemesFor('Good'), [AnimeMouth.o]);
      expect(visemesFor('morning'), [AnimeMouth.o, AnimeMouth.i]);
      expect(visemesFor('Priya'), [AnimeMouth.i, AnimeMouth.a]);
      expect(visemesFor('step'), [AnimeMouth.e]);
      expect(visemesFor('hmm'), [AnimeMouth.e]);
    });

    test('a word, then closed, at each tick', () {
      const text = 'Good morning';
      expect(
        [for (var t = 0; t < 4; t++) visemeAt(text, 0, t)],
        [AnimeMouth.o, AnimeMouth.closed, AnimeMouth.o, AnimeMouth.closed],
      );
      expect(
        [for (var t = 0; t < 3; t++) visemeAt(text, 6, t)],
        [AnimeMouth.o, AnimeMouth.i, AnimeMouth.closed],
      );
      expect(visemeAt('', 0, 0), AnimeMouth.closed);
    });
  });

  group('layers (for the art kit)', () {
    test('the face version picks each layer; covered parts are left out', () {
      final face = AnimeFace.of(AvatarExpression.celebrating);
      final layers = animeLayers(anime.anime, 'none', face, glasses: 'round');
      expect(layers, contains(('eyes', 'round', 'sparkle')));
      expect(layers, contains(('lips', 'smile', 'open_smile')));
      expect(layers, contains(('hair', 'short', 'back')));
      expect(layers, contains(('extra', 'sparkles', null)));
      expect(layers, contains(('glasses', 'round', null)));
      // Back hair at the back, front hair over the face.
      expect(
        layers.indexOf(('hair', 'short', 'back')),
        lessThan(layers.indexOf(('face', 'oval', null))),
      );

      final covered = animeLayers(
        anime.anime.copyWith(AnimeCategory.cap, 'beanie'),
        'hijab',
        AnimeFace.of(AvatarExpression.calm),
      );
      expect(covered.map((l) => l.$1), isNot(contains('hair')));
      expect(covered.map((l) => l.$1), isNot(contains('cap')));
      expect(covered, contains(('head_covering', 'hijab', null)));
    });
  });

  group('in an Avatar Moment', () {
    testWidgets('the mouth moves through the vowel shapes while the coach '
        'speaks, and rests after', (tester) async {
      final h = await openAnime(tester, Moment.morning);
      final text = h.speaker.spoken.single.$1.text;
      final shapes = <AnimeMouth?>{};
      final scales = <double>{};
      for (var i = 0; i < 30; i++) {
        h.speaker.word((i * 4).clamp(0, text.length));
        await tester.pump(const Duration(milliseconds: 160));
        shapes.add(avatar(tester).mouth);
        scales.add(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: find.byKey(const Key('moment-avatar')),
                  matching: find.byType(AnimatedScale),
                ),
              )
              .scale,
        );
      }
      expect(avatar(tester).expression, AvatarExpression.talking);
      expect(
        shapes.whereType<AnimeMouth>().toSet(),
        isNot(anyOf(isEmpty, everyElement(AnimeMouth.closed))),
      );
      expect(
        shapes.whereType<AnimeMouth>(),
        everyElement(
          isIn([
            AnimeMouth.a,
            AnimeMouth.i,
            AnimeMouth.u,
            AnimeMouth.e,
            AnimeMouth.o,
            AnimeMouth.closed,
          ]),
        ),
      );
      // The placeholder circle swells with the open shapes.
      expect(scales.length, greaterThan(1));

      h.speaker.finish();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(avatar(tester).mouth, isNull);
      expect(avatar(tester).expression, AvatarExpression.waving);
    });

    testWidgets('it blinks within 3 to 6 seconds, and sways gently', (
      tester,
    ) async {
      final h = await openAnime(tester, Moment.evening);
      var blinked = false;
      final tilts = <double>{};
      for (var ms = 0; ms < 6400; ms += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        blinked |= avatar(tester).blink;
        tilts.add(double.parse(tilt(tester).toStringAsFixed(4)));
        // Speech started about 300 ms before this loop.
        if (ms + 300 < 3000) {
          expect(avatar(tester).blink, isFalse, reason: 'not before 3 s');
        }
      }
      expect(blinked, isTrue);
      expect(tilts.length, greaterThan(3));
      // Gentle: about a degree each way.
      expect(tilts.every((t) => t.abs() < 0.03), isTrue);
      h.speaker.finish();
      await tester.pump();
    });

    testWidgets('reduced motion: a still face, no blink, no sway', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final h = await openAnime(tester, Moment.morning);
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 160));
        expect(avatar(tester).mouth, isNull);
        expect(avatar(tester).blink, isFalse);
        expect(tilt(tester), 0);
      }
      expect(avatar(tester).expression, AvatarExpression.waving);
      h.speaker.finish();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('the Illustrated coach keeps its own talking mouth', (
    tester,
  ) async {
    final h = Harness(flavor: Flavor.dev);
    await h.boot(tester);
    await tester.scrollUntilVisible(find.text(previewLabel), 200);
    await tester.tap(find.text(previewLabel));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(MomentScreen.pathFor(Moment.morning));
    final faces = <AvatarExpression>{};
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 160));
      expect(avatar(tester).mouth, isNull);
      expect(tilt(tester), 0);
      faces.add(avatar(tester).expression);
    }
    expect(
      faces,
      containsAll([AvatarExpression.talking, AvatarExpression.waving]),
    );
    h.speaker.finish();
    await tester.pumpAndSettle();
  });
}
