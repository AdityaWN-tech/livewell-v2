import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/domain/avatar_options.dart';

/// The bundled option lists (copy of content/avatar/options.json, checked by
/// a test).
final avatarOptionsProvider = FutureProvider<AvatarOptions>(
  (ref) async => AvatarOptions.parse(
    await rootBundle.loadString('assets/avatar/options.json', cache: false),
  ),
);

/// What each option category is called on screen.
String categoryName(AppLocalizations l, String id) => switch (id) {
  'age_range' => l.avatarCatAge,
  'face' => l.avatarCatFace,
  'body_type' => l.avatarCatBody,
  'skin' => l.avatarCatSkin,
  'eyes' => l.avatarCatEyes,
  'eyebrows' => l.avatarCatEyebrows,
  'nose' => l.avatarCatNose,
  'lips' => l.avatarCatLips,
  'hairstyle' => l.avatarCatHairstyle,
  'hair_colour' => l.avatarCatHairColour,
  'facial_hair' => l.avatarCatFacialHair,
  'outfit' => l.avatarCatOutfit,
  'outfit_colour' => l.avatarCatOutfitColour,
  'cap' => l.avatarCatCap,
  'head_covering' => l.avatarCatHeadCovering,
  'glasses' => l.avatarCatGlasses,
  'accessories' => l.avatarCatAccessories,
  _ => id,
};

/// One chip row per category. [chosen] holds the selected option per
/// category; with [allowNone] a tap on the selected chip clears it (Adjust:
/// only what changes is sent).
class AvatarOptionsPicker extends StatelessWidget {
  const AvatarOptionsPicker({
    super.key,
    required this.categories,
    required this.chosen,
    required this.onChanged,
    this.allowNone = false,
  });

  final List<AvatarCategory> categories;
  final Map<String, String> chosen;
  final void Function(String category, String? option) onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in categories) ...[
          Semantics(
            header: true,
            child: Text(categoryName(l, c.id), style: t.titleSmall),
          ),
          const SizedBox(height: LwSpacing.xs),
          Wrap(
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xs,
            children: [
              for (final o in c.options)
                ChoiceChip(
                  key: Key('avatar-opt-${c.id}-${o.id}'),
                  label: Text(o.label),
                  selected: chosen[c.id] == o.id,
                  onSelected: (on) =>
                      onChanged(c.id, on ? o.id : (allowNone ? null : o.id)),
                ),
            ],
          ),
          const SizedBox(height: LwSpacing.md),
        ],
      ],
    );
  }
}
