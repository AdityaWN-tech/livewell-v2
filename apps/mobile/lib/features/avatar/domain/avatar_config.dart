/// The coach's stylized avatar (FR-AVT-01/02), stored as
/// users/{uid}/avatar/current.style_config. Everything is a choice the
/// person makes; nothing is guessed from their photo or name.
library;

/// Starting look for the quick option. Chosen by the person, never inferred.
enum AvatarLook { woman, man, neutral }

enum HairStyle { none, short, long, curly, coily, wavy, bun, buzz }

enum EyeShape { round, almond, smiling }

enum Glasses { none, round, square }

enum HeadCovering { none, hijab, turban, kippah }

enum Clothing { crew, collar, cardigan }

/// Number of options in each palette (colours live in core/design/avatar).
abstract final class AvatarPalettes {
  static const skinTones = 10;
  static const hairColours = 7;
  static const clothingColours = 6;
  static const backgrounds = 6;
}

class AvatarConfig {
  const AvatarConfig({
    required this.skin,
    required this.hair,
    required this.hairColour,
    required this.eyes,
    required this.glasses,
    required this.headCovering,
    required this.clothing,
    required this.clothingColour,
    required this.background,
    this.look,
  });

  /// Palette indexes.
  final int skin;
  final HairStyle hair;
  final int hairColour;
  final EyeShape eyes;
  final Glasses glasses;
  final HeadCovering headCovering;
  final Clothing clothing;
  final int clothingColour;
  final int background;

  /// The starting look picked, if any (kept for "reset to start").
  final AvatarLook? look;

  /// The default for each starting look. Skin and hair stay mid-range so the
  /// default doesn't stand for any one group; the person changes them.
  static AvatarConfig forLook(AvatarLook look) => switch (look) {
    AvatarLook.woman => const AvatarConfig(
      skin: 4,
      hair: HairStyle.long,
      hairColour: 1,
      eyes: EyeShape.almond,
      glasses: Glasses.none,
      headCovering: HeadCovering.none,
      clothing: Clothing.cardigan,
      clothingColour: 0,
      background: 0,
      look: AvatarLook.woman,
    ),
    AvatarLook.man => const AvatarConfig(
      skin: 4,
      hair: HairStyle.short,
      hairColour: 1,
      eyes: EyeShape.round,
      glasses: Glasses.none,
      headCovering: HeadCovering.none,
      clothing: Clothing.collar,
      clothingColour: 1,
      background: 0,
      look: AvatarLook.man,
    ),
    AvatarLook.neutral => const AvatarConfig(
      skin: 4,
      hair: HairStyle.wavy,
      hairColour: 1,
      eyes: EyeShape.smiling,
      glasses: Glasses.none,
      headCovering: HeadCovering.none,
      clothing: Clothing.crew,
      clothingColour: 2,
      background: 0,
      look: AvatarLook.neutral,
    ),
  };

  /// "Skip, use default".
  static final fallback = forLook(AvatarLook.neutral);

  AvatarConfig copyWith({
    int? skin,
    HairStyle? hair,
    int? hairColour,
    EyeShape? eyes,
    Glasses? glasses,
    HeadCovering? headCovering,
    Clothing? clothing,
    int? clothingColour,
    int? background,
  }) => AvatarConfig(
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    hairColour: hairColour ?? this.hairColour,
    eyes: eyes ?? this.eyes,
    glasses: glasses ?? this.glasses,
    headCovering: headCovering ?? this.headCovering,
    clothing: clothing ?? this.clothing,
    clothingColour: clothingColour ?? this.clothingColour,
    background: background ?? this.background,
    look: look,
  );

  Map<String, Object> toMap() => {
    'version': 1,
    'skin': skin,
    'hair': hair.name,
    'hair_colour': hairColour,
    'eyes': eyes.name,
    'glasses': glasses.name,
    'head_covering': headCovering.name,
    'clothing': clothing.name,
    'clothing_colour': clothingColour,
    'background': background,
    if (look != null) 'look': look!.name,
  };

  static AvatarConfig fromMap(Map<String, dynamic> m) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    int idx(Object? v, int count, int fallback) =>
        v is int && v >= 0 && v < count ? v : fallback;
    final d = AvatarConfig.fallback;
    return AvatarConfig(
      skin: idx(m['skin'], AvatarPalettes.skinTones, d.skin),
      hair: pick(HairStyle.values, m['hair'], d.hair),
      hairColour: idx(m['hair_colour'], AvatarPalettes.hairColours, 1),
      eyes: pick(EyeShape.values, m['eyes'], d.eyes),
      glasses: pick(Glasses.values, m['glasses'], Glasses.none),
      headCovering: pick(
        HeadCovering.values,
        m['head_covering'],
        HeadCovering.none,
      ),
      clothing: pick(Clothing.values, m['clothing'], d.clothing),
      clothingColour: idx(
        m['clothing_colour'],
        AvatarPalettes.clothingColours,
        d.clothingColour,
      ),
      background: idx(m['background'], AvatarPalettes.backgrounds, 0),
      look: AvatarLook.values.where((v) => v.name == m['look']).firstOrNull,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarConfig && other.toMap().toString() == toMap().toString();

  @override
  int get hashCode => toMap().toString().hashCode;
}

/// What the selfie suggested (on the device). Null fields: no suggestion.
class SelfieSuggestion {
  const SelfieSuggestion({this.skin, this.hairColour});

  final int? skin;
  final int? hairColour;

  AvatarConfig applyTo(AvatarConfig c) =>
      c.copyWith(skin: skin, hairColour: hairColour);
}
