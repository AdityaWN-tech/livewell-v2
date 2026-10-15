import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/account/application/account_setup.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/avatar/data/selfie_service.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';
import 'package:livewell/features/avatar/presentation/avatar_creator_screen.dart';
import 'package:livewell/features/avatar/presentation/avatar_screen.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/voice/presentation/voice_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';

/// Signed in, at the "Create your coach" step.
Harness atAvatar({SelfieAnalyzer? selfie}) {
  final h = Harness(
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
    selfie: selfie,
  );
  h.profiles.existing[uid] = ProfileStep.avatar;
  return h;
}

/// Suggests fixed features and deletes the photo, like the real analyzer
/// (which is tested on its own below; image decoding needs real async).
class FakeSelfieAnalyzer extends SelfieAnalyzer {
  FakeSelfieAnalyzer(this.source, {this.result, this.fails = false})
    : super(source);

  final FakePhotoSource source;
  final SelfieSuggestion? result;
  final bool fails;

  @override
  Future<SelfieSuggestion?> takeAndSuggest() async {
    final path = await source.takeSelfie();
    if (path == null) return null;
    File(path).deleteSync();
    if (fails) throw Exception('unreadable');
    return result;
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Sync file calls: async IO never completes under the widget-test clock.
File tempPhoto() {
  final dir = Directory.systemTemp.createTempSync('selfie');
  return File('${dir.path}/selfie.jpg')..writeAsBytesSync([1, 2, 3]);
}

void main() {
  test('resumes at the avatar step (FR-ONB-06)', () {
    expect(routeForProfileStep(ProfileStep.avatar), '/onboarding/avatar');
  });

  test('style_config round-trips, and bad values fall back safely', () {
    final c = AvatarConfig.forLook(AvatarLook.woman).copyWith(
      skin: 9,
      headCovering: HeadCovering.hijab,
      glasses: Glasses.round,
    );
    expect(AvatarConfig.fromMap(c.toMap()), c);
    final bad = AvatarConfig.fromMap({'skin': 99, 'hair': 'mohawk'});
    expect(bad.skin, AvatarConfig.fallback.skin);
    expect(bad.hair, AvatarConfig.fallback.hair);
  });

  group('selfie suggestions are read on the phone', () {
    Uint8List image({required Color face, required Color hair}) {
      const w = 20, h = 20;
      final px = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final c = y < 4 ? hair : face;
          final i = (y * w + x) * 4;
          px[i] = (c.r * 255).round();
          px[i + 1] = (c.g * 255).round();
          px[i + 2] = (c.b * 255).round();
          px[i + 3] = 255;
        }
      }
      return px;
    }

    test('skin tone and hair colour from the face and the area above', () {
      final s = SelfieAnalyzer.suggestFromPixels(
        image(face: AvatarColours.skin[7], hair: AvatarColours.hair[0]),
        20,
        20,
      );
      expect(s.skin, 7);
      expect(s.hairColour, 0);
    });

    test('no hair suggestion when it can\'t be told from the skin', () {
      final s = SelfieAnalyzer.suggestFromPixels(
        image(face: AvatarColours.skin[3], hair: AvatarColours.skin[3]),
        20,
        20,
      );
      expect(s.skin, 3);
      expect(s.hairColour, isNull);
    });

    testWidgets('the real analyzer deletes the photo after reading it', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
          ..drawRect(
            const Rect.fromLTWH(0, 0, 40, 40),
            Paint()..color = AvatarColours.skin[5],
          )
          ..drawRect(
            const Rect.fromLTWH(0, 0, 40, 8),
            Paint()..color = AvatarColours.hair[0],
          );
        final img = await recorder.endRecording().toImage(40, 40);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = tempPhoto();
        await file.writeAsBytes(png!.buffer.asUint8List());
        final source = FakePhotoSource()..path = file.path;

        final s = await SelfieAnalyzer(source).takeAndSuggest();
        expect(s!.skin, 5);
        expect(s.hairColour, 0);
        expect(file.existsSync(), isFalse, reason: 'selfie deleted');

        // Even an unreadable photo is deleted.
        final junk = tempPhoto();
        source.path = junk.path;
        await expectLater(
          SelfieAnalyzer(source).takeAndSuggest(),
          throwsA(anything),
        );
        expect(junk.existsSync(), isFalse);
      });
    });
  });

  group('default avatar (fastest)', () {
    testWidgets('nothing is guessed: "Use this" waits for a chosen look', (
      tester,
    ) async {
      await atAvatar().boot(tester);
      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(find.text('Create your coach'), findsOneWidget);
      final use = tester.widget<FilledButton>(
        find.byKey(const Key('avatar-use')),
      );
      expect(use.onPressed, isNull);
    });

    for (final look in AvatarLook.values) {
      testWidgets('pick "${look.name}", Use this: saved, then the voice step', (
        tester,
      ) async {
        final h = atAvatar();
        await h.boot(tester);
        await tapKey(tester, 'avatar-look-${look.name}');
        await tapKey(tester, 'avatar-use');
        expect(h.avatars.saved, AvatarConfig.forLook(look));
        expect(h.profiles.existing[uid], ProfileStep.voice);
        expect(h.avatarDrafts.draft, isNull);
        expect(find.byType(VoiceScreen), findsOneWidget);
      });
    }

    testWidgets('"Skip, use default" never blocks', (tester) async {
      final h = atAvatar();
      await h.boot(tester);
      await tapKey(tester, 'avatar-skip');
      expect(h.avatars.saved, AvatarConfig.fallback);
      expect(find.byType(VoiceScreen), findsOneWidget);
    });

    testWidgets('a save error says so and stays', (tester) async {
      final h = atAvatar();
      h.avatars.fail = true;
      await h.boot(tester);
      await tapKey(tester, 'avatar-skip');
      expect(
        find.text('We couldn’t save your coach. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(h.profiles.existing[uid], ProfileStep.avatar);
    });
  });

  group('cartoon creator', () {
    testWidgets('every choice shows in the preview and is saved', (
      tester,
    ) async {
      final h = atAvatar();
      await h.boot(tester);
      await tapKey(tester, 'avatar-cartoon');
      expect(find.byType(AvatarCreatorScreen), findsOneWidget);
      await tapKey(tester, 'avatar-skin-9');
      await tapKey(tester, 'avatar-covering-Hijab');
      await tapKey(tester, 'avatar-glasses-Round');
      await tapKey(tester, 'avatar-background-3');
      final preview = tester.widget<AvatarView>(
        find.byKey(const Key('avatar-creator-preview')),
      );
      expect(preview.config.skin, 9);
      expect(preview.config.headCovering, HeadCovering.hijab);
      await tapKey(tester, 'avatar-creator-use');
      expect(h.avatars.saved!.skin, 9);
      expect(h.avatars.saved!.headCovering, HeadCovering.hijab);
      expect(h.avatars.saved!.glasses, Glasses.round);
      expect(h.avatars.saved!.background, 3);
      expect(find.byType(VoiceScreen), findsOneWidget);
    });

    testWidgets('closing the app mid-creator: it reopens with the choices', (
      tester,
    ) async {
      final h = atAvatar();
      h.avatarDrafts.draft = AvatarDraft(
        config: AvatarConfig.fallback.copyWith(
          skin: 7,
          glasses: Glasses.square,
        ),
        inCreator: true,
      );
      await h.boot(tester);
      expect(find.byType(AvatarCreatorScreen), findsOneWidget);
      final preview = tester.widget<AvatarView>(
        find.byKey(const Key('avatar-creator-preview')),
      );
      expect(preview.config.skin, 7);
      expect(preview.config.glasses, Glasses.square);
    });

    testWidgets('going back keeps the choices but not the creator', (
      tester,
    ) async {
      final h = atAvatar();
      await h.boot(tester);
      await tapKey(tester, 'avatar-cartoon');
      await tapKey(tester, 'avatar-skin-2');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(h.avatarDrafts.draft!.inCreator, isFalse);
      expect(h.avatarDrafts.draft!.config.skin, 2);
    });
  });

  group('selfie', () {
    testWidgets('consent declined: no camera, back to the other options', (
      tester,
    ) async {
      final h = atAvatar();
      await h.boot(tester);
      await tapKey(tester, 'avatar-selfie');
      expect(find.text('Use your selfie?'), findsOneWidget);
      await tapText(tester, 'Not now');
      expect(h.photos.taken, 0);
      expect(h.consents.records, isEmpty);
      expect(find.byType(AvatarScreen), findsOneWidget);
    });

    testWidgets(
      'allowed: camera + biometric consents, suggestion, photo gone',
      (tester) async {
        final photos = FakePhotoSource();
        final h = atAvatar(
          selfie: FakeSelfieAnalyzer(
            photos,
            result: const SelfieSuggestion(skin: 8, hairColour: 5),
          ),
        );
        final photo = tempPhoto();
        photos.path = photo.path;
        await h.boot(tester);
        await tapKey(tester, 'avatar-selfie');
        await tapText(tester, 'Allow');
        expect(h.consents.records.map((r) => r.type).toSet(), {
          ConsentType.camera,
          ConsentType.biometric,
        });
        expect(find.byType(AvatarCreatorScreen), findsOneWidget);
        expect(find.byKey(const Key('avatar-suggested')), findsOneWidget);
        final preview = tester.widget<AvatarView>(
          find.byKey(const Key('avatar-creator-preview')),
        );
        expect(preview.config.skin, 8);
        expect(preview.config.hairColour, 5);
        expect(photo.existsSync(), isFalse, reason: 'selfie deleted');
      },
    );

    testWidgets('camera cancelled: stays, nothing saved', (tester) async {
      final photos = FakePhotoSource();
      final h = atAvatar(selfie: FakeSelfieAnalyzer(photos));
      await h.consents.record(ConsentType.camera, granted: true);
      await h.consents.record(ConsentType.biometric, granted: true);
      await h.boot(tester);
      await tapKey(tester, 'avatar-selfie');
      expect(find.text('Use your selfie?'), findsNothing);
      expect(find.byType(AvatarScreen), findsOneWidget);
      expect(h.avatars.saved, isNull);
    });

    testWidgets('unreadable photo: says so, creator opens, photo gone', (
      tester,
    ) async {
      final photos = FakePhotoSource();
      final h = atAvatar(selfie: FakeSelfieAnalyzer(photos, fails: true));
      await h.consents.record(ConsentType.camera, granted: true);
      await h.consents.record(ConsentType.biometric, granted: true);
      final photo = tempPhoto();
      photos.path = photo.path;
      await h.boot(tester);
      await tapKey(tester, 'avatar-selfie');
      expect(find.byType(AvatarCreatorScreen), findsOneWidget);
      expect(photo.existsSync(), isFalse);
    });
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets('start and creator (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        await atAvatar().boot(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // No textContrastGuideline here: it reads screenshot pixels and,
        // inside a ChoiceChip, averages the chip outline into the label
        // (a false 3.25:1 for 12.6:1 text). Chip text and outline pairs are
        // checked exactly in test/design/tokens_test.dart.
        expect(find.bySemanticsLabel('Your coach’s avatar'), findsOneWidget);
        await tapKey(tester, 'avatar-cartoon');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(find.bySemanticsLabel('Skin tone 10 of 10'), findsOneWidget);
        handle.dispose();
      });
    }
  });
}
