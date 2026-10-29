import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../application/track_data.dart';
import '../data/health_source.dart';

/// "Connect Health" on Track (Step 4f, D-59): explains what is read (steps
/// and sleep, kept on the phone), records the health data consent
/// (FR-ONB-03) before any system prompt, then shows Apple Health's or
/// Health Connect's own permission screen. Without Health Connect it offers
/// to install it; a phone that can't connect is told so. Disconnect by
/// turning the consent off in Settings > Consents.
Future<void> showConnectHealth(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const SafeArea(child: _ConnectHealthSheet()),
    );

enum _Stage { checking, ready, needsInstall, unavailable, working, denied }

class _ConnectHealthSheet extends ConsumerStatefulWidget {
  const _ConnectHealthSheet();

  @override
  ConsumerState<_ConnectHealthSheet> createState() => _State();
}

class _State extends ConsumerState<_ConnectHealthSheet> {
  _Stage _stage = _Stage.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final a = await ref.read(healthSourceProvider).availability();
    if (!mounted) return;
    setState(
      () => _stage = switch (a) {
        HealthAvailability.available => _Stage.ready,
        HealthAvailability.needsInstall => _Stage.needsInstall,
        HealthAvailability.unavailable => _Stage.unavailable,
      },
    );
  }

  Future<void> _connect() async {
    setState(() => _stage = _Stage.working);
    final consents = ref.read(consentRepositoryProvider);
    final source = ref.read(healthSourceProvider);
    // The in-app consent first, then the system's permission screen.
    await consents.record(ConsentType.healthData, granted: true);
    bool allowed;
    try {
      allowed = await source.requestAccess();
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    if (!allowed) {
      // Keep it off, so Track doesn't look connected without access.
      await consents.record(ConsentType.healthData, granted: false);
      if (mounted) setState(() => _stage = _Stage.denied);
      return;
    }
    ref.invalidate(healthWeekProvider);
    Navigator.of(context).pop();
  }

  Future<void> _install() async {
    await ref.read(healthSourceProvider).install();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final app = ios ? l.healthAppleHealth : l.healthHealthConnect;
    final (String body, List<Widget> actions) = switch (_stage) {
      _Stage.checking || _Stage.working => (
        l.healthConnectBody(app),
        const [Center(child: CircularProgressIndicator())],
      ),
      _Stage.ready => (
        l.healthConnectBody(app),
        [
          FilledButton(
            key: const Key('health-connect'),
            onPressed: _connect,
            child: Text(l.healthConnectButton(app)),
          ),
          TextButton(
            key: const Key('health-not-now'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.healthNotNow),
          ),
        ],
      ),
      _Stage.needsInstall => (
        l.healthNeedsInstallBody,
        [
          FilledButton(
            key: const Key('health-install'),
            onPressed: _install,
            child: Text(l.healthInstallButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.healthNotNow),
          ),
        ],
      ),
      _Stage.unavailable => (
        l.healthUnavailableBody,
        [
          FilledButton(
            key: const Key('health-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.healthClose),
          ),
        ],
      ),
      _Stage.denied => (
        l.healthDeniedBody(app),
        [
          FilledButton(
            key: const Key('health-retry'),
            onPressed: _connect,
            child: Text(l.healthTryAgain),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.healthNotNow),
          ),
        ],
      ),
    };
    return SingleChildScrollView(
      key: const Key('health-sheet'),
      padding: const EdgeInsets.fromLTRB(
        LwSpacing.lg,
        0,
        LwSpacing.lg,
        LwSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.healthConnectTitle(app), style: t.titleLarge),
          const SizedBox(height: LwSpacing.xs),
          Text(body, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.lg),
          ...actions,
        ],
      ),
    );
  }
}
