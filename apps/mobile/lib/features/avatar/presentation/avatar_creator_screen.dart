import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../studio/presentation/studio_widgets.dart' show AvatarStyleSwitch;
import '../data/avatar_repository.dart';
import '../domain/avatar_config.dart';
import 'anime_labels.dart';

/// One category tab: its part id, its name and its options.
typedef _Tab = (String id, String title, Widget Function() options);

/// The cartoon creator (FR-AVT-02): the art style (Illustrated or Anime,
/// T-AVT-06a) and a live preview at the top, then one tab per part: skin
/// tone (10), hair, hair colour, eyes, glasses, head coverings, clothing and
/// background; Anime adds face, eye highlights, eyebrows, nose, lips, blush,
/// bangs, caps, hair accessories and accessories. Every change is kept as a
/// draft so onboarding resumes here.
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

  /// The category tab shown (its part id); null is the style's first.
  String? _tab;

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

    // Shared by both styles.
    final skin = (
      'skin',
      l.avatarSectionSkin,
      () => swatches(
        'skin',
        AvatarColours.skin,
        [
          for (var i = 0; i < AvatarColours.skin.length; i++)
            l.avatarSkinTone(i + 1),
        ],
        _c.skin,
        (i) => _c.copyWith(skin: i),
      ),
    );
    final covering = (
      'head_covering',
      l.avatarSectionHeadCovering,
      () => chips(
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
    );
    final hairColour = (
      'hair_colour',
      l.avatarSectionHairColour,
      () => swatches(
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
    );
    final glasses = (
      'glasses',
      l.avatarSectionGlasses,
      () => chips(
        'glasses',
        [
          (Glasses.none, l.avatarGlassesNone),
          (Glasses.round, l.avatarGlassesRound),
          (Glasses.square, l.avatarGlassesSquare),
        ],
        _c.glasses,
        (v) => _c.copyWith(glasses: v),
      ),
    );
    final clothingColour = (
      'clothing_colour',
      l.avatarSectionClothingColour,
      () => swatches(
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
    );
    final background = (
      'background',
      l.avatarSectionBackground,
      () => swatches(
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
    );

    final List<_Tab> illustrated = [
      skin,
      covering,
      (
        'hair',
        l.avatarSectionHair,
        () => chips(
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
      hairColour,
      (
        'eyes',
        l.avatarSectionEyes,
        () => chips(
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
      glasses,
      (
        'clothing',
        l.avatarSectionClothing,
        () => chips(
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
      clothingColour,
      background,
    ];

    // An anime part covered by the head covering or a cap can't be changed,
    // and says why (the rules in parts_anime.json).
    _Tab anime(AnimeCategory c) => (
      c.id,
      animeSectionLabel(l, c),
      () {
        final hidden = _c.anime.hiddenUnder(_c.headCovering.name).contains(c);
        final covered =
            _c.headCovering == HeadCovering.hijab ||
            _c.headCovering == HeadCovering.turban;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hidden) ...[
              Text(
                covered ? l.avatarHiddenByCovering : l.avatarHiddenByCap,
                key: Key('avatar-anime-${c.id}-hidden'),
                style: t.bodySmall,
              ),
              const SizedBox(height: LwSpacing.xs),
            ],
            Wrap(
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xs,
              children: [
                for (final o in c.options)
                  ChoiceChip(
                    key: Key('avatar-anime-${c.id}-$o'),
                    label: Text(animeOptionLabel(l, c, o)),
                    selected: _c.anime[c] == o,
                    onSelected: hidden
                        ? null
                        : (_) =>
                              _set(_c.copyWith(anime: _c.anime.copyWith(c, o))),
                  ),
              ],
            ),
          ],
        );
      },
    );

    // The order people think in: the face, then hair, then clothes.
    final List<_Tab> animeTabs = [
      anime(AnimeCategory.face),
      skin,
      anime(AnimeCategory.eyes),
      anime(AnimeCategory.eyeHighlight),
      anime(AnimeCategory.eyebrows),
      anime(AnimeCategory.nose),
      anime(AnimeCategory.lips),
      anime(AnimeCategory.blush),
      anime(AnimeCategory.hair),
      anime(AnimeCategory.bangs),
      hairColour,
      anime(AnimeCategory.outfit),
      clothingColour,
      anime(AnimeCategory.cap),
      covering,
      anime(AnimeCategory.hairAccessory),
      anime(AnimeCategory.accessory),
      glasses,
      background,
    ];

    final tabs = _c.style == AvatarStyle.anime ? animeTabs : illustrated;
    final current = tabs.where((x) => x.$1 == _tab).firstOrNull ?? tabs.first;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('avatar-creator'),
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                children: [
                  LwPageTitle(l.avatarCreatorTitle),
                  AvatarStyleSwitch(
                    style: _c.style,
                    onChanged: (style) {
                      _tab = null;
                      _set(_c.withStyle(style));
                    },
                  ),
                  const SizedBox(height: LwSpacing.sm),
                  Center(
                    child: AvatarView(
                      key: const Key('avatar-creator-preview'),
                      config: _c,
                      size: 132,
                      semanticLabel: l.avatarPreviewLabel,
                    ),
                  ),
                  if (_c.style == AvatarStyle.anime) ...[
                    const SizedBox(height: LwSpacing.xs),
                    Text(
                      l.avatarAnimeSoon,
                      key: const Key('avatar-anime-soon'),
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (widget.suggested) ...[
                    const SizedBox(height: LwSpacing.sm),
                    Container(
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
                  ],
                  const SizedBox(height: LwSpacing.md),
                  // The category tabs: one part at a time.
                  Semantics(
                    container: true,
                    label: l.avatarSectionCategories,
                    child: SingleChildScrollView(
                      key: const Key('avatar-tabs'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (id, title, _) in tabs)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: LwSpacing.xs,
                              ),
                              child: ChoiceChip(
                                key: Key('avatar-tab-$id'),
                                label: Text(title),
                                selected: id == current.$1,
                                onSelected: (_) => setState(() => _tab = id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LwSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(current.$2, style: t.titleSmall),
                  ),
                  const SizedBox(height: LwSpacing.xs),
                  current.$3(),
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
