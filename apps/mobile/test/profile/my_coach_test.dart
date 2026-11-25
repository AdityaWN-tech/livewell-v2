import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/features/avatar/application/avatar_deletion.dart';
import 'package:livewell/features/avatar/data/avatar_frames_store.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
import 'package:livewell/features/avatar/domain/coaches.dart';
import 'package:livewell/features/studio/presentation/studio_screen.dart';
import 'package:livewell/features/studio/presentation/studio_widgets.dart';

import '../support/fakes.dart';
import 'profile_test.dart' show confirm, openProfile, signedIn, tapKey, uid;

/// A coach made from the person's selfie, with its own frame set.
const _fromPhoto = CoachChoice(
  source: CoachSource.selfie,
  coach: ReadyCoach.greenHijab,
  framesVersion: 3,
  coachName: 'Maya',
  background: 2,
);

void main() {
  group('Profile > My coach (T-AVT-08h)', () {
    testWidgets('preview, coach name and the ways to change the coach; '
        'photo, build and adjust hidden while their flags are off', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = _fromPhoto;
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-coach-preview');
      expect(find.byType(StudioScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final preview = find.byKey(const Key('profile-coach-preview'));
      expect(
        find.descendant(of: preview, matching: find.text('Maya')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text('Made from your photo'),
        ),
        findsOneWidget,
      );
      for (final key in [
        'profile-avatar',
        'profile-voice',
        'profile-coach-name',
        'profile-delete-avatar',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(Key(key)),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(find.text('Choose another coach'), findsOneWidget);
      for (final key in [
        'profile-avatar-photo',
        'profile-avatar-build',
        'profile-avatar-adjust',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
    });

    for (final (key, tab) in [
      ('profile-avatar', StudioTab.coaches),
      ('profile-avatar-photo', StudioTab.photo),
      ('profile-avatar-build', StudioTab.build),
      ('profile-avatar-adjust', StudioTab.adjust),
      ('profile-voice', StudioTab.voice),
    ]) {
      testWidgets('$key opens the Studio on ${tab.name} (flags on)', (
        tester,
      ) async {
        final h = signedIn(
          flags: const FeatureFlags(avatarFromPhoto: true, avatarMaker: true),
        );
        await h.boot(tester);
        await openProfile(tester);
        await tapKey(tester, key);
        final studio = tester.widget<StudioScreen>(find.byType(StudioScreen));
        expect(studio.initialTab, tab);
      });
    }

    testWidgets('"Remake from a new photo" needs the photo flag, not only '
        'the maker', (tester) async {
      final h = signedIn(flags: const FeatureFlags(avatarMaker: true));
      await h.boot(tester);
      await openProfile(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-delete-avatar')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('profile-avatar-photo')), findsNothing);
      expect(find.byKey(const Key('profile-avatar-build')), findsOneWidget);
    });
  });

  group('Delete my avatar (FR-SET-03, T-AVT-05)', () {
    testWidgets('the dialog says what goes, that it can’t be undone and '
        'that a ready-made coach takes over; "Keep it" changes nothing', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = _fromPhoto;
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-delete-avatar');
      final dialog = find.byKey(const Key('delete-avatar-dialog'));
      expect(dialog, findsOneWidget);
      expect(find.text('Delete your avatar?'), findsOneWidget);
      for (final words in [
        'portrait',
        'every picture of its faces',
        'avatar partner',
        'can’t be undone',
        'A ready-made coach will take over',
      ]) {
        expect(
          find.descendant(of: dialog, matching: find.textContaining(words)),
          findsOneWidget,
          reason: words,
        );
      }
      // Calm words: nothing fear-based.
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining(RegExp('warning|danger|!')),
        ),
        findsNothing,
      );
      await tapKey(tester, 'delete-avatar-keep');
      expect(h.deletions.calls, isEmpty);
      expect(h.avatarLocal.cleared, isEmpty);
    });

    testWidgets('confirmed: the server deletes, this phone forgets its '
        'copies, the widget is refreshed and a ready-made coach shows', (
      tester,
    ) async {
      final h = signedIn();
      h.avatars.saved = _fromPhoto;
      // What the server does (services/core-api deleteAvatar, D-78).
      h.deletions.onCall = (name) {
        if (name == 'avatar') {
          h.avatars.saved = const CoachChoice(
            coach: ReadyCoach.greenHijab,
            coachName: 'Maya',
            background: 2,
          );
        }
      };
      await h.boot(tester);
      await openProfile(tester);
      final published = h.widget.published.length;
      await tapKey(tester, 'profile-delete-avatar');
      await confirm(tester);

      expect(h.deletions.calls, ['avatar']);
      expect(h.avatarLocal.cleared, [uid]);
      expect(h.widget.published.length, greaterThan(published));
      expect(
        find.text(
          'Your avatar is deleted. A ready-made coach is with you now.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-coach-preview')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('A ready-made coach'), findsOneWidget);
      expect(find.text('Made from your photo'), findsNothing);
    });

    testWidgets('server not reachable: says so, keeps everything on the '
        'phone, and "Try again" works', (tester) async {
      final h = signedIn();
      h.avatars.saved = _fromPhoto;
      h.deletions.fail = true;
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-delete-avatar');
      await confirm(tester);

      expect(h.deletions.calls, isEmpty);
      expect(h.avatarLocal.cleared, isEmpty, reason: 'never pretend');
      expect(find.textContaining('hasn’t been deleted yet'), findsOneWidget);
      expect(find.textContaining('avatar is deleted'), findsNothing);

      h.deletions.fail = false;
      await tester.tap(find.byKey(const Key('delete-avatar-retry')));
      await tester.pumpAndSettle();
      expect(h.deletions.calls, ['avatar']);
      expect(h.avatarLocal.cleared, [uid]);
      expect(
        find.text(
          'Your avatar is deleted. A ready-made coach is with you now.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the phone’s copies (T-AVT-05 local purge)', () {
    test('frame sets for this person and the widget’s faces are '
        'cleared; another account’s stay', () async {
      final root = await Directory.systemTemp.createTemp('lw-frames');
      addTearDown(() => root.delete(recursive: true));
      Future<File> put(String path) async => File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      final mine = await put('avatars/$uid/3/neutral@2x.webp');
      final manifest = await put('avatars/$uid/3/avatar_frames.json');
      final partial = await put('avatars/$uid/4.part/happy@2x.webp');
      final other = await put('avatars/someone-else/1/neutral@2x.webp');
      final widget = FakeWidgetPublisher();
      final local = DeviceAvatarLocalData(
        AvatarFrameCache(root: () async => root, source: _NoFrames()),
        widget,
      );

      await local.clear(uid);

      for (final f in [mine, manifest, partial]) {
        expect(f.existsSync(), isFalse, reason: f.path);
      }
      expect(Directory('${root.path}/avatars/$uid').existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(widget.facesCleared, 1);

      // Nothing there: still fine.
      await local.clear(uid);
      expect(widget.facesCleared, 2);
    });
  });
}

class _NoFrames implements AvatarFrameSource {
  @override
  Future<Map<String, Uri>> signedUrls({
    required String uid,
    required int version,
  }) async => const {};
}
