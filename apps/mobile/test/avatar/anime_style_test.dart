import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/avatar/domain/characters.dart';
import 'package:livewell/features/avatar/presentation/avatar_creator_screen.dart';
import 'package:livewell/features/moments/data/coach_faces.dart';
import 'package:livewell/features/voice/presentation/voice_screen.dart';

import '../studio/studio_test.dart' show openStudio, preview, signedIn;
import 'avatar_flow_test.dart' show atAvatar;

/// T-AVT-06a: the Anime style in the part system and the avatar maker.

Map<String, dynamic> manifest(String file) =>
    jsonDecode(File('assets/avatar/$file').readAsStringSync())
        as Map<String, dynamic>;

Map<String, List<String>> categories(Map<String, dynamic> m) => {
  for (final c in (m['categories'] as List).cast<Map<String, dynamic>>())
    c['id'] as String: [
      for (final o in (c['options'] as List).cast<Map<String, dynamic>>())
        o['id'] as String,
    ],
};

/// Taps [key] once it is built and in view (lists build lazily).
Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

AvatarConfig creatorPreview(WidgetTester tester) => tester
    .widget<AvatarView>(find.byKey(const Key('avatar-creator-preview')))
    .config;

final anime = AvatarConfig.fallback.withStyle(AvatarStyle.anime);

