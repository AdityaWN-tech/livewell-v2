import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/domain/avatar_config.dart';
import '../../avatar/domain/characters.dart';
import '../../voice/domain/voice.dart';

/// Shared parts of the Avatar & Voice Studio (T-UI-02h), used by the Studio
/// (from Profile) and the onboarding avatar and voice steps (T-ONB-03b/c).

/// The Studio tabs.
enum StudioTab { avatar, voice, background }

String characterName(AppLocalizations l, String id) => switch (id) {
  'hoodie' => l.avatarCharacterHoodie,
  'long_hair' => l.avatarCharacterLongHair,
  'glasses' => l.avatarCharacterGlasses,
  'curly' => l.avatarCharacterCurly,
  'hijab' => l.avatarCharacterHijab,
  'turban' => l.avatarCharacterTurban,
  _ => l.avatarCharacterOlder,
};

String voiceName(AppLocalizations l, LibraryVoice v) => switch (v.id) {
  'lw-warm' => l.voiceNameWarm,
  'lw-bright' => l.voiceNameBright,
  'lw-steady' => l.voiceNameSteady,
  'lw-deep' => l.voiceNameDeep,
  'lw-gentle' => l.voiceNameGentle,
  _ => l.voiceNameClear,
};

/// Avatar / Voice / Background as pill tabs.
class StudioTabs extends StatelessWidget {
  const StudioTabs({super.key, required this.tab, required this.onChanged});

  final StudioTab tab;
  final ValueChanged<StudioTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xs,
      children: [
        for (final (x, name) in [
          (StudioTab.avatar, l.studioTabAvatar),
          (StudioTab.voice, l.studioTabVoice),
          (StudioTab.background, l.studioTabBackground),
        ])
          ChoiceChip(
            key: Key('studio-tab-${x.name}'),
            label: Text(name),
            selected: tab == x,
            onSelected: (_) => onChanged(x),
          ),
      ],
    );
  }
}

/// Anime or Illustrated (T-AVT-06a), at the top of the avatar maker. The
/// preview under it changes as soon as a style is picked.
class AvatarStyleSwitch extends StatelessWidget {
  const AvatarStyleSwitch({
    super.key,
    required this.style,
    required this.onChanged,
  });

  final AvatarStyle style;
  final ValueChanged<AvatarStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l.avatarStyle,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<AvatarStyle>(
          key: const Key('avatar-style'),
          segments: [
            ButtonSegment(
              value: AvatarStyle.illustrated,
              label: Text(
                l.avatarStyleIllustrated,
                key: const Key('avatar-style-illustrated'),
              ),
            ),
            ButtonSegment(
              value: AvatarStyle.anime,
              label: Text(
                l.avatarStyleAnime,
                key: const Key('avatar-style-anime'),
              ),
            ),
          ],
          selected: {style},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ),
    );
  }
}

/// The large preview of the coach on its background, with left / right
/// arrows and page dots to move between the default characters.
class AvatarStage extends StatelessWidget {
  const AvatarStage({
    super.key,
    required this.config,
    required this.index,
    required this.onStep,
  });

  final AvatarConfig config;

  /// The character shown, or -1 for a customized look.
  final int index;

