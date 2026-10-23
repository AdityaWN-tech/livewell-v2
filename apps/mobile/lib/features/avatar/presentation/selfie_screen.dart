import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/avatar_maker_api.dart';
import '../data/selfie_capture.dart';
import '../domain/liveness.dart';

/// "Make me from my photo" (T-AVT-08e): a live selfie in the app (never the
/// gallery), one face, a blink (or a head turn) to show it's a live person,
/// with tips from on-device face detection. The photo is sent once to our
/// Media Service and only kept in memory until then. Pops with true when the
/// coach is made.
class SelfieScreen extends ConsumerStatefulWidget {
  const SelfieScreen({super.key});

  @override
  ConsumerState<SelfieScreen> createState() => _SelfieScreenState();
}

enum _Stage { camera, making, failed }

class _SelfieScreenState extends ConsumerState<SelfieScreen> {
  late final SelfieCapture _capture = ref.read(selfieCaptureProvider);
  late final AvatarMakerApi _api = ref.read(avatarMakerApiProvider);
  LivenessTracker _tracker = LivenessTracker();
  StreamSubscription<FaceObservation>? _seen;
  SelfieTip _tip = SelfieTip.noFace;
  _Stage _stage = _Stage.camera;
  bool _cameraOpen = false;
  String? _error;
  final _key = DateTime.now().microsecondsSinceEpoch.toString();

  /// How long to wait for the coach (the job takes 30 to 90 seconds).
  static const pollEvery = Duration(seconds: 3);
  static const pollTimes = 60;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      await _capture.start();
    } on SelfieCameraUnavailable {
      if (mounted) setState(() => _fail('camera'));
      return;
    }
    if (!mounted) return;
    _seen = _capture.observations.listen((f) {
      if (!mounted || _stage != _Stage.camera) return;
      if (f.faces == 0) _tracker.reset();
      final tip = _tracker.see(f);
      if (tip != _tip) setState(() => _tip = tip);
    });
    setState(() => _cameraOpen = true);
  }

  void _fail(String messageId) {
    _stage = _Stage.failed;
    _error = messageId;
  }

  /// Starts again with the camera (a new photo).
  Future<void> _retry() async {
    unawaited(_seen?.cancel());
    setState(() {
      _stage = _Stage.camera;
      _error = null;
      _cameraOpen = false;
      _tracker = LivenessTracker(_tracker.method);
      _tip = SelfieTip.noFace;
    });
    await _open();
  }

  void _switchToTurn() => setState(() {
    _tracker = LivenessTracker(
      _tracker.method == LivenessMethod.blink
          ? LivenessMethod.turn
          : LivenessMethod.blink,
    );
    _tip = SelfieTip.noFace;
  });

  Future<void> _take() async {
    final method = _tracker.method;
    setState(() => _stage = _Stage.making);
    Uint8List? photo;
    try {
      photo = await _capture.takePhoto();
      await _capture.stop();
      final jobId = await _api.startFromSelfie(
        jpeg: photo,
        liveness: method,
        idempotencyKey: _key,
      );
      // Sent once: the photo isn't needed on the phone any more.
      photo = null;
      for (var i = 0; i < pollTimes; i++) {
        await Future<void>.delayed(pollEvery);
        if (!mounted) return;
        final job = await _api.job(jobId);
        if (!job.done) continue;
        if (job.succeeded) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        if (mounted) setState(() => _fail(job.messageId ?? 'avatar_not_made'));
        return;
      }
      if (mounted) setState(() => _fail('avatar_not_made'));
    } on SelfieCameraUnavailable {
      if (mounted) setState(() => _fail('camera'));
    } on AvatarMakerError catch (e) {
      if (mounted) setState(() => _fail(e.messageId));
    } finally {
      photo = null;
    }
  }

  @override
  void dispose() {
    _seen?.cancel();
    _capture.close();
    super.dispose();
  }

  String _tipText(AppLocalizations l) => switch (_tip) {
    SelfieTip.noFace => l.photoTipNoFace,
    SelfieTip.oneFaceOnly => l.photoTipOneFace,
    SelfieTip.moveCloser => l.photoTipCloser,
    SelfieTip.moveBack => l.photoTipBack,
    SelfieTip.centre => l.photoTipCentre,
    SelfieTip.blink => l.photoTipBlink,
    SelfieTip.turn => l.photoTipTurn,
    SelfieTip.ready => l.photoTipReady,
  };

  String _errorText(AppLocalizations l) => switch (_error) {
    'avatar_daily_limit' => l.photoErrLimit,
    'camera' => l.photoErrCamera,
    'network' => l.photoErrNetwork,
    'consent_required' => l.photoErrConsent,
    'not_configured' || 'feature_off' => l.photoErrUnavailable,
    _ => l.photoErrNotMade,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final ready = _tip == SelfieTip.ready;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('selfie'),
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            LwPageTitle(l.photoTitle),
            if (_stage == _Stage.camera) ...[
              LayoutBuilder(
                builder: (context, box) {
                  final side = math.min(box.maxWidth, 320.0);
                  return Center(
                    child: Container(
                      key: const Key('selfie-preview'),
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ready ? p.success : p.outlineStrong,
                          width: 4,
                        ),
                      ),
                      child: ClipOval(
                        child: _cameraOpen
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: side,
                                  height: side * 4 / 3,
                                  child: _capture.preview(),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: LwSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _tipText(l),
                  key: const Key('selfie-tip'),
                  textAlign: TextAlign.center,
                  style: t.titleMedium,
                ),
              ),
              const SizedBox(height: LwSpacing.md),
              FilledButton(
                key: const Key('selfie-take'),
                onPressed: ready ? _take : null,
                child: Text(l.photoTake),
              ),
              const SizedBox(height: LwSpacing.xs),
              Center(
                child: TextButton(
                  key: const Key('selfie-switch'),
                  onPressed: _switchToTurn,
                  child: Text(
                    _tracker.method == LivenessMethod.blink
                        ? l.photoUseTurn
                        : l.photoUseBlink,
                  ),
                ),
              ),
              const SizedBox(height: LwSpacing.sm),
              Text(l.photoPrivacy, style: t.bodySmall),
            ],
            if (_stage == _Stage.making) ...[
              const SizedBox(height: LwSpacing.xl),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: LwSpacing.md),
              Text(
                l.photoMaking,
                key: const Key('selfie-making'),
                textAlign: TextAlign.center,
                style: t.titleMedium,
              ),
            ],
            if (_stage == _Stage.failed) ...[
              const SizedBox(height: LwSpacing.lg),
              Text(
                _errorText(l),
                key: Key('selfie-error-$_error'),
                style: t.titleMedium,
              ),
              const SizedBox(height: LwSpacing.md),
              if (_error != 'avatar_daily_limit' &&
                  _error != 'not_configured' &&
                  _error != 'feature_off')
                FilledButton(
                  key: const Key('selfie-retry'),
                  onPressed: _retry,
                  child: Text(l.photoTryAgain),
                ),
              const SizedBox(height: LwSpacing.xs),
              OutlinedButton(
                key: const Key('selfie-pick-ready'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.photoPickReady),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
