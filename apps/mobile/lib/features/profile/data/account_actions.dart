import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/painting.dart' show imageCache;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../starter_plan/data/plan_repository.dart';
import '../../voice/data/voice_repository.dart';
import '../../home/application/home_data.dart' show todayPlanProvider;
import '../../home/presentation/home_screen.dart'
    show canCheckInProvider, todayCheckInProvider;
import '../../onboarding/data/onboarding_store.dart';
import '../../starter_plan/data/reminders.dart';

/// The profile picture (T-ONB-03f), separate from the coach avatar.
/// Kept on this phone only: Cloud Storage needs the Blaze plan (D-17).
/// TODO(D-17): move to Cloud Storage with signed URLs once Blaze is on.
abstract class ProfilePhotoStore {
  Future<String?> current();

  /// Takes or picks a photo and keeps a copy; null when cancelled.
  Future<String?> pick({required bool camera});
  Future<void> remove();
}

class LocalProfilePhotoStore implements ProfilePhotoStore {
  Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/profile.jpg');

  @override
  Future<String?> current() async {
    final f = await _file();
    return await f.exists() ? f.path : null;
  }

  @override
  Future<String?> pick({required bool camera}) async {
    final picked = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      // Small square-ish image; shown cropped to a circle.
      maxWidth: 512,
      maxHeight: 512,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final f = await _file();
    await File(picked.path).copy(f.path);
    // The picker's own copy is not kept.
    try {
      await File(picked.path).delete();
    } on FileSystemException {
      // Already gone.
    }
    imageCache.clear();
    return f.path;
  }

  @override
  Future<void> remove() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
    imageCache.clear();
  }
}

final profilePhotoStoreProvider = Provider<ProfilePhotoStore>(
  (ref) => LocalProfilePhotoStore(),
);

/// The current profile picture path, refreshed after changes.
final profilePhotoProvider = FutureProvider<String?>(
  (ref) => ref.watch(profilePhotoStoreProvider).current(),
);

/// Server-side deletions (FR-SET-02/03): callable functions in
/// services/core-api that delete and write the audit log. Deployed with
/// the Blaze plan (D-17); until then they fail and the app says so.
abstract class Deletions {
  Future<void> deleteAvatar();
  Future<void> deleteVoice();
  Future<void> deleteAccount();
}

class CallableDeletions implements Deletions {
  Future<void> _call(String name) => FirebaseFunctions.instance
      .httpsCallable(name)
      .call<void>(<String, Object>{});

  @override
  Future<void> deleteAvatar() => _call('deleteAvatar');

  @override
  Future<void> deleteVoice() => _call('deleteVoice');

  @override
  Future<void> deleteAccount() => _call('deleteAccount');
}

final deletionsProvider = Provider<Deletions>((ref) => CallableDeletions());

/// Everything personal kept on the phone, cleared on log out and account
/// deletion (T-ONB-03f).
abstract class LocalData {
  Future<void> clear();

  /// True once, at the next start, after [clear]: the Firestore offline
  /// cache must be cleared before Firestore is used again.
  Future<bool> takeCachePending();
}

class SharedPrefsLocalData implements LocalData {
  static const _pending = 'clear_firestore_cache';

  /// Personal or per-person keys. Appearance stays: it is a phone setting.
  static const personalKeys = [
    'avatar_draft',
    'voice_draft',
    'checkin_last_asked_day',
    'reminders_time_zone',
  ];

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in personalKeys) {
      await p.remove(k);
    }
    await p.setBool(_pending, true);
  }

  @override
  Future<bool> takeCachePending() async {
    final p = await SharedPreferences.getInstance();
    final pending = p.getBool(_pending) ?? false;
    if (pending) await p.remove(_pending);
    return pending;
  }
}

final localDataProvider = Provider<LocalData>((ref) => SharedPrefsLocalData());

/// Log out / switch account / after deleting the account.
/// TODO(T-FND-08): also drop the encrypted database key.
class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  Future<void> logOut() async {
    await _ref.read(remindersProvider).cancelAll();
    await _ref.read(profilePhotoStoreProvider).remove();
    await _ref.read(localDataProvider).clear();
    await _ref.read(onboardingStoreProvider).clear();
    await _ref.read(authServiceProvider).signOut();
    // Nothing of the old account may show after switching.
    _ref
      ..invalidate(onboardingProvider)
      ..invalidate(currentProfileProvider)
      ..invalidate(todayCheckInProvider)
      ..invalidate(todayPlanProvider)
      ..invalidate(canCheckInProvider)
      ..invalidate(profilePhotoProvider)
      ..invalidate(planRepositoryProvider)
      ..invalidate(avatarRepositoryProvider)
      ..invalidate(voiceRepositoryProvider);
  }

  Future<void> deleteAccount() async {
    await _ref.read(deletionsProvider).deleteAccount();
    await logOut();
  }
}

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);