void main() {
  group('parts_anime.json: the Anime part set', () {
    final m = manifest('parts_anime.json');
    final cats = categories(m);
    final illustrated = manifest('parts.json');
    final shared = categories(illustrated);

    test('is the anime style, on the illustrated canvas, same expressions', () {
      expect(m['style'], 'anime');
      expect(illustrated['style'], 'illustrated');
      expect(m['canvas'], illustrated['canvas']);
      expect(m['expressions'], illustrated['expressions']);
    });

    test('every anime category and option, in order, and nothing extra', () {
      for (final c in AnimeCategory.values) {
        expect(cats[c.id], c.options, reason: c.id);
      }
      // The shared parts are the illustrated ones (outfit colour is the
      // clothing colour).
      for (final id in [
        'skin',
        'hair_colour',
        'glasses',
        'head_covering',
        'background',
      ]) {
        expect(cats[id], shared[id], reason: id);
      }
      expect(cats['outfit_colour'], shared['clothing_colour']);
      expect(cats.keys.toSet(), {
        for (final c in AnimeCategory.values) c.id,
        'skin',
        'hair_colour',
        'outfit_colour',
        'glasses',
        'head_covering',
        'background',
      });
    });

    test('the categories asked for are all there', () {
      for (final id in [
        'face',
        'skin',
        'eyes',
        'eye_highlight',
        'eyebrows',
        'nose',
        'lips',
        'blush',
        'hair',
        'bangs',
        'hair_colour',
        'outfit',
        'cap',
        'head_covering',
        'hair_accessory',
        'accessory',
      ]) {
        expect(cats, contains(id));
      }
    });

    test('no part is drawn in code: placeholder, or final with its file', () {
      for (final c in (m['categories'] as List).cast<Map<String, dynamic>>()) {
        for (final o in (c['options'] as List).cast<Map<String, dynamic>>()) {
          expect(['placeholder', 'final'], contains(o['status']));
          if (o['status'] == 'final') {
            expect(File('assets/avatar/${o['file']}').existsSync(), isTrue);
          }
        }
      }
    });

    test('the hiding rules are the ones the app applies', () {
      final rules = (m['rules'] as List).cast<Map<String, dynamic>>();
      Set<String> hides(String when, String value) => {
        for (final r in rules)
          if ((r['when'] as Map)[when] == value)
            ...(r['hides'] as List).cast<String>(),
      };
      final ids = {for (final c in AnimeCategory.values) c.id: c};
      for (final covering in ['hijab', 'turban']) {
        expect(AnimeParts.defaults.hiddenUnder(covering), {
          for (final id in hides('head_covering', covering)) ids[id],
        });
      }
      final capped = AnimeParts.defaults.copyWith(AnimeCategory.cap, 'beanie');
      expect(capped.hiddenUnder('none'), {
        for (final id in hides('cap', '!none')) ids[id],
      });
      expect(AnimeParts.defaults.hiddenUnder('kippah'), isEmpty);
    });
  });

  group('switching style', () {
    final start = AvatarConfig.fallback.copyWith(
      skin: 8,
      hairColour: 5,
      glasses: Glasses.round,
      headCovering: HeadCovering.kippah,
      clothingColour: 3,
      background: 4,
      hair: HairStyle.coily,
      eyes: EyeShape.round,
      clothing: Clothing.collar,
    );

    test('keeps skin, hair colour, glasses, head covering, clothing colour '
        'and background; resets the rest', () {
      final a = start.withStyle(AvatarStyle.anime);
      expect(a.style, AvatarStyle.anime);
      expect(
        (a.skin, a.hairColour, a.glasses, a.headCovering),
        (8, 5, Glasses.round, HeadCovering.kippah),
      );
      expect((a.clothingColour, a.background), (3, 4));
      expect(a.anime, AnimeParts.defaults);

      final edited = a.copyWith(
        anime: a.anime.copyWith(AnimeCategory.eyeHighlight, 'star'),
      );
      final back = edited.withStyle(AvatarStyle.illustrated);
      expect(back.style, AvatarStyle.illustrated);
      expect((back.skin, back.hairColour, back.glasses), (8, 5, Glasses.round));
      // The illustrated parts start again from the starting look.
      final look = AvatarConfig.forLook(AvatarLook.neutral);
      expect((back.hair, back.eyes), (look.hair, look.eyes));
      // And the anime parts start fresh when going to Anime again.
      expect(back.withStyle(AvatarStyle.anime).anime, AnimeParts.defaults);
    });

    test('the same style changes nothing', () {
      expect(identical(start.withStyle(AvatarStyle.illustrated), start), true);
    });

    test('the characters are Illustrated: an Anime look is never one', () {
      final c = CoachCharacters.all.first.config;
      expect(CoachCharacters.indexOf(c), 0);
      expect(CoachCharacters.indexOf(c.withStyle(AvatarStyle.anime)), -1);
    });
  });

  group('saving and loading (style_config v2)', () {
    test('each style round-trips', () {
      final a = anime.copyWith(
        skin: 2,
        anime: anime.anime
            .copyWith(AnimeCategory.hair, 'twin_tails')
            .copyWith(AnimeCategory.accessory, 'hearing_aid'),
      );
      final map = a.toMap();
      expect(map['version'], 2);
      expect(map['style'], 'anime');
      expect((map['anime'] as Map)['hair'], 'twin_tails');
      expect(AvatarConfig.fromMap(map), a);

      final i = AvatarConfig.fallback.copyWith(skin: 6);
      expect(i.toMap()['style'], 'illustrated');
      expect(i.toMap(), isNot(contains('anime')));
      expect(AvatarConfig.fromMap(i.toMap()), i);
    });

    test('a v1 document (before styles) loads as Illustrated', () {
      final v1 = {...AvatarConfig.fallback.toMap()}
        ..remove('style')
        ..['version'] = 1;
      expect(AvatarConfig.fromMap(v1).style, AvatarStyle.illustrated);
    });

    test('unknown anime values fall back, never break', () {
      final c = AvatarConfig.fromMap({
        ...anime.toMap(),
        'anime': {'eyes': 'laser', 'face': 'heart', 'blush': 3},
      });
      expect(c.anime[AnimeCategory.eyes], AnimeCategory.eyes.fallback);
      expect(c.anime[AnimeCategory.face], 'heart');
      expect(c.anime[AnimeCategory.blush], AnimeCategory.blush.fallback);
      expect(
        AvatarConfig.fromMap({...anime.toMap(), 'style': 'oil'}).style,
        AvatarStyle.illustrated,
      );
    });
  });

  group('the Anime look before its art exists', () {
    testWidgets('a soft circle with the coach\'s initial, never a drawn face', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AvatarInitial(
            initial: 'C',
            child: Center(child: AvatarView(config: anime)),
          ),
        ),
      );
      expect(find.byKey(const Key('avatar-anime-placeholder')), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AvatarView),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('the notification face is the circle too', (tester) async {
      final png = await tester.runAsync(
        () => FileCoachFaces.png(anime, AvatarExpression.waving, initial: 'C'),
      );
      final drawn = await tester.runAsync(
        () =>
            FileCoachFaces.png(AvatarConfig.fallback, AvatarExpression.waving),
      );
      expect(png!.take(4), [0x89, 0x50, 0x4E, 0x47]);
      expect(png, isNot(drawn));
    });
  });

  group('Avatar Studio', () {
    testWidgets('the style switch is at the top; Anime shows its preview '
        'at once, without the Illustrated characters', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      final top = tester.getTopLeft(find.byKey(const Key('avatar-style'))).dy;
      expect(
        tester.getTopLeft(find.byKey(const Key('studio-stage'))).dy,
        greaterThan(top),
      );
      expect(find.byKey(const Key('studio-next')), findsOneWidget);
      await tapKey(tester, 'avatar-style-anime');
      expect(preview(tester).style, AvatarStyle.anime);
      expect(find.byKey(const Key('avatar-anime-placeholder')), findsOneWidget);
      // The coach is called "Coach" until named: its initial.
      expect(
        find.descendant(
          of: find.byKey(const Key('studio-stage')),
          matching: find.text('C'),
        ),
        findsOneWidget,
      );
      expect(find.text('Anime look'), findsOneWidget);
      expect(find.byKey(const Key('studio-next')), findsNothing);
      expect(find.byKey(const Key('avatar-anime-soon')), findsOneWidget);
      expect(find.byKey(const Key('avatar-character-older')), findsNothing);

      // Back to Illustrated: the characters return.
      await tapKey(tester, 'avatar-style-illustrated');
      expect(preview(tester).style, AvatarStyle.illustrated);
      expect(find.byKey(const Key('studio-next')), findsOneWidget);
    });

    testWidgets('customize every Anime part in tabs, then save and reopen', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'avatar-style-anime');
      await tapKey(tester, 'studio-customize');
      expect(find.byType(AvatarCreatorScreen), findsOneWidget);
      // One tab per part, the face first.
      for (final id in [
        'face',
        'skin',
        'eyes',
        'eye_highlight',
        'eyebrows',
        'nose',
        'lips',
        'blush',
        'hair',
        'bangs',
        'hair_colour',
        'outfit',
        'clothing_colour',
        'cap',
        'head_covering',
        'hair_accessory',
        'accessory',
        'glasses',
        'background',
      ]) {
        expect(find.byKey(Key('avatar-tab-$id')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const Key('avatar-anime-face-heart')), findsOneWidget);

      for (final (tab, option) in [
        ('face', 'heart'),
        ('eye_highlight', 'star'),
        ('lips', 'full'),
        ('blush', 'round'),
        ('hair', 'braids'),
        ('bangs', 'curtain'),
        ('outfit', 'kurta'),
        ('hair_accessory', 'ribbon'),
        ('accessory', 'hearing_aid'),
      ]) {
        await tapKey(tester, 'avatar-tab-$tab');
        await tapKey(tester, 'avatar-anime-$tab-$option');
      }
      await tapKey(tester, 'avatar-tab-skin');
      await tapKey(tester, 'avatar-skin-2');
      final chosen = creatorPreview(tester);
      expect(chosen.style, AvatarStyle.anime);
      expect(chosen.skin, 2);
      expect(chosen.anime[AnimeCategory.hair], 'braids');
      expect(chosen.anime[AnimeCategory.accessory], 'hearing_aid');

      await tapKey(tester, 'avatar-creator-use');
      expect(preview(tester), chosen);
      await tapKey(tester, 'studio-save-avatar');
      expect(h.avatars.saved, chosen);

      // Reopened: the saved Anime look.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'profile-avatar');
      expect(preview(tester), chosen);
    });

    testWidgets('a hijab or cap covers parts: they say why and can\'t be '
        'changed', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'avatar-style-anime');
      await tapKey(tester, 'studio-customize');

      await tapKey(tester, 'avatar-tab-cap');
      await tapKey(tester, 'avatar-anime-cap-beanie');
      await tapKey(tester, 'avatar-tab-bangs');
      expect(find.text('Hidden under the cap.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('avatar-anime-bangs-wispy')));
      await tester.pumpAndSettle();
      expect(creatorPreview(tester).anime[AnimeCategory.bangs], 'side');

      await tapKey(tester, 'avatar-tab-head_covering');
      await tapKey(tester, 'avatar-covering-Hijab');
      await tapKey(tester, 'avatar-tab-hair');
      expect(find.text('Hidden under the head covering.'), findsOneWidget);
      // Taking it off frees the hair again.
      await tapKey(tester, 'avatar-tab-head_covering');
      await tapKey(tester, 'avatar-covering-None');
      await tapKey(tester, 'avatar-tab-hair');
      expect(find.byKey(const Key('avatar-anime-hair-hidden')), findsNothing);
    });

    testWidgets('switching style in the creator keeps the shared choices', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openStudio(tester);
      await tapKey(tester, 'studio-customize');
      await tapKey(tester, 'avatar-skin-9');
      await tapKey(tester, 'avatar-style-anime');
      expect(creatorPreview(tester).style, AvatarStyle.anime);
      expect(creatorPreview(tester).skin, 9);
      // The tabs change with the style.
      expect(find.byKey(const Key('avatar-tab-face')), findsOneWidget);
      await tapKey(tester, 'avatar-style-illustrated');
      expect(find.byKey(const Key('avatar-tab-face')), findsNothing);
      expect(creatorPreview(tester).skin, 9);
    });
  });

  testWidgets('onboarding: pick Anime at the avatar step and use it', (
    tester,
  ) async {
    final h = atAvatar();
    await h.boot(tester);
    expect(find.byKey(const Key('avatar-style')), findsOneWidget);
    await tapKey(tester, 'avatar-style-anime');
    expect(find.byKey(const Key('avatar-anime-placeholder')), findsOneWidget);
    expect(h.avatarDrafts.draft!.config.style, AvatarStyle.anime);
    await tapKey(tester, 'avatar-use');
    expect(h.avatars.saved!.style, AvatarStyle.anime);
    expect(find.byType(VoiceScreen), findsOneWidget);
  });
}
