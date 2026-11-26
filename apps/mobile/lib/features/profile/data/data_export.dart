import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/firestore.dart';
import '../../auth/data/firebase_auth_service.dart';

/// "Download my data" (FR-SET-02, T-CMP-03, D-82). The server builds a zip
/// (data.json, summary.pdf, README.txt) that is kept for 7 days; the app
/// asks for it, watches the job in users/{uid}/data_exports and opens a
/// 15-minute download link. Nothing about the export is sent to analytics.
enum DataExportStatus { preparing, ready, failed, expired }

class DataExportJob {
  const DataExportJob({
    required this.id,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final DataExportStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Same as the server: still preparing after an hour means it failed
  /// (and a new one may be asked for); ready past expires_at is gone.
  static const staleAfter = Duration(minutes: 60);

  static DataExportJob fromMap(
    String id,
    Map<String, dynamic> data,
    DateTime now,
  ) {
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    final created = time(data['created_at']);
    final expires = time(data['expires_at']);
    final status = switch (data['status']) {
      'ready' when expires != null && !expires.isAfter(now) =>
        DataExportStatus.expired,
      'ready' => DataExportStatus.ready,
      'preparing'
          when created != null && now.difference(created) >= staleAfter =>
        DataExportStatus.failed,
      'preparing' => DataExportStatus.preparing,
      _ => DataExportStatus.failed,
    };
    return DataExportJob(
      id: id,
      status: status,
      createdAt: created,
      expiresAt: expires,
    );
  }
}

/// One export a day (the server's limit).
class DataExportLimited implements Exception {
  const DataExportLimited(this.retryAfter);
  final DateTime? retryAfter;
}

abstract class DataExports {
  /// The newest export, or null when none was asked for.
  Stream<DataExportJob?> watchLatest();

  /// Starts a new export. Throws [DataExportLimited] within a day of the
  /// last one.
  Future<void> request();

  /// A short-lived link to download a ready export.
  Future<Uri> downloadLink(String jobId);
}

class FirebaseDataExports implements DataExports {
  FirebaseDataExports(this._db, this._uid, this._now);

  final FirebaseFirestore _db;
  final String Function() _uid;
  final DateTime Function() _now;

  HttpsCallable _fn(String name) =>
      FirebaseFunctions.instance.httpsCallable(name);

  @override
  Stream<DataExportJob?> watchLatest() => _db
      .collection('users')
      .doc(_uid())
      .collection('data_exports')
      .orderBy('created_at', descending: true)
      .limit(1)
      .snapshots()
      .map(
        (s) => s.docs.isEmpty
            ? null
            : DataExportJob.fromMap(
                s.docs.first.id,
                s.docs.first.data(),
                _now(),
              ),
      );

  @override
  Future<void> request() async {
    try {
      await _fn('requestDataExport').call<Object?>(<String, Object>{});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        final details = e.details;
        final after = details is Map ? details['retry_after'] : null;
        throw DataExportLimited(
          after is String ? DateTime.tryParse(after)?.toLocal() : null,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Uri> downloadLink(String jobId) async {
    final r = await _fn('getDataExportLink')
        .call<Object?>(<String, Object>{'jobId': jobId});
    return Uri.parse((r.data! as Map)['url'] as String);
  }
}

final dataExportsProvider = Provider<DataExports>((ref) {
  final auth = ref.watch(authServiceProvider);
  return FirebaseDataExports(
    ref.watch(firestoreProvider),
    () => auth.currentUser!.uid,
    DateTime.now,
  );
});

/// The newest export, watched while the sheet is open.
final latestDataExportProvider = StreamProvider.autoDispose<DataExportJob?>(
  (ref) => ref.watch(dataExportsProvider).watchLatest(),
);

/// Opens the download link (or the email fallback) outside the app, so the
/// browser saves the file. Overridden in tests.
final dataExportOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