  /// -1 previous, +1 next. Null: no characters to step through (the
  /// characters are Illustrated, so not for an Anime look).
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final count = CoachCharacters.all.length;
    final step = onStep;
    final name = config.style == AvatarStyle.anime
        ? l.avatarAnimeName
        : index < 0
        ? l.studioCustom
        : characterName(l, CoachCharacters.all[index].id);
    return Container(
      key: const Key('studio-stage'),
      padding: const EdgeInsets.all(LwSpacing.md),
      decoration: BoxDecoration(
        color: AvatarColours.background[config.background],
        borderRadius: LwRadius.lgAll,
        boxShadow: LwShadow.of(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (step != null)
                _Arrow(
                  key: const Key('studio-prev'),
                  icon: Icons.chevron_left,
                  tooltip: l.studioPrevious,
                  onTap: () => step(-1),
                ),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, box) => AvatarView(
                      key: const Key('avatar-preview'),
                      config: config,
                      expression: AvatarExpression.waving,
                      size: box.maxWidth.clamp(96, 180).toDouble(),
                      semanticLabel: l.avatarPreviewLabel,
                    ),
                  ),
                ),
              ),
              if (step != null)
                _Arrow(
                  key: const Key('studio-next'),
                  icon: Icons.chevron_right,
                  tooltip: l.studioNext,
                  onTap: () => step(1),
                ),
            ],
          ),
          const SizedBox(height: LwSpacing.xs),
          // The art colours are light pastels in both modes, so the name and
          // dots always use the light palette's dark ink.
          Text(
            name,
            key: const Key('studio-name'),
            style: t.titleSmall?.copyWith(color: LwPalette.light.textPrimary),
          ),
          if (step != null) ...[
            const SizedBox(height: LwSpacing.xs),
            Semantics(
              container: true,
              label: index < 0
                  ? l.studioCustom
                  : l.studioPage(index + 1, count),
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    Container(
                      width: i == index ? LwSpacing.md : LwSpacing.xs,
                      height: LwSpacing.xs,
                      margin: const EdgeInsets.symmetric(
                        horizontal: LwSpacing.xxs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: i == index
                            ? LwPalette.light.primary
                            : LwPalette.light.outlineStrong,
                        borderRadius: LwRadius.pillAll,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: LwPalette.light.surface,
      foregroundColor: LwPalette.light.textPrimary,
      minimumSize: const Size.square(LwSize.minTapTarget),
    ),
    onPressed: onTap,
    icon: Icon(icon),
  );
}

/// The row of default characters to pick from.
class CharacterStrip extends StatelessWidget {
  const CharacterStrip({
    super.key,
    required this.selected,
    required this.onPick,
    this.background,
  });

  /// Index in [CoachCharacters.all], or -1.
  final int selected;
  final ValueChanged<int> onPick;

  /// Shows every character on this background (the person's choice).
  final int? background;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xs,
      children: [
        for (final (i, c) in CoachCharacters.all.indexed)
          Semantics(
            key: Key('avatar-character-${c.id}'),
            button: true,
            selected: selected == i,
            container: true,
            excludeSemantics: true,
            label: l.studioCharacterLabel(
              characterName(l, c.id),
              selected == i ? l.studioVoiceSelected : l.studioVoiceNotSelected,
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: LwRadius.mdAll,
              ),
              onTap: () => onPick(i),
              child: Container(
                padding: const EdgeInsets.all(LwSpacing.xxs),
                decoration: BoxDecoration(
                  borderRadius: LwRadius.mdAll,
                  border: Border.all(
                    color: selected == i ? p.primary : p.outlineSoft,
                    width: selected == i ? 3 : 1,
                  ),
                ),
                child: AvatarView(
                  config: background == null
                      ? c.config
                      : c.config.copyWith(background: background),
                  size: LwSize.minTapTarget * 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One row of "Choose Your Voice": icon, name, detail, a status pill and a
/// radio button.
class VoiceRow extends StatelessWidget {
  const VoiceRow({
    super.key,
    required this.icon,
    required this.name,
    required this.detail,
    this.status,
    this.selected,
    this.onTap,
    this.onPreview,
    this.previewTooltip,
    this.previewKey,
  });

  final IconData icon;
  final String name;
  final String detail;

  /// "Active", "Coming soon", "AI voice"...
  final String? status;

  /// Null: no radio (not choosable).
  final bool? selected;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;
  final String? previewTooltip;
  final Key? previewKey;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final enabled = onTap != null;
    final state = selected == null
        ? (status ?? '')
        : selected!
        ? l.studioVoiceSelected
        : l.studioVoiceNotSelected;
    return Semantics(
      container: true,
      button: enabled,
      selected: selected ?? false,
      label: l.studioVoiceRowLabel(name, detail, state),
      child: Material(
        color: selected == true ? p.mint : p.surface,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.inputHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LwSpacing.sm,
                vertical: LwSpacing.xs,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: LwSize.minTapTarget * 0.8,
                      height: LwSize.minTapTarget * 0.8,
                      decoration: BoxDecoration(
                        color: enabled ? p.lavender : p.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: LwSize.iconSm,
                        color: enabled ? p.primaryDark : p.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: LwSpacing.sm),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: t.titleSmall?.copyWith(
                              color: selected == true
                                  ? p.onTint
                                  : p.textPrimary,
                            ),
                          ),
                          Text(
                            detail,
                            style: t.bodySmall?.copyWith(
                              color: selected == true
                                  ? p.onTintSecondary
                                  : p.textSecondary,
                            ),
                          ),
                          if (status != null) ...[
                            const SizedBox(height: LwSpacing.xxs),
                            _Pill(status!, strong: selected == true),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (onPreview != null)
                    IconButton(
                      key: previewKey,
                      tooltip: previewTooltip,
                      onPressed: onPreview,
                      icon: Icon(
                        Icons.play_circle_outline,
                        color: p.primaryDark,
                      ),
                    ),
                  if (selected != null)
                    ExcludeSemantics(
                      child: Icon(
                        selected!
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected! ? p.primary : p.outlineStrong,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.strong});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LwSpacing.xs,
        vertical: LwSpacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: strong ? p.primary : p.surfaceMuted,
        borderRadius: LwRadius.pillAll,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: strong ? p.onPrimary : p.textPrimary),
      ),
    );
  }
}

/// "Choose Your Voice": the library voices, then the gated rows.
/// - "My Voice (Cloned)" and "Add a Loved One's Voice" are "Coming soon"
///   while the clone flag is off (FR-VOC-02, spec 7.4).
/// - "Dr. Gokula (Licensed)" shows only with its flag (licence signed),
///   always labelled as an AI voice.
/// - The voice-consent banner shows only when a cloned voice with valid
///   consent exists.
class VoiceChoices extends StatelessWidget {
  const VoiceChoices({
    super.key,
    required this.selectedId,
    required this.onSelect,
    required this.onPreview,
    required this.flags,
    required this.hasClonedVoiceConsent,
    this.onOwnVoice,
  });

  final String selectedId;
  final ValueChanged<LibraryVoice> onSelect;
  final ValueChanged<LibraryVoice> onPreview;
  final FeatureFlags flags;
  final bool hasClonedVoiceConsent;

  /// Opens the explanation when the clone flag is on.
  final VoidCallback? onOwnVoice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final clone = flags.voiceClone;
    final rows = <Widget>[
      for (final v in VoiceLibrary.all)
        VoiceRow(
          key: Key('voice-${v.id}'),
          icon: Icons.graphic_eq,
          name: voiceName(l, v),
          detail:
              '${v.accent == VoiceAccent.us ? l.voiceAccentUs : l.voiceAccentUk}'
              ' · ${l.voiceAiLabel}',
          status: v.id == selectedId ? l.studioVoiceActive : null,
          selected: v.id == selectedId,
          onTap: () => onSelect(v),
          onPreview: () => onPreview(v),
          previewTooltip: l.voicePreview(voiceName(l, v)),
          previewKey: Key('voice-play-${v.id}'),
        ),
      if (flags.drGokulaVoice)
        VoiceRow(
          key: const Key('voice-dr-gokula'),
          icon: Icons.verified_outlined,
          name: l.studioDrGokula,
          detail: l.voiceAiLabel,
          status: l.studioVoiceSoon,
        ),
      VoiceRow(
        key: const Key('voice-own'),
        icon: Icons.record_voice_over_outlined,
        name: l.studioMyVoice,
        detail: l.voiceAiLabel,
        status: clone ? null : l.studioVoiceSoon,
        onTap: clone ? onOwnVoice : null,
      ),
      VoiceRow(
        key: const Key('voice-loved-one'),
        icon: Icons.add_circle_outline,
        name: l.studioLovedOne,
        detail: l.voiceAiLabel,
        status: clone ? null : l.studioVoiceSoon,
        onTap: clone ? onOwnVoice : null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.studioChooseVoice, style: t.titleMedium),
        ),
        const SizedBox(height: LwSpacing.xs),
        for (final r in rows) ...[r, const SizedBox(height: LwSpacing.xs)],
        if (hasClonedVoiceConsent)
          Container(
            key: const Key('voice-consent-banner'),
            padding: const EdgeInsets.all(LwSpacing.sm),
            decoration: BoxDecoration(
              color: p.mint,
              borderRadius: LwRadius.lgAll,
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: p.primaryDark),
                const SizedBox(width: LwSpacing.xs),
                Expanded(
                  child: Text(
                    l.studioConsentBanner,
                    style: t.bodySmall?.copyWith(color: p.onTint),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The avatar background colours, and the scene backgrounds that come with
/// the art kit (one unlocked by a streak, FR-GAM-03).
class BackgroundChoices extends StatelessWidget {
  const BackgroundChoices({
    super.key,
    required this.config,
    required this.onPick,
  });

  final AvatarConfig config;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final names = [
      l.avatarBgSage,
      l.avatarBgPeach,
      l.avatarBgCream,
      l.avatarBgSky,
      l.avatarBgLavender,
      l.avatarBgSunshine,
    ];
    // Scene art comes with the art kit (studio_bg_* in the asset brief).
    final scenes = [
      ('garden', l.studioSceneGarden, l.studioSceneSoon),
      ('sunrise', l.studioSceneSunrise, l.studioSceneSoon),
      ('room', l.studioSceneRoom, l.studioSceneSoon),
      ('beach', l.studioSceneBeach, l.studioLocked(7)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l.studioColours, style: t.titleMedium),
        ),
        const SizedBox(height: LwSpacing.xs),
        Wrap(
          spacing: LwSpacing.sm,
          runSpacing: LwSpacing.sm,
          children: [
            for (var i = 0; i < AvatarColours.background.length; i++)
              Semantics(
                key: Key('studio-bg-$i'),
                button: true,
                selected: config.background == i,
                container: true,
                excludeSemantics: true,
                label: names[i],
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: LwRadius.lgAll,
                  ),
                  onTap: () => onPick(i),
                  child: Container(
                    padding: const EdgeInsets.all(LwSpacing.xxs),
                    decoration: BoxDecoration(
                      borderRadius: LwRadius.lgAll,
                      border: Border.all(
                        color: config.background == i
                            ? p.primary
                            : p.outlineSoft,
                        width: config.background == i ? 3 : 1,
                      ),
                    ),
                    child: AvatarView(
                      config: config.copyWith(background: i),
                      size: LwSize.minTapTarget * 1.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.lg),
        Semantics(
          header: true,
          child: Text(l.studioScenes, style: t.titleMedium),
        ),
        const SizedBox(height: LwSpacing.xs),
        for (final (id, name, note) in scenes) ...[
          VoiceRow(
            key: Key('studio-scene-$id'),
            icon: Icons.landscape_outlined,
            name: name,
            detail: note,
          ),
          const SizedBox(height: LwSpacing.xs),
        ],
      ],
    );
  }
}
