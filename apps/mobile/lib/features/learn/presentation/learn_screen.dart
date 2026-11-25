import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_button.dart';
import '../application/learn_data.dart';
import '../domain/lesson.dart';
import 'breathing_screen.dart';
import 'lesson_reader_screen.dart';
import 'portal_card.dart';

/// The Learn filter chips (T-UI-02f).
enum LearnFilter { all, lessons, audio, programs }

/// Learn tab (T-UI-02f, illustrated design): search, filter chips, "Pick up
/// where you left off", Featured Lessons (2 across), Popular Audio
/// Sessions, and the one portal card when every spec 13.3 check passes
/// ("Programs"). Only approved content (content_items, review_status
/// approved) ever appears.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  static const libraryPath = '/learn/library';
  static const searchPath = '/learn/search';

  /// Featured lessons and audio sessions shown in "All".
  static const preview = 4;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  LearnFilter _filter = LearnFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final offer = ref.watch(portalCardProvider);
    final all = ref.watch(lessonsProvider).value ?? const <Lesson>[];
    final lessons = [
      for (final x in all)
        if (x.kind == LessonKind.lesson) x,
    ];
    final audio = [
      for (final x in all)
        if (x.kind == LessonKind.audio) x,
    ];
    final next = ref.watch(continueLessonProvider);
    final f = _filter;
    final showAll = f == LearnFilter.all;

    final portal = offer == null
        ? null
        : PortalCard(
            key: ValueKey(offer.id),
            offer: offer,
            surface: PortalSurface.learn,
          );
    return LwScreen(
      eyebrow: l.learnEyebrow,
      title: l.tabLearn,
      icons: [
        IconButton(
          key: const Key('learn-search'),
          tooltip: l.learnSearch,
          onPressed: () => context.push(LearnScreen.searchPath),
          icon: Icon(Icons.search, color: p.textPrimary),
        ),
      ],
      profile: const ProfileButton(),
      children: [
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final (x, name) in [
              (LearnFilter.all, l.learnFilterAll),
              (LearnFilter.lessons, l.learnFilterLessons),
              (LearnFilter.audio, l.learnFilterAudio),
              (LearnFilter.programs, l.learnFilterPrograms),
            ])
              ChoiceChip(
                key: Key('learn-filter-${x.name}'),
                label: Text(name),
                selected: f == x,
                onSelected: (_) => setState(() => _filter = x),
              ),
          ],
        ),
        const SizedBox(height: LwSpacing.sm),
        if (showAll && all.isEmpty && portal == null)
          LwEmptyState(
            icon: Icons.menu_book_outlined,
            title: l.learnLessonsEmptyTitle,
            body: l.learnLessonsEmptyBody,
          ),
        if (showAll && next != null) ...[
          LwSectionHeader(l.learnContinueTitle),
          _ContinueCard(next),
        ],
        if (showAll || f == LearnFilter.lessons) ...[
          if (lessons.isNotEmpty || f == LearnFilter.lessons)
            LwSectionHeader(
              l.learnFeatured,
              actionLabel: l.learnSeeAll,
              actionKey: const Key('learn-view-all'),
              onAction: showAll && lessons.length > LearnScreen.preview
                  ? () => context.push(LearnScreen.libraryPath)
                  : null,
            ),
          if (lessons.isEmpty && f == LearnFilter.lessons)
            LwEmptyState(
              icon: Icons.menu_book_outlined,
              title: l.learnLessonsEmptyTitle,
              body: l.learnLessonsEmptyBody,
            )
          else
            LessonGrid(
              showAll ? lessons.take(LearnScreen.preview).toList() : lessons,
            ),
        ],
        if (showAll && portal != null) ...[
          const SizedBox(height: LwSpacing.sectionGap),
          portal,
        ],
        if (showAll || f == LearnFilter.audio) ...[
          LwSectionHeader(l.learnPopularAudio),
          const Padding(
            padding: EdgeInsets.only(bottom: LwSpacing.sm),
            child: BreatheCard(),
          ),
          if (audio.isEmpty && f == LearnFilter.audio)
            LwEmptyState(
              icon: Icons.headphones_outlined,
              title: l.learnPopularAudio,
              body: l.learnAudioEmpty,
            )
          else
            for (final a in showAll ? audio.take(LearnScreen.preview) : audio)
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.sm),
                child: AudioRow(a),
              ),
        ],
        if (f == LearnFilter.programs)
          portal ??
              LwEmptyState(
                icon: Icons.school_outlined,
                title: l.learnProgramsEmptyTitle,
                body: l.learnProgramsEmptyBody,
              ),
      ],
    );
  }
}

/// A lesson opens in the reader, a breathing session in the breathing
/// guide (Step 4e).
Future<void> openLesson(BuildContext context, Lesson lesson) =>
    context.push(LearnItemScreen.pathFor(lesson.id));

