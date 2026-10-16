import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/core/design/components/speech_bubble.dart';
import 'package:livewell/core/design/illustration/illustration.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/avatar/presentation/coach_avatar.dart';
import 'package:livewell/l10n/app_localizations.dart';

import '../support/fakes.dart';

/// T-UI-02b: the illustration manifest, the Illustration widget and the
/// CoachAvatar with its 6 expressions and speech bubble.

final manifestJson = File('assets/illustrations/illustrations.json')
    .readAsStringSync();
final catalog = IllustrationCatalog.parse(manifestJson);

class _ThrowingAvatars extends FakeAvatarRepository {
  @override
  Future<AvatarConfig?> load() async => throw Exception('offline');
}

Widget app(
  Widget child, {
  bool dark = false,
  double scale = 1,
  double width = 400,
  AvatarRepository? avatars,
}) => ProviderScope(
  overrides: [
    avatarRepositoryProvider.overrideWithValue(
      avatars ?? FakeAvatarRepository(),
    ),
  ],
  child: MaterialApp(
    theme: dark ? LwTheme.dark() : LwTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  setUp(() => IllustrationCatalog.debugValue = catalog);
  tearDown(() => IllustrationCatalog.debugValue = null);

  group('manifest (illustrations.json)', () {
    final items = catalog.entries.toList();
    const tints = {
      'mint',
      'lime',
      'lavender',
      'peach',
      'sky',
      'butter',
      'rose',
    };
    const kinds = {'character', 'scene', 'lesson', 'icon', 'empty', 'feature'};

    test('ids are unique and every field is valid', () {
      final ids = RegExp(r'"id": "([^"]+)"')
          .allMatches(manifestJson)
          .map((m) => m[1])
          .toList();
      expect(ids.toSet().length, ids.length);
      expect(items.length, ids.length);
      for (final e in items) {
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(e.id), isTrue, reason: e.id);
        expect(kinds, contains(e.kind), reason: e.id);
        expect(tints, contains(e.tint), reason: e.id);
        expect(['placeholder', 'final'], contains(e.status), reason: e.id);
        expect(illustrationIcons.keys, contains(e.fallbackIcon), reason: e.id);
        if (!e.decorative) expect(e.alt, isNotEmpty, reason: e.id);
      }
    });

    test('a final asset has its file, a source and a commercial licence', () {
      for (final e in items) {
        for (final f in [e.file, e.fileDark].nonNulls) {
          expect(
            File('assets/illustrations/$f').existsSync(),
            isTrue,
            reason: '${e.id}: $f is missing',
          );
        }
        if (e.isFinal) {
          expect(e.file, isNotNull, reason: e.id);
          expect(e.source, isNotEmpty, reason: e.id);
          expect(e.licence, isNotEmpty, reason: e.id);
        }
      }
    });

    test('covers everything the task lists', () {
      int count(String kind, [String prefix = '']) =>
          items.where((e) => e.kind == kind && e.id.startsWith(prefix)).length;
      expect(count('character'), greaterThanOrEqualTo(4));
      expect(catalog['character_wheelchair'], isNotNull);
      expect(count('scene', 'scene_'), 2);
      expect(count('scene', 'studio_bg_'), greaterThanOrEqualTo(3));
      for (final id in [
        'lesson_breathe_reset',
        'lesson_reduce_stress',
        'lesson_better_sleep',
        'lesson_move_body',
        'lesson_mindful_eating',
        'lesson_deep_breathing',
        'icon_mood',
        'icon_energy',
        'icon_sleep',
        'icon_stress',
        'icon_streak',
        'icon_steps',
        'icon_water',
        'icon_goal',
        'icon_reflection',
        'empty_no_data',
        'empty_offline',
        'empty_coming_soon',
        'feature_notifications',
        'feature_travel',
        'feature_reflection',
        'feature_portal',
        'feature_watch',
      ]) {
        expect(catalog[id], isNotNull, reason: id);
      }
      expect(count('lesson', 'lesson_driver_'), 8);
      expect(count('icon', 'wheel_driver_'), 8);
    });

    test('docs/design/asset-brief.md lists every asset', () {
      final brief = File('../../docs/design/asset-brief.md').readAsStringSync();
      for (final e in items) {
        expect(brief, contains('`${e.id}`'), reason: e.id);
      }
    });

    test('the manifest is bundled with the app', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/illustrations/'),
      );
    });
  });

  group('Illustration', () {
    testWidgets('a placeholder is a soft shape; decorative art is hidden', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const Illustration('icon_mood', width: 96, height: 96)),
      );
      expect(find.byType(IllustrationPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        tester.getSemantics(find.byType(IllustrationPlaceholder)).label,
        isEmpty,
      );
      handle.dispose();
    });

    testWidgets('meaningful art is read with its alt text', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const Illustration('empty_offline', width: 96, height: 96)),
      );
      expect(find.bySemanticsLabel('You are offline'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an unknown id never breaks the screen', (tester) async {
      await tester.pumpWidget(app(const Illustration('nope', width: 64)));
      expect(find.byType(IllustrationPlaceholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('the $mode file is used; if missing, the placeholder', (
        tester,
      ) async {
        IllustrationCatalog.debugValue = IllustrationCatalog([
          const IllustrationEntry(
            id: 'x',
            kind: 'scene',
            alt: 'A garden',
            decorative: false,
            tint: 'sky',
            fallbackIcon: 'leaf',
            status: 'placeholder',
            file: 'x.png',
            fileDark: 'x_dark.png',
          ),
        ]);
        await tester.pumpWidget(
          app(const Illustration('x', width: 96, height: 96), dark: dark),
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          dark
              ? 'assets/illustrations/x_dark.png'
              : 'assets/illustrations/x.png',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(IllustrationPlaceholder), findsOneWidget);
      });
    }
  });

  group('CoachAvatar', () {
    for (final x in AvatarExpression.values) {
      testWidgets('draws the ${x.name} expression', (tester) async {
        await tester.pumpWidget(app(CoachAvatar(expression: x)));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('coach-avatar-${x.name}')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('uses the saved avatar (avatar/current)', (tester) async {
      final saved = AvatarConfig.forLook(AvatarLook.woman);
      await tester.pumpWidget(
        app(
          const CoachAvatar(),
          avatars: FakeAvatarRepository()..saved = saved,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AvatarView>(find.byType(AvatarView)).config, saved);
    });

    for (final (name, repo) in [
      ('no avatar yet', FakeAvatarRepository()),
      ('unreadable', _ThrowingAvatars()),
    ]) {
      testWidgets('$name: the default coach (green top)', (tester) async {
        await tester.pumpWidget(app(const CoachAvatar(), avatars: repo));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AvatarView>(find.byType(AvatarView)).config,
          defaultCoach,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the coach and the bubble are both read out', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const CoachAvatar(bubble: 'Good morning!')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Your coach'), findsOneWidget);
      expect(find.text('Good morning!'), findsOneWidget);
      handle.dispose();
    });

    for (final (scale, width, beside) in [
      (1.0, 400.0, true),
      (1.3, 400.0, true),
      (2.0, 400.0, false),
      (1.0, 280.0, false),
    ]) {
      final where = beside ? 'beside' : 'above';
      testWidgets('bubble $where the coach (text $scale, $width dp)', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            const CoachAvatar(bubble: 'I am here for you.'),
            scale: scale,
            width: width,
          ),
        );
        await tester.pumpAndSettle();
        final bubble = tester.widget<SpeechBubble>(
          find.byKey(const Key('coach-bubble')),
        );
        expect(bubble.tail, beside ? BubbleTail.left : BubbleTail.bottom);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
