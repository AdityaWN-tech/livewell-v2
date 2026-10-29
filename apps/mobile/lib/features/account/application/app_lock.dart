import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Optional fingerprint / face unlock (FR-ONB-01, D-62). Off by default.
/// When on, the app asks for the phone's own unlock (biometrics, or the
/// phone's PIN as a fallback) when it starts and when it comes back after
/// a minute away. The setting lives on this phone only.
abstract class DeviceUnlock {
  Future<bool> available();
  Future<bool> unlock(String reason);
}

class LocalAuthUnlock implements DeviceUnlock {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> unlock(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}

final deviceUnlockProvider = Provider<DeviceUnlock>((ref) => LocalAuthUnlock());

/// Whether the lock is on (shared preferences, this phone only).
class AppLockSetting extends AsyncNotifier<bool> {
  static const key = 'lw_app_lock';

  @override
  Future<bool> build() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Turning it on needs one successful unlock first, so nobody locks
  /// themselves out with a lock the phone can't open.
  Future<bool> set(bool on, String reason) async {
    if (on) {
      final unlock = ref.read(deviceUnlockProvider);
      if (!await unlock.available() || !await unlock.unlock(reason)) {
        return false;
      }
    }
    try {
      await (await SharedPreferences.getInstance()).setBool(key, on);
    } catch (_) {
      return false;
    }
    state = AsyncData(on);
    return true;
  }
}

final appLockProvider = AsyncNotifierProvider<AppLockSetting, bool>(
  AppLockSetting.new,
);

/// Covers the app with a lock screen while the lock is on and the app is
/// locked: at start, and after [away] in the background.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.away = const Duration(minutes: 1),
  });

  final Widget child;
  final Duration away;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = true;
  bool _asking = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && DateTime.now().difference(left) >= widget.away) {
        setState(() => _locked = true);
      }
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final ok = await ref
        .read(deviceUnlockProvider)
        .unlock(AppLocalizations.of(context).appLockReason);
    _asking = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  /// The system prompt shows by itself once each time the app locks.
  bool _prompted = false;

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(appLockProvider);
    final on = setting.value ?? false;
    // Known to be off: unlocked, so turning it on now doesn't lock the
    // person out mid-session (it locks next start or after [away]).
    if (setting.hasValue && !on) _locked = false;
    final showLock = on && _locked;
    if (!showLock) _prompted = false;
    if (showLock && !_prompted) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlock();
      });
    }
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    // One structure always, so the app underneath never restarts.
    return Stack(
      children: [
        ExcludeSemantics(excluding: showLock, child: widget.child),
        if (showLock)
          Positioned.fill(
            child: Material(
              key: const Key('app-lock'),
              color: p.background,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(LwSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_outline, size: 56, color: p.primary),
                      const SizedBox(height: LwSpacing.md),
                      Text(
                        l.appLockTitle,
                        style: t.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LwSpacing.xl),
                      FilledButton(
                        key: const Key('app-unlock'),
                        onPressed: _unlock,
                        child: Text(l.appLockUnlock),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
