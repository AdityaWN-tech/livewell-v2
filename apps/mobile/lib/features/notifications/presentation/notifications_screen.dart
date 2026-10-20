import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../starter_plan/domain/touchpoints.dart';

/// The reminder times, from the plan (T-ONB-03e).
final reminderTimesProvider = FutureProvider<TouchpointTimes>((ref) async {
  try {
    return await ref.watch(planRepositoryProvider).loadTimes();
  } catch (_) {
    return const TouchpointTimes();
  }
});

/// "Today's reminders" (T-UI-02i), from the bell on Home: the 3 daily
/// moments with their times, which are on, and the quiet hours. Generic
/// names only: nothing personal or health-related (AGENTS.md).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const path = '/notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final ml = MaterialLocalizations.of(context);
    String fmt(ClockTime c) =>
        ml.formatTimeOfDay(TimeOfDay(hour: c.hour, minute: c.minute));
    final signedIn = ref.watch(signedInUidProvider) != null;
    final settings =
        ref.watch(currentProfileProvider).value?.settings ??
        const <String, dynamic>{};
    final enabled = enabledFromMap(
      settings[ProfileSettings.notificationCategories] as Map<String, dynamic>?,
    );
    final quiet = QuietHours.fromMap(
      settings[ProfileSettings.quietHours] as Map<String, dynamic>?,
    );
    final times =
        ref.watch(reminderTimesProvider).value ?? const TouchpointTimes();
    final moments = [
      (TouchpointKind.greeting, l.planMorning, 'icon_mood', p.butter),
      (TouchpointKind.nudge, l.planMidday, 'icon_steps', p.mint),
      (TouchpointKind.reflection, l.planEvening, 'icon_reflection', p.lavender),
    ];
    return Scaffold(
      // Back arrow only: the title is in the page so it wraps.
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            LwPageTitle(l.notificationsTitle),
            Text(l.notificationsBody, style: t.bodyMedium),
            const SizedBox(height: LwSpacing.md),
            if (!signedIn)
              Text(l.notificationsSignedOut, style: t.bodyLarge)
            else ...[
              for (final (k, name, art, tint) in moments) ...[
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: l.notificationsRowLabel(
                    name,
                    fmt(times.of(k)),
                    enabled.contains(k)
                        ? l.notificationsOn
                        : l.notificationsOff,
                  ),
                  child: Container(
                    key: Key('notification-${k.name}'),
                    padding: const EdgeInsets.all(LwSpacing.sm),
                    decoration: BoxDecoration(
                      color: enabled.contains(k) ? tint : p.surfaceMuted,
                      borderRadius: LwRadius.lgAll,
                    ),
                    child: Row(
                      children: [
                        Illustration(art, width: 44, height: 44),
                        const SizedBox(width: LwSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: t.titleSmall?.copyWith(color: p.onTint),
                              ),
                              Text(
                                fmt(times.of(k)),
                                style: t.bodySmall?.copyWith(
                                  color: p.onTintSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          enabled.contains(k)
                              ? l.notificationsOn
                              : l.notificationsOff,
                          key: Key('notification-${k.name}-state'),
                          style: t.labelMedium?.copyWith(color: p.onTint),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LwSpacing.xs),
              ],
              const SizedBox(height: LwSpacing.xs),
              Row(
                children: [
                  Icon(Icons.bedtime_outlined, color: p.textSecondary),
                  const SizedBox(width: LwSpacing.xs),
                  Expanded(
                    child: Text(
                      l.notificationsQuiet(fmt(quiet.start), fmt(quiet.end)),
                      key: const Key('notifications-quiet'),
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LwSpacing.md),
              OutlinedButton(
                key: const Key('notifications-edit'),
                onPressed: () => context.push('/profile'),
                child: Text(l.notificationsEdit),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
