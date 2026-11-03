import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/media_service.dart';
import '../domain/liveness.dart';

/// Where a job stands (GET /v1/avatar/jobs/{id}, T-AVT-08c/d).
class AvatarJobStatus {
  const AvatarJobStatus({
    required this.status,
    this.messageId,
    this.framesVersion,
  });

  /// queued, running, succeeded, rejected or failed.
  final String status;

  /// A kind message to show when it didn't work (avatar_not_made, ...).
  final String? messageId;
  final int? framesVersion;

  bool get done => status != 'queued' && status != 'running';
  bool get succeeded => status == 'succeeded';
}

/// Why a request couldn't start, as a message id the app words kindly:
/// not_configured, network, feature_off, consent_required,
/// avatar_daily_limit, or another refusal.
class AvatarMakerError implements Exception {
  const AvatarMakerError(this.messageId);
  final String messageId;
}

/// The Media Service's avatar endpoints. Photos only go to it, over HTTPS.
abstract class AvatarMakerApi {
  /// Starts "Make me from my photo". [jpeg] is the live selfie, held in
  /// memory only and sent once.
  Future<String> startFromSelfie({
    required Uint8List jpeg,
    required LivenessMethod liveness,
    required String idempotencyKey,
  });

  /// Starts "Build my own" from option ids (content/avatar/options.json).
  Future<String> startBuilt({
    required Map<String, String> options,
    required String idempotencyKey,
  });

  /// Starts "Adjust" on the person's current made-for-you coach: only the
  /// changed option ids.
  Future<String> startAdjust({
    required Map<String, String> changes,
    required String idempotencyKey,
  });

  Future<AvatarJobStatus> job(String jobId);

  /// False while the Media Service isn't set up: the Studio then hides the
  /// ways that need it.
  bool get available;
}

/// The Media Service isn't deployed yet (it is built in T-AVT-08c/d and set
/// up at deploy, with App Check): nothing is sent.
class UnavailableAvatarMaker implements AvatarMakerApi {
  @override
  Future<String> startFromSelfie({
    required Uint8List jpeg,
    required LivenessMethod liveness,
    required String idempotencyKey,
  }) async => throw const AvatarMakerError('not_configured');

  @override
  Future<String> startBuilt({
    required Map<String, String> options,
    required String idempotencyKey,
  }) async => throw const AvatarMakerError('not_configured');

  @override
  Future<String> startAdjust({
    required Map<String, String> changes,
    required String idempotencyKey,
  }) async => throw const AvatarMakerError('not_configured');

  @override
  Future<AvatarJobStatus> job(String jobId) async =>
      throw const AvatarMakerError('not_configured');

  @override
  bool get available => false;
}

/// The real client: HTTPS to [base] with a Firebase ID token and an App
/// Check token on every call (spec 12.1). Plain HTTP only to this phone in a
/// debug build (a Media Service on the developer's computer, D-64).
class HttpAvatarMaker implements AvatarMakerApi {
  HttpAvatarMaker({
    required this.base,
    required this.idToken,
    required this.appCheckToken,
  }) : assert(mediaUrlAllowed(base), 'The Media Service is HTTPS only');

  final Uri base;
  final Future<String> Function() idToken;
  final Future<String> Function() appCheckToken;

  Future<(int, Map<String, dynamic>)> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    if (!mediaUrlAllowed(base)) throw const AvatarMakerError('not_configured');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.openUrl(method, base.resolve(path));
      request.headers
        ..set('Authorization', 'Bearer ${await idToken()}')
        ..set('X-Firebase-AppCheck', await appCheckToken())
        ..contentType = ContentType.json;
      if (idempotencyKey != null) {
        request.headers.set('Idempotency-Key', idempotencyKey);
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final json = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;
      return (response.statusCode, json);
    } on AvatarMakerError {
      rethrow;
    } catch (_) {
      throw const AvatarMakerError('network');
    } finally {
      client.close();
    }
  }

  static AvatarMakerError _refusal(Map<String, dynamic> json) =>
      AvatarMakerError(
        json['detail'] is String ? json['detail'] as String : 'refused',
      );

  @override
  Future<String> startFromSelfie({
    required Uint8List jpeg,
    required LivenessMethod liveness,
    required String idempotencyKey,
  }) async {
    final (code, json) = await _send(
      'POST',
      'v1/avatar',
      body: {
        'source': 'selfie',
        'liveness': liveness.id,
        'selfie_jpeg_base64': base64Encode(jpeg),
      },
      idempotencyKey: idempotencyKey,
    );
    if (code != 202) throw _refusal(json);
    return json['job_id'] as String;
  }

  @override
  Future<String> startBuilt({
    required Map<String, String> options,
    required String idempotencyKey,
  }) => _start('built', options, idempotencyKey);

  @override
  Future<String> startAdjust({
    required Map<String, String> changes,
    required String idempotencyKey,
  }) => _start('adjust', changes, idempotencyKey);

  Future<String> _start(
    String source,
    Map<String, String> options,
    String idempotencyKey,
  ) async {
    final (code, json) = await _send(
      'POST',
      'v1/avatar',
      body: {'source': source, 'options': options},
      idempotencyKey: idempotencyKey,
    );
    if (code != 202) throw _refusal(json);
    return json['job_id'] as String;
  }

  @override
  bool get available => true;

  @override
  Future<AvatarJobStatus> job(String jobId) async {
    final (code, json) = await _send('GET', 'v1/avatar/jobs/$jobId');
    if (code != 200) throw _refusal(json);
    return AvatarJobStatus(
      status: json['status'] as String,
      messageId: json['message_id'] as String?,
      framesVersion: json['frames_version'] as int?,
    );
  }
}

/// The signed-in person's Firebase ID token for the Media Service.
Future<String> firebaseIdToken() async {
  final token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw const AvatarMakerError('not_configured');
  return token;
}

/// The Media Service once its address is set (dev: LW_MEDIA_URL, D-64).
/// TODO(T-AVT-08 deploy): App Check activation; until then the dev service
/// runs with MEDIA_REQUIRE_APP_CHECK=0 and this sends no token.
final avatarMakerApiProvider = Provider<AvatarMakerApi>((ref) {
  final base = ref.watch(mediaServiceBaseProvider);
  if (base == null) return UnavailableAvatarMaker();
  return HttpAvatarMaker(
    base: base,
    idToken: firebaseIdToken,
    appCheckToken: () async => '',
  );
});
