import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/speech_bubble.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../dev/application/preview_mode.dart';
import '../data/avatar_frames_store.dart';
import '../data/avatar_repository.dart';
import '../domain/avatar_config.dart';
import '../domain/avatar_frames.dart';

export '../../../core/design/avatar/avatar_art.dart' show AvatarExpression;

/// The person's saved avatar settings from users/{uid}/avatar/current (the
/// background for now), or the default.
/// TODO(T-AVT-08b): the 3d_adult document (source, frames_version, options,
/// coach_name) replaces the cartoon style_config.
final coachAvatarConfigProvider = FutureProvider<AvatarConfig>((ref) async {
  try {
    return await ref.watch(avatarRepositoryProvider).load() ?? defaultCoach;
  } catch (_) {
    // Offline or unreadable: the default, never an error on screen.
    return defaultCoach;
  }
});

/// The default settings (mint background).
final defaultCoach = AvatarConfig.fallback.copyWith(clothingColour: 0);

/// The coach's background colour.
final coachBackgroundProvider = Provider<Color>((ref) {
  final config = ref.watch(coachAvatarConfigProvider).value ?? defaultCoach;
  return AvatarColours.background[config.background];
});

/// Blinking and idle breathing on (tests turn it off so screens settle).
final avatarIdleMotionProvider = Provider<bool>((ref) => true);

/// The person's frame set version, once they have one.
/// TODO(T-AVT-08b): from users/{uid}/avatar/current.frames_version.
final avatarFramesVersionProvider = Provider<int?>((ref) => null);

/// The default coach's frames, bundled with the app.
/// TODO(T-AVT-08b): the 8 ready-made coaches; none are bundled yet.
final defaultCoachImagesProvider = FutureProvider<AvatarImages?>((ref) async {
  // The dev preview shows the placeholder frames (dev builds only).
  if (ref.watch(previewModeProvider)) {
    return ref.watch(placeholderFramesProvider.future);
  }
  return null;
});

/// The placeholder frame set (labelled cards, no face) for developing the
/// player before the art exists. Dev preview and the dev gallery only.
final placeholderFramesProvider = FutureProvider<AvatarImages?>((ref) async {
  try {
    return assetFrames(
      AvatarFrameManifest.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            '$placeholderFramesDir/avatar_frames.json',
          ),
        ) as Map<String, dynamic>,
      ),
      placeholderFramesDir,
    );
  } catch (_) {
    return null;
  }
});

const placeholderFramesDir = 'assets/avatar/frames/placeholder';

/// A bundled frame set as images.
AvatarImages assetFrames(
  AvatarFrameManifest m,
  String dir, {
  double devicePixelRatio = 3,
}) => AvatarImages({
  for (final f in AvatarFrame.values)
    if (m.fileFor(f, devicePixelRatio: devicePixelRatio) case final name?)
      f: AssetImage('$dir/$name'),
});

/// The images for a frame set on the device: the whole set, or only the
/// neutral face when that is all there is, or null.
AvatarImages? cachedFrames(CachedFrameSet? set, {double devicePixelRatio = 3}) {
  if (set == null) return null;
  File? file(AvatarFrame f) => set.file(f, devicePixelRatio: devicePixelRatio);
  if (set.complete) {
    return AvatarImages({
      for (final f in AvatarFrame.values)
        if (file(f) case final x?) f: FileImage(x),
    });
  }
  final neutral = file(AvatarFrame.neutral);
  return neutral == null ? null : AvatarImages.neutral(FileImage(neutral));
}

/// The fallback chain (FR-AVT-05): the person's frame set → its neutral
/// frame only → the default coach → null (the initial circle).
AvatarImages? pickCoachImages({
  AvatarImages? own,
  AvatarImages? defaultCoach,
}) => own ?? defaultCoach;

/// The person's own frame set on the device (downloaded once per version),
/// or null.
final ownFrameSetProvider = FutureProvider<CachedFrameSet?>((ref) async {
  final uid = ref.watch(signedInUidProvider);
  final version = ref.watch(avatarFramesVersionProvider);
  if (uid == null || version == null || ref.watch(previewModeProvider)) {
    return null;
  }
  try {
    return await ref.watch(avatarFrameCacheProvider).load(uid, version);
  } catch (_) {
    return null;
  }
});

/// The coach's images now, following the fallback chain. Cached on the
/// device, so it works offline once downloaded.
final coachImagesProvider = FutureProvider<AvatarImages?>((ref) async {
  final own = cachedFrames(await ref.watch(ownFrameSetProvider.future));
  AvatarImages? fallback;
  try {
    fallback = await ref.watch(defaultCoachImagesProvider.future);
  } catch (_) {
    fallback = null;
  }
  return pickCoachImages(own: own, defaultCoach: fallback);
});

/// The coach with an [expression] and an optional speech [bubble]
/// (T-UI-02b), used on Home, Care and the Studio. The bubble sits beside
/// the coach, or below it when there isn't room (small phones, large text).
class CoachAvatar extends ConsumerWidget {
  const CoachAvatar({
    super.key,
    this.expression = AvatarExpression.happy,
    this.bubble,
    this.size = 120,
    this.animate = true,
  });

  final AvatarExpression expression;
  final String? bubble;
  final double size;

  /// Blinks and breathes (unless reduced motion).
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final face = AvatarView(
      key: Key('coach-avatar-${expression.name}'),
      images: ref.watch(coachImagesProvider).value,
      background: ref.watch(coachBackgroundProvider),
      size: size,
      expression: expression,
      animate: animate && ref.watch(avatarIdleMotionProvider),
      semanticLabel: l.coachAvatarLabel,
    );
    if (bubble == null) return face;
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final beside = c.maxWidth >= size + 180 && scale <= 1.3;
        final speech = SpeechBubble(
          key: const Key('coach-bubble'),
          text: bubble!,
          tail: beside ? BubbleTail.left : BubbleTail.bottom,
        );
        if (beside) {
          return Row(
            children: [
              face,
              const SizedBox(width: LwSpacing.xs),
              Expanded(child: speech),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            speech,
            const SizedBox(height: LwSpacing.xs),
            face,
          ],
        );
      },
    );
  }
}
