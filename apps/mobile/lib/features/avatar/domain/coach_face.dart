/// Which frame the coach shows from moment to moment (T-AVT-08a): the
/// expression, blinking, and the A, I, U, E, O mouth shapes while the coach
/// speaks. Kept from the anime work (T-AVT-06b) because it doesn't depend
/// on the art style.
library;

import '../../../core/design/avatar/avatar_art.dart' show AvatarExpression;
import 'avatar_frames.dart';

/// The talking mouth shapes (lip movement).
enum MouthShape {
  a(AvatarFrame.mouthA),
  i(AvatarFrame.mouthI),
  u(AvatarFrame.mouthU),
  e(AvatarFrame.mouthE),
  o(AvatarFrame.mouthO),
  closed(AvatarFrame.mouthClosed);

  const MouthShape(this.frame);
  final AvatarFrame frame;
}

/// The frame for [expression] at rest.
AvatarFrame expressionFrame(AvatarExpression expression) =>
    switch (expression) {
      AvatarExpression.happy => AvatarFrame.happy,
      AvatarExpression.waving => AvatarFrame.waving,
      AvatarExpression.listening => AvatarFrame.listening,
      AvatarExpression.calm => AvatarFrame.calm,
      AvatarExpression.celebrating => AvatarFrame.celebrating,
      // Talking is the neutral face with the mouth frames on it.
      AvatarExpression.talking => AvatarFrame.neutral,
    };

/// Whether the eyes can blink on [frame]: the blink frame is the neutral
/// face with closed eyes, so only the neutral face and the mouth frames
/// (which keep the neutral eyes) blink; other expressions hold still.
bool canBlink(AvatarFrame frame) =>
    frame == AvatarFrame.neutral ||
    MouthShape.values.any((m) => m.frame == frame);

/// The frame to show now. [still] (reduced motion) is always the neutral
/// face. While speaking, [mouth] picks the mouth frame; [blink] closes the
/// eyes for a moment where the face allows it.
AvatarFrame frameFor(
  AvatarExpression expression, {
  bool blink = false,
  MouthShape? mouth,
  bool still = false,
}) {
  if (still) return AvatarFrame.neutral;
  final base = mouth?.frame ?? expressionFrame(expression);
  return blink && canBlink(base) ? AvatarFrame.blink : base;
}

/// The mouth shapes for one spoken word, from its vowels (y sounds like I,
/// w like U), repeats merged; a word without vowels opens a little (E).
List<MouthShape> visemesFor(String word) {
  final out = <MouthShape>[];
  for (final ch in word.toLowerCase().split('')) {
    final m = switch (ch) {
      'a' => MouthShape.a,
      'i' || 'y' => MouthShape.i,
      'u' || 'w' => MouthShape.u,
      'e' => MouthShape.e,
      'o' => MouthShape.o,
      _ => null,
    };
    if (m != null && (out.isEmpty || out.last != m)) out.add(m);
  }
  return out.isEmpty ? [MouthShape.e] : out;
}

/// The mouth shape [tick] steps into the word around [offset] in [text]:
/// the word's shapes, then closed between words.
MouthShape visemeAt(String text, int offset, int tick) {
  if (text.isEmpty) return MouthShape.closed;
  final at = offset.clamp(0, text.length - 1);
  final words = RegExp(r"[A-Za-z']+").allMatches(text).toList();
  final word = words.where((w) => w.end > at).firstOrNull ?? words.lastOrNull;
  if (word == null) return MouthShape.closed;
  final shapes = [...visemesFor(word.group(0)!), MouthShape.closed];
  return shapes[tick % shapes.length];
}

/// Mouth shapes from loudness (0 to 1), for voices without word timing.
MouthShape visemeForLoudness(double level, int tick) => level < 0.08
    ? MouthShape.closed
    : level > 0.6
    ? (tick.isEven ? MouthShape.a : MouthShape.o)
    : (tick.isEven ? MouthShape.e : MouthShape.i);
