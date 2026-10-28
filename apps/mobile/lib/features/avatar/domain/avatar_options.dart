import 'dart:convert';

/// The fixed option lists for "Build my own" and "Adjust" (T-AVT-08,
/// FR-AVT-02): a copy of content/avatar/options.json, the same file the
/// Media Service fills its prompts from. Only these ids are ever sent; the
/// person never types into a prompt.

class AvatarOption {
  const AvatarOption(this.id, this.label);

  final String id;
  final String label;
}

class AvatarCategory {
  const AvatarCategory(this.id, this.options);

  final String id;
  final List<AvatarOption> options;

  bool has(String optionId) => options.any((o) => o.id == optionId);
}

class AvatarOptions {
  const AvatarOptions(this.categories);

  final List<AvatarCategory> categories;

  AvatarCategory? operator [](String id) =>
      categories.where((c) => c.id == id).firstOrNull;

  static AvatarOptions parse(String json) {
    final d = jsonDecode(json) as Map<String, dynamic>;
    return AvatarOptions([
      for (final c in (d['categories'] as List).cast<Map<String, dynamic>>())
        AvatarCategory(c['id'] as String, [
          for (final o in (c['options'] as List).cast<Map<String, dynamic>>())
            AvatarOption(o['id'] as String, o['label'] as String),
        ]),
    ]);
  }

  /// Build my own: every category, in the file's order.
  List<AvatarCategory> get forBuild => categories;

  /// Adjust: what can change on an existing coach without changing who it
  /// is (hair, clothes, hats, glasses, head covering, accessories). Face,
  /// skin, age and build stay.
  List<AvatarCategory> get forAdjust => [
    for (final id in adjustable) ?this[id],
  ];

  static const adjustable = [
    'hairstyle',
    'hair_colour',
    'outfit',
    'outfit_colour',
    'cap',
    'head_covering',
    'glasses',
    'accessories',
  ];

  /// The first option of each category: a complete starting choice.
  Map<String, String> get defaults => {
    for (final c in categories)
      if (c.options.isNotEmpty) c.id: c.options.first.id,
  };

  /// [choices] with anything not in the lists removed.
  Map<String, String> valid(Map<String, String> choices) => {
    for (final e in choices.entries)
      if (this[e.key]?.has(e.value) ?? false) e.key: e.value,
  };
}
