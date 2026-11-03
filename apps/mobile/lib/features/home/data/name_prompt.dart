import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "What should your coach call you?" is asked once (T-UI-02c): saving or
/// "Not now" both count. Kept on the phone and cleared on log out.
abstract class NamePromptStore {
  Future<bool> asked();
  Future<void> markAsked();
}

class SharedPrefsNamePromptStore implements NamePromptStore {
  static const key = 'name_prompt_asked';

  @override
  Future<bool> asked() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;

  @override
  Future<void> markAsked() async =>
      (await SharedPreferences.getInstance()).setBool(key, true);
}

final namePromptStoreProvider = Provider<NamePromptStore>(
  (ref) => SharedPrefsNamePromptStore(),
);

/// True once the prompt was answered or dismissed. Unreadable storage
/// counts as asked: never nag.
final namePromptAskedProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(namePromptStoreProvider).asked();
  } catch (_) {
    return true;
  }
});

/// A first name: letters (any script), spaces, hyphens and apostrophes,
/// 1 to 30 characters.
bool isValidFirstName(String v) =>
    RegExp(r"^[\p{L}][\p{L}\p{M} '\-]{0,29}$", unicode: true).hasMatch(v);