/// "Breathe with me": the built-in breathing guide, always there (it needs
/// no download and no reviewed recording).
class BreatheCard extends StatelessWidget {
  const BreatheCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: l.breatheCardLabel,
      child: Material(
        key: const Key('learn-breathe'),
        color: p.sky,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(BreathingScreen.path),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Row(
              children: [
                const Illustration(
                  'lesson_deep_breathing',
                  width: 56,
                  height: 56,
                ),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.breatheTitle,
                        style: t.titleMedium?.copyWith(color: p.onTint),
                      ),
                      Text(
                        l.breatheCardBody,
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LwSpacing.xs),
                const _PlayDot(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _openLabel(AppLocalizations l, Lesson x) => x.readMinutes == null
    ? l.learnOpenLabelNoTime(x.title)
    : l.learnOpenLabel(x.title, x.readMinutes!);

/// "Pick up where you left off": a wide card with art, title, type and
/// length, a progress bar and a play button.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard(this.next);
  final LessonProgress next;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final x = next.lesson;
    final kind = x.kind == LessonKind.audio
        ? l.learnKindAudio
        : l.learnKindLesson;
    final pct = (next.progress * 100).round();
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: l.learnContinueLabel(x.title, kind, x.readMinutes ?? 0, pct),
      child: Material(
        key: const Key('learn-continue'),
        color: p.peach,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLesson(context, x),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.cardPadding),
            child: Row(
              children: [
                Illustration(x.artId, width: 72, height: 72),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        x.title,
                        style: t.titleMedium?.copyWith(color: p.onTint),
                      ),
                      Text(
                        x.readMinutes == null
                            ? kind
                            : '$kind · ${l.learnMinutes(x.readMinutes!)}',
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                      const SizedBox(height: LwSpacing.xs),
                      ClipRRect(
                        borderRadius: LwRadius.pillAll,
                        child: LinearProgressIndicator(
                          value: next.progress,
                          minHeight: LwSpacing.xxs,
                          color: p.accent,
                          backgroundColor: p.surface,
                        ),
                      ),
                      const SizedBox(height: LwSpacing.xxs),
                      Text(
                        l.learnPercentDone(pct),
                        style: t.labelSmall?.copyWith(color: p.onTintSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LwSpacing.xs),
                const _PlayDot(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayDot extends StatelessWidget {
  const _PlayDot();

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return Container(
      width: LwSize.minTapTarget,
      height: LwSize.minTapTarget,
      decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
      child: Icon(Icons.play_arrow_rounded, color: p.onPrimary),
    );
  }
}

/// Featured lessons: illustrated cards, 2 across (1 across on small phones
/// or with large text).
class LessonGrid extends StatelessWidget {
  const LessonGrid(this.lessons, {super.key});
  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = box.maxWidth / scale >= 260 ? 2 : 1;
      final w = (box.maxWidth - LwSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: LwSpacing.sm,
        runSpacing: LwSpacing.sm,
        children: [
          for (final x in lessons) SizedBox(width: w, child: LessonCard(x)),
        ],
      );
    },
  );
}

class LessonCard extends StatelessWidget {
  const LessonCard(this.lesson, {super.key});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final x = lesson;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: _openLabel(l, x),
      child: Card(
        key: Key('lesson-${x.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLesson(context, x),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Illustration(
                  x.artId,
                  fit: BoxFit.cover,
                  placeholderIcon: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(LwSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.title, style: t.titleSmall),
                    if (x.summary != null)
                      Text(
                        x.summary!,
                        style: t.bodySmall,
                        // Cards are one column at large text: show it all
                        // rather than cut it off (T-REL-01).
                        maxLines: large ? null : 3,
                        overflow: large ? null : TextOverflow.ellipsis,
                      ),
                    if (x.readMinutes != null) ...[
                      const SizedBox(height: LwSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: LwSize.iconSm * 0.8,
                            color: LwPalette.of(context).textSecondary,
                          ),
                          const SizedBox(width: LwSpacing.xxs),
                          Flexible(
                            child: Text(
                              l.learnMinutes(x.readMinutes!),
                              style: t.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An audio session row: art, title, length and a play button.
class AudioRow extends StatelessWidget {
  const AudioRow(this.lesson, {super.key});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final x = lesson;
    return Card(
      key: Key('audio-${x.id}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(LwSpacing.sm),
        child: Row(
          children: [
            Illustration(x.artId, width: 56, height: 56),
            const SizedBox(width: LwSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.title, style: t.titleSmall),
                  Text(
                    x.readMinutes == null
                        ? l.learnKindAudio
                        : '${l.learnMinutes(x.readMinutes!)} · '
                              '${l.learnKindAudio}',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              key: Key('audio-${x.id}-play'),
              tooltip: l.learnPlay(x.title),
              style: IconButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                minimumSize: const Size.square(LwSize.minTapTarget),
              ),
              onPressed: () => openLesson(context, x),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
