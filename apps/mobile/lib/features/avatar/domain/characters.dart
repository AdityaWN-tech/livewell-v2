import 'avatar_config.dart';

/// The default coach characters in the Studio (T-UI-02h), one per
/// `character_*` id in assets/illustrations/illustrations.json. The person
/// picks one and can customize every part; nothing is guessed (D-28). Until
/// the final art exists they're drawn from these part choices.
/// The wheelchair user (`character_wheelchair`) needs full-body art, so it
/// comes with the art kit (docs/design/asset-brief.md).
class CoachCharacter {
  const CoachCharacter(this.id, this.config);

  /// Matches the illustration id `character_<id>`.
  final String id;
  final AvatarConfig config;

  String get illustrationId => 'character_$id';
}

abstract final class CoachCharacters {
  static const all = [
    CoachCharacter(
      'hoodie',
      AvatarConfig(
        skin: 4,
        hair: HairStyle.short,
        hairColour: 0,
        eyes: EyeShape.smiling,
        glasses: Glasses.none,
        headCovering: HeadCovering.none,
        clothing: Clothing.crew,
        clothingColour: 0,
        background: 0,
      ),
    ),
    CoachCharacter(
      'long_hair',
      AvatarConfig(
        skin: 6,
        hair: HairStyle.long,
        hairColour: 1,
        eyes: EyeShape.almond,
        glasses: Glasses.none,
        headCovering: HeadCovering.none,
        clothing: Clothing.cardigan,
        clothingColour: 2,
        background: 1,
      ),
    ),
    CoachCharacter(
      'glasses',
      AvatarConfig(
        skin: 2,
        hair: HairStyle.short,
        hairColour: 2,
        eyes: EyeShape.round,
        glasses: Glasses.square,
        headCovering: HeadCovering.none,
        clothing: Clothing.collar,
        clothingColour: 3,
        background: 3,
      ),
    ),
    CoachCharacter(
      'curly',
      AvatarConfig(
        skin: 7,
        hair: HairStyle.curly,
        hairColour: 0,
        eyes: EyeShape.round,
        glasses: Glasses.none,
        headCovering: HeadCovering.none,
        clothing: Clothing.crew,
        clothingColour: 5,
        background: 4,
      ),
    ),
    CoachCharacter(
      'hijab',
      AvatarConfig(
        skin: 5,
        hair: HairStyle.none,
        hairColour: 0,
        eyes: EyeShape.almond,
        glasses: Glasses.none,
        headCovering: HeadCovering.hijab,
        clothing: Clothing.cardigan,
        clothingColour: 1,
        background: 5,
      ),
    ),
    CoachCharacter(
      'turban',
      AvatarConfig(
        skin: 6,
        hair: HairStyle.short,
        hairColour: 0,
        eyes: EyeShape.round,
        glasses: Glasses.none,
        headCovering: HeadCovering.turban,
        clothing: Clothing.collar,
        clothingColour: 3,
        background: 2,
      ),
    ),
    CoachCharacter(
      'older',
      AvatarConfig(
        skin: 3,
        hair: HairStyle.wavy,
        hairColour: 5,
        eyes: EyeShape.smiling,
        glasses: Glasses.round,
        headCovering: HeadCovering.none,
        clothing: Clothing.cardigan,
        clothingColour: 2,
        background: 0,
      ),
    ),
  ];

  /// The character [config] was made from, ignoring the background (that is
  /// chosen separately), or -1 after customizing.
  static int indexOf(AvatarConfig config) => all.indexWhere(
    (c) => c.config.copyWith(background: config.background) == _plain(config),
  );

  static AvatarConfig _plain(AvatarConfig c) => AvatarConfig(
    skin: c.skin,
    hair: c.hair,
    hairColour: c.hairColour,
    eyes: c.eyes,
    glasses: c.glasses,
    headCovering: c.headCovering,
    clothing: c.clothing,
    clothingColour: c.clothingColour,
    background: c.background,
  );
}
