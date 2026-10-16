import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Core Live Well components. Built only from tokens; feature screens compose
/// these instead of styling Material widgets themselves.

/// Standard screen: bold left-aligned title (as in the reference screens),
/// 16 dp gutters, scrolling body.
///
/// With an [eyebrow] it is a tab screen and uses the shared tab header
/// ([LwTabHeader]) instead of an app bar, scrolling with the content so it
/// grows with large text.
class LwScreen extends StatelessWidget {
  const LwScreen({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.eyebrow,
    this.icons = const [],
    this.profile,
    this.bottom,
  });

  final String title;
  final List<Widget> children;

  /// Tab screens: buttons and status pills, on their own row below the
  /// title. Other screens: app bar actions.
  final List<Widget> actions;
  final String? eyebrow;

  /// Small icon buttons (search, bell, calendar) next to [profile].
  final List<Widget> icons;

  /// The profile button, always at the top right of a tab header.
  final Widget? profile;

  /// Fixed below the scrolling content (for example a message composer).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    if (eyebrow != null) {
      // No app bar here, so set the status bar icons ourselves: dark icons
      // on the light background, light icons in dark mode.
      final dark = Theme.of(context).brightness == Brightness.dark;
      final p = LwPalette.of(context);
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: DecoratedBox(
            // The illustrated design's soft mint-to-sky wash.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.washTop, p.washBottom],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(LwSpacing.screenGutter),
                      children: [
                        LwTabHeader(
                          eyebrow: eyebrow!,
                          title: title,
                          icons: icons,
                          profile: profile,
                          actions: actions,
                        ),
                        const SizedBox(height: LwSpacing.md),
                        ...children,
                      ],
                    ),
                  ),
                  ?bottom,
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: children,
      ),
    );
  }
}

/// The one header for every tab (T-UI-02): eyebrow and title on the left,
/// [icons] and the [profile] button at the top right of the same row, and
/// any [actions] (buttons, status pills) on their own row below. At large
/// text sizes the title wraps; it never pushes the profile button off its
/// row.
class LwTabHeader extends StatelessWidget {
  const LwTabHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.icons = const [],
    this.profile,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final List<Widget> icons;
  final Widget? profile;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  key: const Key('tab-header-title'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow.toUpperCase(), style: t.labelSmall),
                    Text(title, style: t.headlineSmall),
                  ],
                ),
              ),
            ),
            ...icons,
            ?profile,
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: LwSpacing.xs),
          Wrap(
            key: const Key('tab-header-actions'),
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}

/// Section title inside a screen.
class LwSectionHeader extends StatelessWidget {
  const LwSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: LwSpacing.lg, bottom: LwSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// White card with a soft outline. [eyebrow] is the small label above the
/// title (e.g. "FROM THE LIVE WELL PORTAL", spec 13.4).
class LwCard extends StatelessWidget {
  const LwCard({
    super.key,
    required this.title,
    this.eyebrow,
    this.body,
    this.tag,
    this.onTap,
  });

  final String title;
  final String? eyebrow;
  final String? body;
  final Widget? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(LwSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null || tag != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: LwSpacing.xxs),
                  child: Row(
                    children: [
                      if (eyebrow != null)
                        Expanded(
                          child: Text(
                            eyebrow!.toUpperCase(),
                            style: t.labelSmall,
                          ),
                        )
                      else
                        const Spacer(),
                      ?tag,
                    ],
                  ),
                ),
              Text(title, style: t.titleLarge),
              if (body != null) ...[
                const SizedBox(height: LwSpacing.xxs),
                Text(body!, style: t.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill label, like the reference's "NEW" badge. Also used for
/// "Paid course" on portal cards (spec 13.4).
class LwTag extends StatelessWidget {
  const LwTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LwSpacing.xs,
        vertical: LwSpacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: LwRadius.pillAll,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: p.onPrimary),
      ),
    );
  }
}

/// Friendly placeholder for something not there yet. Calm, never alarming.
class LwEmptyState extends StatelessWidget {
  const LwEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LwSpacing.xl),
      child: Column(
        children: [
          Container(
            width: LwSize.avatarSm * 2,
            height: LwSize.avatarSm * 2,
            decoration: BoxDecoration(
              color: p.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: LwSize.iconMd * 1.5,
              color: p.onPrimaryTint,
            ),
          ),
          const SizedBox(height: LwSpacing.md),
          Text(title, textAlign: TextAlign.center, style: t.titleLarge),
          const SizedBox(height: LwSpacing.xs),
          Text(body, textAlign: TextAlign.center, style: t.bodyMedium),
        ],
      ),
    );
  }
}
