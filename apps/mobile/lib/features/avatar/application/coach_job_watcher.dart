import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../starter_plan/data/reminders.dart';
import '../data/avatar_maker_api.dart';
import '../presentation/coach_avatar.dart';

enum CoachJobStage { idle, making, ready, notMade }

/// Where the coach being made stands.
class CoachJob {
  const CoachJob(this.stage, {this.jobId, this.messageId});

  static const idle = CoachJob(CoachJobStage.idle);

  final CoachJobStage stage;
  final String? jobId;

  /// Why it wasn't made (avatar_not_made, ...), for a kind message.
  final String? messageId;
}

/// The notification's words. Generic on purpose: no name, photo or anything
/// personal on the lock screen (AGENTS.md).
class CoachNoticeTexts {
  const CoachNoticeTexts({
    required this.readyTitle,
    required this.readyBody,
    required this.notMadeTitle,
    required this.notMadeBody,
    required this.channelName,
  });

  final String readyTitle;
  final String readyBody;
  final String notMadeTitle;
  final String notMadeBody;
  final String channelName;
}

/// Follows a coach being made on the Media Service (T-AVT-08). It takes
/// several minutes on our GPU (docs/media/comfyui-setup.md), so the person
/// doesn't wait on the camera screen: while the app runs this asks how the
/// job is going and, when it ends, loads the new coach and shows a
/// notification (only with the notification consent, and not while the
/// person is watching the screen). The server also pushes one when FCM is
/// wired at deploy, for when the app is closed.
class CoachJobWatcher extends Notifier<CoachJob> {
  static const pollEvery = Duration(seconds: 10);
  static const maxWait = Duration(minutes: 20);
  static const noticeId = 7100;

  /// True while the selfie screen shows the job (it says the result itself).
  bool onScreen = false;
  int _run = 0;

  @override
  CoachJob build() => CoachJob.idle;

  /// Follows [jobId] until it ends; a newer [follow] or [clear] stops it.
  Future<void> follow(String jobId, CoachNoticeTexts texts) async {
    final run = ++_run;
    state = CoachJob(CoachJobStage.making, jobId: jobId);
    final api = ref.read(avatarMakerApiProvider);
    final tries = maxWait.inSeconds ~/ pollEvery.inSeconds;
    for (var i = 0; i < tries; i++) {
      await Future<void>.delayed(pollEvery);
      if (run != _run) return;
      final AvatarJobStatus job;
      try {
        job = await api.job(jobId);
      } on AvatarMakerError catch (e) {
        // A dropped connection: ask again next time.
        if (e.messageId == 'network') continue;
        return _end(run, jobId, e.messageId, texts);
      }
      if (!job.done) continue;
      return _end(
        run,
        jobId,
        job.succeeded ? null : job.messageId ?? 'avatar_not_made',
        texts,
      );
    }
    await _end(run, jobId, 'avatar_not_made', texts);
  }

  Future<void> _end(
    int run,
    String jobId,
    String? failed,
    CoachNoticeTexts t,
  ) async {
    if (run != _run) return;
    final made = failed == null;
    state = made
        ? CoachJob(CoachJobStage.ready, jobId: jobId)
        : CoachJob(CoachJobStage.notMade, jobId: jobId, messageId: failed);
    if (made) ref.invalidate(coachChoiceProvider);
    final life = WidgetsBinding.instance.lifecycleState;
    final away = life != null && life != AppLifecycleState.resumed;
    if (onScreen && !away) return;
    try {
      final consents = currentConsents(
        await ref.read(consentRepositoryProvider).watchRecords().first,
      );
      if (!isGranted(consents, ConsentType.notifications)) return;
      await ref
          .read(remindersProvider)
          .showNow(
            id: noticeId,
            title: made ? t.readyTitle : t.notMadeTitle,
            body: made ? t.readyBody : t.notMadeBody,
            channelName: t.channelName,
          );
    } catch (_) {
      // No notifications on this device: the Studio shows it next time.
    }
  }

  /// Stops following (a new photo is being taken).
  void clear() {
    _run++;
    state = CoachJob.idle;
  }
}

final coachJobWatcherProvider = NotifierProvider<CoachJobWatcher, CoachJob>(
  CoachJobWatcher.new,
);
