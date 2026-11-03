import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';

/// Theme and in-app text size (T-ONB-03f, FR-SET-01).
class Appearance {
  const Appearance({this.theme = ThemeMode.system, this.textScale = 1.0});

  final ThemeMode theme;

  /// Multiplies the phone's own text size: 1.0, 1.15 or 1.3.
  final double textScale;

  static const scales = [1.0, 1.15, 1.3];

  Map<String, Object> toMap() => {'theme': theme.name, 'text_scale': textScale};

  static Appearance fromMap(Map<String, dynamic>? m) => Appearance(
    theme:
        ThemeMode.values.where((t) => t.name == m?['theme']).firstOrNull ??
        ThemeMode.system,
    textScale: scales.contains((m?['text_scale'] as num?)?.toDouble())
        ? (m!['text_scale'] as num).toDouble()
        : 1.0,
  );

  Appearance copyWith({ThemeMode? theme, double? textScale}) => Appearance(
    theme: theme ?? this.theme,
    textScale: textScale ?? this.textScale,
  );
}

/// Kept on the phone too, so the right theme shows from the first frame,
/// before the profile has loaded.
abstract class AppearanceStore {
  Future<Appearance> load();
  Future<void> save(Appearance a);
}

class SharedPrefsAppearanceStore implements AppearanceStore {
  static const _theme = 'appearance_theme';
  static const _scale = 'appearance_text_scale';

  @override
  Future<Appearance> load() async {
    final p = await SharedPreferences.getInstance();
    return Appearance.fromMap({
      'theme': p.getString(_theme),
      'text_scale': p.getDouble(_scale),
    });
  }

  @override
  Future<void> save(Appearance a) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_theme, a.theme.name);
    await p.setDouble(_scale, a.textScale);
  }
}

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => SharedPrefsAppearanceStore(),
);

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() {
    // Phone copy first; the profile (other devices) wins once it loads.
    ref
        .read(appearanceStoreProvider)
        .load()
        .then((a) {
          if (ref.mounted) state = a;
        })
        // Unreadable phone storage: keep the default look, never crash.
        .catchError((Object _) {});
    ref.listen(currentProfileProvider, (_, next) {
      final m = next.value?.settings[ProfileSettings.appearance];
      if (m is Map<String, dynamic>) state = Appearance.fromMap(m);
    });
    return const Appearance();
  }

  /// Applies at once, then saves on the phone and the profile.
  Future<void> set(Appearance a) async {
    state = a;
    await ref.read(appearanceStoreProvider).save(a);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      await ref.read(profileRepositoryProvider).updateSettings(uid, {
        ProfileSettings.appearance: a.toMap(),
      });
    }
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);
