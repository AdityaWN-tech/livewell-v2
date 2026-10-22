/// The Anime art style's own parts (T-AVT-06a), one category per entry in
/// assets/avatar/parts_anime.json (a test keeps them in step). Skin, hair
/// colour, outfit colour, glasses, head covering and background are shared
/// with the Illustrated style and live on [AvatarConfig] itself.
library;

/// The avatar's art style. Both use the same layer system.
enum AvatarStyle { illustrated, anime }

/// An anime-only category and its options, in the manifest's order. The
/// first option is the default.
enum AnimeCategory {
  face('face', ['oval', 'round', 'heart', 'square', 'long', 'soft']),
  eyes('eyes', ['round', 'almond', 'droopy', 'upturned', 'wide', 'gentle']),
  eyeHighlight('eye_highlight', ['sparkle', 'none', 'dot', 'double', 'star']),
  eyebrows('eyebrows', ['soft', 'straight', 'arched', 'thick', 'thin']),
  nose('nose', ['dot', 'small', 'button', 'line']),
  lips('lips', ['smile', 'soft', 'wide', 'small', 'full']),
  blush('blush', ['light', 'none', 'round', 'lines']),
  hair('hair', [
    'short',
    'bob',
    'long',
    'ponytail',
    'twin_tails',
    'bun',
    'curly',
    'coily',
    'braids',
    'wavy',
    'buzz',
    'none',
  ]),
  bangs('bangs', ['side', 'none', 'straight', 'curtain', 'wispy']),
  outfit('outfit', ['tee', 'hoodie', 'cardigan', 'kurta', 'blazer', 'sweater']),
  cap('cap', ['none', 'beanie', 'baseball', 'bucket', 'beret', 'sun_hat']),
  hairAccessory('hair_accessory', [
    'none',
    'clip',
    'ribbon',
    'flower',
    'headband',
  ]),
  accessory('accessory', [
    'none',
    'earrings',
    'hearing_aid',
    'necklace',
    'scarf',
  ]);

  const AnimeCategory(this.id, this.options);

  /// The manifest's category id.
  final String id;
  final List<String> options;

  String get fallback => options.first;
}

/// The person's anime part choices. Unknown or missing values fall back to
/// each category's default, so an old or edited document still loads.
class AnimeParts {
  const AnimeParts._(this._parts);

  /// A friendly starting face; the person changes everything.
  static const defaults = AnimeParts._({});

  final Map<AnimeCategory, String> _parts;

  String operator [](AnimeCategory c) => _parts[c] ?? c.fallback;

  AnimeParts copyWith(AnimeCategory c, String option) {
    assert(c.options.contains(option), '$option is not a ${c.id}');
    return AnimeParts._({..._parts, c: option});
  }

  Map<String, String> toMap() => {
    for (final c in AnimeCategory.values) c.id: this[c],
  };

  static AnimeParts fromMap(Object? m) {
    if (m is! Map) return defaults;
    return AnimeParts._({
      for (final c in AnimeCategory.values)
        if (c.options.contains(m[c.id])) c: m[c.id] as String,
    });
  }

  /// Layers hidden by the compatibility rules in parts_anime.json: a hijab
  /// or turban covers the hair, bangs, hair accessory and cap; a cap
  /// covers the bangs and hair accessory.
  Set<AnimeCategory> hiddenUnder(String headCovering) => {
    if (headCovering == 'hijab' || headCovering == 'turban') ...{
      AnimeCategory.hair,
      AnimeCategory.bangs,
      AnimeCategory.hairAccessory,
      AnimeCategory.cap,
    },
    if (this[AnimeCategory.cap] != 'none') ...{
      AnimeCategory.bangs,
      AnimeCategory.hairAccessory,
    },
  };

  @override
  bool operator ==(Object other) =>
      other is AnimeParts && other.toMap().toString() == toMap().toString();

  @override
  int get hashCode => toMap().toString().hashCode;
}
