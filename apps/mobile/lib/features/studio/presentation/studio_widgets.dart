import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/avatar/avatar_art.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../avatar/domain/coaches.dart';
import '../../avatar/presentation/coach_avatar.dart'
    show avatarIdleMotionProvider, readyCoachFramesProvider;
import '../../voice/domain/voice.dart';

/// Shared parts of the Avatar & Voice Studio (T-UI-02h), used by the Studio
/// (from Profile) and the onboarding avatar and voice steps (T-ONB-03b/c).

/// The Studio tabs (T-AVT-08b): the coach's look (ready-made coaches, from
/// a photo, built from options, adjusted), its background, and its voice.
enum StudioTab { coaches, photo, build, adjust, background, voice }

/// The ready-made coaches' names in lists ("Brown hair, 30s").
String readyCoachLabel(AppLocalizations l, ReadyCoach c) => switch (c) {
  ReadyCoach.brownHair => l.coachReadyBrownHair,
  ReadyCoach.longBlackHair => l.coachReadyLongBlackHair,
  ReadyCoach.greenHijab => l.coachReadyGreenHijab,
  ReadyCoach.navyTurban => l.coachReadyNavyTurban,
  ReadyCoach.greyGlasses => l.coachReadyGreyGlasses,
  ReadyCoach.shortCurls => l.coachReadyShortCurls,
  ReadyCoach.shortBlackHair => l.coachReadyShortBlackHair,
  ReadyCoach.wheelchair => l.coachReadyWheelchair,
};

String voiceName(AppLocalizations l, LibraryVoice v) => switch (v.id) {
  'lw-warm' => l.voiceNameWarm,
  'lw-bright' => l.voiceNameBright,
  'lw-steady' => l.voiceNameSteady,
  'lw-deep' => l.voiceNameDeep,
  'lw-gentle' => l.voiceNameGentle,
  _ => l.voiceNameClear,
};

/// The Studio's tabs as pills that wrap. [tabs] leaves out Voice in
/// onboarding (the voice step comes next).
class StudioTabs extends StatelessWidget {
  const StudioTabs({
    super.key,
    required this.tab,
    required this.onChanged,
    this.tabs = StudioTab.values,
  });

  final StudioTab tab;
  final ValueChanged<StudioTab> onChanged;
  final List<StudioTab> tabs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String name(StudioTab x) => switch (x) {
      StudioTab.coaches => l.studioTabCoaches,
      StudioTab.photo => l.studioTabPhoto,
      StudioTab.build => l.studioTabBuild,
      StudioTab.adjust => l.studioTabAdjust,
      StudioTab.background => l.studioTabBackground,
      StudioTab.voice => l.studioTabVoice,
    };
    return Wrap(
      spacing: LwSpacing.xs,
      runSpacing: LwSpacing.xs,
      children: [
        for (final x in tabs)
          ChoiceChip(
            key: Key('studio-tab-${x.name}'),
            label: Text(name(x)),
            selected: tab == x,
            onSelected: (_) => onChanged(x),
          ),
      ],
    );
  }
}

/// The large live preview of the coach on its background: it blinks and
/// breathes (T-AVT-08a). Shows the choice being made, before it is saved.
class AvatarStage extends ConsumerWidget {
  const AvatarStage({
    super.key,
    required this.images,
    required this.background,
  });

  final AvatarImages? images;
  final Color background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('studio-stage'),
      padding: const EdgeInsets.all(LwSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: LwRadius.lgAll,
        boxShadow: LwShadow.of(context),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) => AvatarView(
            key: const Key('avatar-preview'),
            images: images,
            background: background,
            expression: AvatarExpression.talking,
            animate: ref.watch(avatarIdleMotionProvider),
            size: box.maxWidth.clamp(96, 200).toDouble(),
            semanticLabel: l.avatarPreviewLabel,
          ),
        ),
      ),
    );
  }
}

/// A ready-made coach's small face (its `thumb` frame), or the initial
/// circle while its art isn't available.
AvatarImages? coachThumb(AvatarImages? set) {
  final thumb = set?[AvatarFrame.thumb];
  return thumb == null ? null : AvatarImages.neutral(thumb);
}

/// The 8 ready-made coaches to pick from (T-AVT-08b): each one's small
/// face and a short description.
class CoachGrid extends ConsumerWidget {
  const CoachGrid({super.key, required this.selected, required this.onPick});

  final ReadyCoach? selected;
  final ValueChanged<ReadyCoach> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        // Four across, or two on small phones and at large text sizes.
        final big = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final columns = box.maxWidth < 360 || big ? 2 : 4;
        final width = (box.maxWidth - LwSpacing.xs * (columns - 1)) / columns;
        return Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final c in ReadyCoach.values)
              SizedBox(
                width: width,
                child: Semantics(
                  key: Key('coach-${c.id}'),
                  button: true,
                  selected: selected == c,
                  label: readyCoachLabel(l, c),
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: LwRadius.lgAll,
                    onTap: () => onPick(c),
                    child: Container(
                      padding: const EdgeInsets.all(LwSpacing.xs),
                      decoration: BoxDecoration(
                        borderRadius: LwRadius.lgAll,
                        border: Border.all(
                          color: selected == c ? p.primary : p.outlineSoft,
                          width: selected == c ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          AvatarView(
                            images: coachThumb(
                              ref.watch(readyCoachFramesProvider(c)).value,
                            ),
                            background: AvatarColours.background.first,
                            expression: AvatarExpression.talking,
                            size: LwSize.minTapTarget * 1.3,
                          ),
                          const SizedBox(height: LwSpacing.xxs),
                          Text(
                            readyCoachLabel(l, c),
                            style: t.labelSmall?.copyWith(
                              color: p.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A tab whose work needs the Media Service, which isn't built yet
/// (T-AVT-08c to 08e): what it will do, and that it is coming.
class StudioComingSoon extends StatelessWidget {
  const StudioComingSoon({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LwCard(title: title, body: body, eyebrow: l.studioSoon);
  }
}

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
    required this.selected,
    required this.onPick,
    this.images,
  });

  /// The background index chosen.
  final int selected;
  final ValueChanged<int> onPick;

  /// The coach being chosen, shown on each colour.
  final AvatarImages? images;

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
                selected: selected == i,
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
                        color: selected == i ? p.primary : p.outlineSoft,
                        width: selected == i ? 3 : 1,
                      ),
                    ),
                    child: AvatarView(
                      images: coachThumb(images),
                      background: AvatarColours.background[i],
                      expression: AvatarExpression.talking,
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
