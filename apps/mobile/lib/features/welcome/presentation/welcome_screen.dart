import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/flavor.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../dev/application/preview_mode.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/domain/onboarding_progress.dart';
import '../../../l10n/app_localizations.dart';

/// First screen for new users (spec 5.2 step 1), in the illustrated style
/// (T-UI-02i): the logo, the tagline, a short tour of what Live Well does
/// today, then "Get started" (onboarding) or "I already have an account"
/// (sign-in). Scrolls, so nothing is cut off at large text sizes.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    // No app bar here, so set the status bar icons explicitly; otherwise the
    // splash's light (white) icons carry over onto this light screen.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.washTop, p.washBottom],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight - LwSpacing.screenGutter * 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: LwSpacing.md),
                          Center(
                            child: ClipRRect(
                              borderRadius: LwRadius.lgAll,
                              child: Image.asset(
                                'assets/brand/logo.png',
                                width: LwSize.splashMark * 0.8,
                                semanticLabel: l10n.appTitle,
                              ),
                            ),
                          ),
                          const SizedBox(height: LwSpacing.lg),
                          Text(
                            l10n.welcomeTitle,
                            textAlign: TextAlign.center,
                            style: t.headlineSmall,
                          ),
                          const SizedBox(height: LwSpacing.xs),
                          Text(
                            l10n.homeTagline,
                            textAlign: TextAlign.center,
                            style: t.bodyMedium,
                          ),
                          const SizedBox(height: LwSpacing.lg),
                          const FeatureTour(),
                          const SizedBox(height: LwSpacing.lg),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(onboardingProvider.notifier)
                                  .goTo(OnboardingStep.about);
                              if (context.mounted) {
                                context.push(OnboardingStep.about.path);
                              }
                            },
                            child: Text(l10n.welcomeGetStarted),
                          ),
                          const SizedBox(height: LwSpacing.xs),
                          TextButton(
                            onPressed: () =>
                                context.push(OnboardingStep.signIn.path),
                            child: Text(l10n.welcomeHaveAccount),
                          ),
                          if (isDev)
                            TextButton(
                              onPressed: () {
                                ref.read(previewModeProvider.notifier).enable();
                                context.go('/home');
                              },
                              child: Text(l10n.devPreviewApp),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short tour of what Live Well does today, with the feature art
/// (T-UI-02b ids): one card at a time, arrows and dots, or swipe. Only
/// features that exist are shown (no watch or portal promises yet).
class FeatureTour extends StatefulWidget {
  const FeatureTour({super.key});

  @override
  State<FeatureTour> createState() => _FeatureTourState();
}

class _FeatureTourState extends State<FeatureTour> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final tips = [
      ('step', l.tourStepTitle, l.tourStepBody, 'icon_steps', p.lime),
      (
        'checkin',
        l.tourCheckInTitle,
        l.tourCheckInBody,
        'feature_reflection',
        p.butter,
      ),
      (
        'reminders',
        l.tourRemindersTitle,
        l.tourRemindersBody,
        'feature_notifications',
        p.sky,
      ),
      ('coach', l.tourCoachTitle, l.tourCoachBody, null, p.mint),
    ];
    final (id, title, body, art, tint) = tips[_i];
    final n = tips.length;
    void go(int by) => setState(() => _i = (_i + by + n) % n);
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -100) go(1);
        if (v > 100) go(-1);
      },
      child: Column(
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            liveRegion: true,
            label: l.tourLabel(title, body, _i + 1, n),
            child: AnimatedSwitcher(
              duration: LwMotion.duration(context, LwMotion.medium),
              child: Container(
                key: Key('tour-$id'),
                padding: const EdgeInsets.all(LwSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: LwRadius.lgAll,
                ),
                child: Row(
                  children: [
                    if (art == null)
                      CoachAvatar(expression: AvatarExpression.waving, size: 72)
                    else
                      Illustration(art, width: 72, height: 72),
                    const SizedBox(width: LwSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: t.titleMedium?.copyWith(color: p.onTint),
                          ),
                          const SizedBox(height: LwSpacing.xxs),
                          Text(
                            body,
                            style: t.bodySmall?.copyWith(
                              color: p.onTintSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: LwSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('tour-prev'),
                tooltip: l.tourPrevious,
                onPressed: () => go(-1),
                icon: Icon(Icons.chevron_left, color: p.textPrimary),
              ),
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var k = 0; k < n; k++)
                      Container(
                        width: k == _i ? LwSpacing.md : LwSpacing.xs,
                        height: LwSpacing.xs,
                        margin: const EdgeInsets.symmetric(
                          horizontal: LwSpacing.xxs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: k == _i ? p.primary : p.outlineStrong,
                          borderRadius: LwRadius.pillAll,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('tour-next'),
                tooltip: l.tourNext,
                onPressed: () => go(1),
                icon: Icon(Icons.chevron_right, color: p.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
