/// The Anime coach's face from moment to moment (T-AVT-06b): which version
/// of the eyes, eyebrows and mouth to show for each expression, blinking,
/// and the A, I, U, E, O mouth shapes while the coach speaks. Every anime
/// eyes, eyebrows and lips part has each of these versions
/// (assets/avatar/parts_anime.json `variants`; a test keeps them in step).
library;

import '../../../core/design/avatar/avatar_art.dart' show AvatarExpression;
import 'anime_parts.dart';

enum AnimeEyes {
  open('open'),
  closedSmile('closed_smile'),
  sparkle('sparkle'),
  soft('soft'),
  halfClosed('half_closed'),
  blink('blink');

  const AnimeEyes(this.id);
  final String id;
}

enum AnimeBrows {
  neutral('neutral'),
  raised('raised'),
  soft('soft'),

  /// Slightly up in the middle.
  caring('caring');

  const AnimeBrows(this.id);
  final String id;
}

enum AnimeMouth {
  closedSmile('closed_smile'),
  openSmile('open_smile'),
  a('a'),
  i('i'),
  u('u'),
  e('e'),
  o('o'),
  closed('closed');

  const AnimeMouth(this.id);
  final String id;

  /// How open the mouth is, 0 to 1 (the placeholder pulses with it).
  double get openness => switch (this) {
    AnimeMouth.a || AnimeMouth.o || AnimeMouth.openSmile => 1,
    AnimeMouth.e || AnimeMouth.u => 0.6,
    AnimeMouth.i => 0.4,
    AnimeMouth.closedSmile || AnimeMouth.closed => 0,
  };
}

/// The versions shown right now, plus the celebrating extras.
class AnimeFace {
  const AnimeFace({
    required this.eyes,
    required this.brows,
    required this.mouth,
    this.blush = false,
    this.sparkles = false,
  });

  final AnimeEyes eyes;
  final AnimeBrows brows;
  final AnimeMouth mouth;

  /// Extra blush on celebrating.
  final bool blush;

  /// Small sparkles or hearts around the head on celebrating; never with
  /// reduced motion.
  final bool sparkles;

  /// The face for [expression]. [blink] closes the eyes for a moment;
  /// [speaking] is the mouth shape while the coach talks.
  factory AnimeFace.of(
    AvatarExpression expression, {
    bool blink = false,
    AnimeMouth? speaking,
    bool reducedMotion = false,
  }) {
    final base = switch (expression) {
      AvatarExpression.happy => const AnimeFace(
        eyes: AnimeEyes.closedSmile,
        brows: AnimeBrows.raised,
        mouth: AnimeMouth.closedSmile,
      ),
      AvatarExpression.waving => const AnimeFace(
        eyes: AnimeEyes.open,
        brows: AnimeBrows.raised,
        mouth: AnimeMouth.openSmile,
      ),
      AvatarExpression.talking => const AnimeFace(
        eyes: AnimeEyes.open,
        brows: AnimeBrows.neutral,
        mouth: AnimeMouth.closed,
      ),
      AvatarExpression.listening => const AnimeFace(
        eyes: AnimeEyes.halfClosed,
        brows: AnimeBrows.caring,
        mouth: AnimeMouth.closed,
      ),
      AvatarExpression.calm => const AnimeFace(
        eyes: AnimeEyes.soft,
        brows: AnimeBrows.soft,
        mouth: AnimeMouth.closedSmile,
      ),
      AvatarExpression.celebrating => AnimeFace(
        eyes: AnimeEyes.sparkle,
        brows: AnimeBrows.raised,
        mouth: AnimeMouth.openSmile,
        blush: true,
        sparkles: !reducedMotion,
      ),
    };
    return AnimeFace(
      eyes: blink ? AnimeEyes.blink : base.eyes,
      brows: base.brows,
      mouth: speaking ?? base.mouth,
      blush: base.blush,
      sparkles: base.sparkles,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnimeFace &&
      (other.eyes, other.brows, other.mouth, other.blush, other.sparkles) ==
          (eyes, brows, mouth, blush, sparkles);

  @override
  int get hashCode => Object.hash(eyes, brows, mouth, blush, sparkles);
}

/// The mouth shapes for one spoken word, from its vowels (y sounds like I),
/// repeats merged; a word without vowels just opens a little (E).
List<AnimeMouth> visemesFor(String word) {
  final out = <AnimeMouth>[];
  for (final ch in word.toLowerCase().split('')) {
    final m = switch (ch) {
      'a' => AnimeMouth.a,
      'i' || 'y' => AnimeMouth.i,
      'u' || 'w' => AnimeMouth.u,
      'e' => AnimeMouth.e,
      'o' => AnimeMouth.o,
      _ => null,
    };
    if (m != null && (out.isEmpty || out.last != m)) out.add(m);
  }
  return out.isEmpty ? [AnimeMouth.e] : out;
}

/// The mouth shape [tick] steps into the word around [offset] in [text]:
/// the shapes of the word, then closed between words.
AnimeMouth visemeAt(String text, int offset, int tick) {
  if (text.isEmpty) return AnimeMouth.closed;
  final at = offset.clamp(0, text.length - 1);
  final words = RegExp(r"[A-Za-z']+").allMatches(text).toList();
  final word = words.where((w) => w.end > at).firstOrNull ?? words.lastOrNull;
  if (word == null) return AnimeMouth.closed;
  final shapes = [...visemesFor(word.group(0)!), AnimeMouth.closed];
  return shapes[tick % shapes.length];
}

/// One layer of the Anime coach, back to front: the part, its option and
/// (for eyes, eyebrows and lips) the version shown.
typedef AnimeLayer = (String part, String option, String? variant);

/// The layers to draw for [anime] parts under [headCovering] with [face],
/// back to front, without those hidden by the rules. The art kit's files
/// are looked up by these ids (T-AVT-06c).
List<AnimeLayer> animeLayers(
  AnimeParts anime,
  String headCovering,
  AnimeFace face, {
  String glasses = 'none',
}) {
  final hidden = anime.hiddenUnder(headCovering);
  AnimeLayer? part(AnimeCategory c, [String? variant]) =>
      hidden.contains(c) || anime[c] == 'none'
      ? null
      : (c.id, anime[c], variant);
  return [
    ?part(AnimeCategory.hair, 'back'),
    ?part(AnimeCategory.outfit),
    ?part(AnimeCategory.face),
    ?part(AnimeCategory.accessory),
    if (headCovering != 'none') ('head_covering', headCovering, null),
    ?part(AnimeCategory.blush),
    if (face.blush) ('extra', 'blush_celebrate', null),
    ?part(AnimeCategory.eyes, face.eyes.id),
    ?part(AnimeCategory.eyeHighlight),
    ?part(AnimeCategory.eyebrows, face.brows.id),
    ?part(AnimeCategory.nose),
    ?part(AnimeCategory.lips, face.mouth.id),
    ?part(AnimeCategory.hair, 'front'),
    ?part(AnimeCategory.bangs),
    ?part(AnimeCategory.hairAccessory),
    ?part(AnimeCategory.cap),
    if (glasses != 'none') ('glasses', glasses, null),
    if (face.sparkles) ('extra', 'sparkles', null),
  ];
}
