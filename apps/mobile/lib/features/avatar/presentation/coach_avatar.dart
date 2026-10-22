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
import '../../../core/config/flavor.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../dev/application/preview_mode.dart';
import '../data/avatar_frames_store.dart';
import '../data/avatar_repository.dart';
import '../domain/coach_choice.dart';
import '../domain/coaches.dart';
import '../domain/avatar_frames.dart';

export '../../../core/design/avatar/avatar_art.dart' show AvatarExpression;

/// The person's coach from users/{uid}/avatar/current (T-AVT-08b), or the
/// default ready-made coach.
final coachChoiceProvider = FutureProvider<CoachChoice>((ref) async {
  try {
    return await ref.watch(avatarRepositoryProvider).load() ??
        CoachChoice.fallback;
  } catch (_) {
    // Offline or unreadable: the default, never an error on screen.
    return CoachChoice.fallback;
  }
});

/// The coach's background colour.
final coachBackgroundProvider = Provider<Color>((ref) {
  final choice = ref.watch(coachChoiceProvider).value ?? CoachChoice.fallback;
  return AvatarColours.background[choice.background];
});

/// Blinking and idle breathing on (tests turn it off so screens settle).
final avatarIdleMotionProvider = Provider<bool>((ref) => true);

/// The person's made-for-you frame set version (selfie or built), once the
/// Media Service has made it (T-AVT-08c/d).
final avatarFramesVersionProvider = Provider<int?>(
  (ref) => ref.watch(coachChoiceProvider).value?.framesVersion,
);

/// Whether a ready-made coach's art may be shown: always in dev builds;
/// elsewhere only once its art is final (illustrations.json), so nobody
/// outside development sees placeholder cards.
final readyCoachArtFinalProvider = FutureProvider.family<bool, ReadyCoach>((
  ref,
  coach,
) async {
  if (ref.watch(flavorProvider) == Flavor.dev) return true;
  final catalog = await IllustrationCatalog.load();
  return catalog[coach.illustrationId]?.status == 'final';
});

/// A ready-made coach's bundled frame set, or null while its art isn't
/// final (outside dev) or can't be read.
final readyCoachFramesProvider =
    FutureProvider.family<AvatarImages?, ReadyCoach>((ref, coach) async {
      try {
        if (!await ref.watch(readyCoachArtFinalProvider(coach).future)) {
          return null;
        }
        final manifest = AvatarFrameManifest.fromJson(
          jsonDecode(
            await rootBundle.loadString(
              '${coach.framesDir}/avatar_frames.json',
            ),
          ) as Map<String, dynamic>,
        );
        return assetFrames(manifest, coach.framesDir);
      } catch (_) {
        return null;
      }
    });

/// The chosen ready-made coach's frames (the default coach step of the
/// fallback chain).
final defaultCoachImagesProvider = FutureProvider<AvatarImages?>((ref) async {
  final choice = ref.watch(coachChoiceProvider).value ?? CoachChoice.fallback;
  return ref.watch(readyCoachFramesProvider(choice.coach).future);
});

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
