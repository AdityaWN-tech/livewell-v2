import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/avatar_repository.dart';
import '../domain/avatar_config.dart';

/// The cartoon creator (FR-AVT-02): skin tone (10), hair, hair colour, eyes,
/// glasses, head coverings, clothing and background, with a live preview.
/// Every change is kept as a draft so onboarding resumes here.
class AvatarCreatorScreen extends ConsumerStatefulWidget {
  const AvatarCreatorScreen({
    super.key,
    required this.initial,
    this.suggested = false,
  });

  final AvatarConfig initial;

  /// Opened from a selfie: say what was suggested and that it's deleted.
  final bool suggested;

  @override
  ConsumerState<AvatarCreatorScreen> createState() =>
      _AvatarCreatorScreenState();
}

class _AvatarCreatorScreenState extends ConsumerState<AvatarCreatorScreen> {
  late AvatarConfig _c = widget.initial;

  void _set(AvatarConfig next) {
    setState(() => _c = next);
    ref
        .read(avatarDraftStoreProvider)
        .save(AvatarDraft(config: next, inCreator: true));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;

    Widget section(String title, Widget body) => Padding(
      padding: const EdgeInsets.only(bottom: LwSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: t.titleSmall)),
          const SizedBox(height: LwSpacing.xs),
          body,
        ],
      ),
    );

    Widget chips<T>(
      String id,
      List<(T, String)> options,
      T selected,
      AvatarConfig Function(T) apply,
    ) => Wrap(
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xs,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            key: Key('avatar-$id-$label'),
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => _set(apply(value)),
          ),
      ],
    );

    Widget swatches(
      String id,
      List<Color> colours,
      List<String> labels,
      int selected,
      AvatarConfig Function(int) apply,
    ) => Wrap(
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xs,
      children: [
        for (var i = 0; i < colours.length; i++)
          Semantics(
            key: Key('avatar-$id-$i'),
            button: true,
            selected: selected == i,
            label: labels[i],
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _set(apply(i)),
              child: Container(
                width: LwSize.minTapTarget,
                height: LwSize.minTapTarget,
                padding: const EdgeInsets.all(LwSpacing.xxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == i ? p.primary : p.outlineSoft,
                    width: selected == i ? 3 : 1,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colours[i],
                    shape: BoxShape.circle,
                    border: Border.all(color: p.outlineSoft),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: LwSpacing.sm),
              child: AvatarView(
                key: const Key('avatar-creator-preview'),
                config: _c,
                size: 132,
                semanticLabel: l.avatarPreviewLabel,
              ),
            ),
            if (widget.suggested)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LwSpacing.screenGutter,
                ),
                child: Container(
                  key: const Key('avatar-suggested'),
                  padding: const EdgeInsets.all(LwSpacing.sm),
                  decoration: BoxDecoration(
                    color: p.primaryTint,
                    borderRadius: LwRadius.mdAll,
                  ),
                  child: Text(
                    l.avatarSuggested,
                    style: t.bodySmall?.copyWith(color: p.onPrimaryTint),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                children: [
                  LwPageTitle(l.avatarCreatorTitle),
                  section(
                    l.avatarSectionSkin,
                    swatches(
                      'skin',
                      AvatarColours.skin,
                      [
                        for (var i = 0; i < AvatarColours.skin.length; i++)
                          l.avatarSkinTone(i + 1),
                      ],
                      _c.skin,
                      (i) => _c.copyWith(skin: i),
                    ),
                  ),
                  section(
                    l.avatarSectionHeadCovering,
                    chips(
                      'covering',
                      [
                        (HeadCovering.none, l.avatarCoveringNone),
                        (HeadCovering.hijab, l.avatarCoveringHijab),
                        (HeadCovering.turban, l.avatarCoveringTurban),
                        (HeadCovering.kippah, l.avatarCoveringKippah),
                      ],
                      _c.headCovering,
                      (v) => _c.copyWith(headCovering: v),
                    ),
                  ),
                  section(
                    l.avatarSectionHair,
                    chips(
                      'hair',
                      [
                        (HairStyle.none, l.avatarHairNone),
                        (HairStyle.short, l.avatarHairShort),
                        (HairStyle.long, l.avatarHairLong),
                        (HairStyle.curly, l.avatarHairCurly),
                        (HairStyle.coily, l.avatarHairCoily),
                        (HairStyle.wavy, l.avatarHairWavy),
                        (HairStyle.bun, l.avatarHairBun),
                        (HairStyle.buzz, l.avatarHairBuzz),
                      ],
                      _c.hair,
                      (v) => _c.copyWith(hair: v),
                    ),
                  ),
                  section(
                    l.avatarSectionHairColour,
                    swatches(
                      'hair-colour',
                      AvatarColours.hair,
                      [
                        l.avatarHairColourBlack,
                        l.avatarHairColourDarkBrown,
                        l.avatarHairColourBrown,
                        l.avatarHairColourAuburn,
                        l.avatarHairColourBlonde,
                        l.avatarHairColourGrey,
                        l.avatarHairColourWhite,
                      ],
                      _c.hairColour,
                      (i) => _c.copyWith(hairColour: i),
                    ),
                  ),
                  section(
                    l.avatarSectionEyes,
                    chips(
                      'eyes',
                      [
                        (EyeShape.round, l.avatarEyesRound),
                        (EyeShape.almond, l.avatarEyesAlmond),
                        (EyeShape.smiling, l.avatarEyesSmiling),
                      ],
                      _c.eyes,
                      (v) => _c.copyWith(eyes: v),
                    ),
                  ),
                  section(
                    l.avatarSectionGlasses,
                    chips(
                      'glasses',
                      [
                        (Glasses.none, l.avatarGlassesNone),
                        (Glasses.round, l.avatarGlassesRound),
                        (Glasses.square, l.avatarGlassesSquare),
                      ],
                      _c.glasses,
                      (v) => _c.copyWith(glasses: v),
                    ),
                  ),
                  section(
                    l.avatarSectionClothing,
                    chips(
                      'clothing',
                      [
                        (Clothing.crew, l.avatarClothingCrew),
                        (Clothing.collar, l.avatarClothingCollar),
                        (Clothing.cardigan, l.avatarClothingCardigan),
                      ],
                      _c.clothing,
                      (v) => _c.copyWith(clothing: v),
                    ),
                  ),
                  section(
                    l.avatarSectionClothingColour,
                    swatches(
                      'clothing-colour',
                      AvatarColours.clothing,
                      [
                        l.avatarClothForest,
                        l.avatarClothTerracotta,
                        l.avatarClothSage,
                        l.avatarClothNavy,
                        l.avatarClothMustard,
                        l.avatarClothPlum,
                      ],
                      _c.clothingColour,
                      (i) => _c.copyWith(clothingColour: i),
                    ),
                  ),
                  section(
                    l.avatarSectionBackground,
                    swatches(
                      'background',
                      AvatarColours.background,
                      [
                        l.avatarBgSage,
                        l.avatarBgPeach,
                        l.avatarBgCream,
                        l.avatarBgSky,
                        l.avatarBgLavender,
                        l.avatarBgSunshine,
                      ],
                      _c.background,
                      (i) => _c.copyWith(background: i),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LwSpacing.screenGutter),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('avatar-creator-use'),
                  onPressed: () => Navigator.of(context).pop(_c),
                  child: Text(l.avatarUseThis),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
