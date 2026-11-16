import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/firebase_auth_service.dart';
import '../../profile/data/account_actions.dart' show deletionsProvider;
import '../../widget/application/widget_sync.dart';
import '../../widget/data/widget_publisher.dart';
import '../data/avatar_frames_store.dart';
import '../presentation/coach_avatar.dart';
import 'coach_job_watcher.dart';

/// Everything about the person's own avatar kept on this phone: the frame
/// sets (`<app support>/avatars/{uid}/`) and the copies of its faces the
/// home-screen widget keeps.
abstract class AvatarLocalData {
  Future<void> clear(String uid);
}

class DeviceAvatarLocalData implements AvatarLocalData {
  DeviceAvatarLocalData(this._frames, this._widget);

  final AvatarFrameCache _frames;
  final WidgetPublisher _widget;

  @override
  Future<void> clear(String uid) async {
    await _frames.clear(uid);
    await _widget.clearFaces();
  }
}

final avatarLocalDataProvider = Provider<AvatarLocalData>(
  (ref) => DeviceAvatarLocalData(
    ref.watch(avatarFrameCacheProvider),
    ref.watch(widgetPublisherProvider),
  ),
);

/// "Delete my avatar" (FR-SET-03, T-AVT-05, D-78). HUMAN REVIEW REQUIRED
/// (privacy). The server deletes first (portraits, frame sets and selfies
/// in Cloud Storage, the vendor copy queued, an audit entry, the avatar
/// back to a ready-made coach). If that call fails, it throws and nothing
/// on the phone changes, so the app never says it's done when it isn't;
/// asking again is safe (the server side is idempotent). Then this phone
/// forgets its copies: the frame sets, the widget's faces, and any photo
/// job still being followed; the coach, the widget and the reminders'
/// faces fall back to the ready-made coach.
class AvatarDeletion {
  AvatarDeletion(this._ref);

  final Ref _ref;

  Future<void> run() async {
    await _ref.read(deletionsProvider).deleteAvatar();
    _ref.read(coachJobWatcherProvider.notifier).clear();
    final uid = _ref.read(signedInUidProvider);
    if (uid != null) await _ref.read(avatarLocalDataProvider).clear(uid);
    _ref
      ..invalidate(coachChoiceProvider)
      ..invalidate(ownFrameSetProvider)
      ..invalidate(widgetFacesProvider);
    // The widget shows the ready-made coach straight away.
    await _ref.read(widgetSyncProvider).refresh();
  }
}

final avatarDeletionProvider = Provider<AvatarDeletion>(AvatarDeletion.new);
