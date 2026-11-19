import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/auth/data/firebase_auth_service.dart';
import '../data/firestore.dart';
import '../data/firestore_remote_writer.dart';
import 'encrypted_open.dart';
import 'local_database.dart';
import 'sync_queue.dart';

/// The database file, in the app's private support directory.
Future<File> localDatabaseFile() async =>
    File('${(await getApplicationSupportDirectory()).path}/livewell_local.db');

final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => SecureDatabaseKeyStore(),
);

/// The encrypted database. Opened on first use (not at startup, NFR-01).
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final keys = ref.watch(databaseKeyStoreProvider);
  final db = LocalDatabase.lazy(
    () async =>
        openEncryptedDatabase(file: await localDatabaseFile(), keys: keys),
  );
  ref.onDispose(() => unawaited(db.closeOnce()));
  return db;
});

final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(ref.watch(localDatabaseProvider)),
);

final remoteWriterProvider = Provider<RemoteWriter>(
  (ref) => FirestoreRemoteWriter(ref.watch(firestoreProvider)),
);

/// Runs the queue for the signed-in user. Created with the first
/// repository that uses it, and flushes anything left from last time.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final auth = ref.watch(authServiceProvider);
  final engine = SyncEngine(
    queue: ref.watch(syncQueueProvider),
    remote: ref.watch(remoteWriterProvider),
    uid: () => auth.currentUser?.uid,
  );
  ref.onDispose(engine.dispose);
  engine.kick();
  return engine;
});

/// Removes this phone's copy on log out and account deletion: one last
/// try to send what is waiting, then the database file and its key go.
abstract class LocalDatabaseWiper {
  Future<void> wipe();
}

class EncryptedDatabaseWiper implements LocalDatabaseWiper {
  EncryptedDatabaseWiper(this._ref);

  final Ref _ref;

  static const lastFlush = Duration(seconds: 5);

  @override
  Future<void> wipe() async {
    try {
      await _ref.read(syncEngineProvider).flushNow().timeout(lastFlush);
    } catch (_) {
      // Offline: what is still waiting can't be sent (D-84).
    }
    final db = _ref.read(localDatabaseProvider);
    await db.closeOnce();
    _ref.invalidate(localDatabaseProvider);
    try {
      await deleteDatabaseFiles(await localDatabaseFile());
    } finally {
      // Without the key the file can never be read, even if deleting failed.
      await _ref.read(databaseKeyStoreProvider).delete();
    }
  }
}

final localDatabaseWiperProvider = Provider<LocalDatabaseWiper>(
  EncryptedDatabaseWiper.new,
);
