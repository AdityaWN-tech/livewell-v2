import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

/// Where the database key lives. The real one is the platform keystore
/// (iOS Keychain, Android Keystore-wrapped storage); never a constant in the
/// code, never logged (AGENTS.md, NFR-09).
abstract class DatabaseKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

/// The key in flutter_secure_storage. On iOS it is readable after the first
/// unlock (so a widget refresh or background sync can open the database) and
/// stays on this device: it is not in iCloud Keychain or a backup, so a
/// restored copy of the database file can't be opened (it is recreated).
class SecureDatabaseKeyStore implements DatabaseKeyStore {
  SecureDatabaseKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const storageKey = 'local_db_key_v1';
  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const _android = AndroidOptions();

  @override
  Future<String?> read() =>
      _storage.read(key: storageKey, iOptions: _ios, aOptions: _android);

  @override
  Future<void> write(String key) => _storage.write(
    key: storageKey,
    value: key,
    iOptions: _ios,
    aOptions: _android,
  );

  @override
  Future<void> delete() =>
      _storage.delete(key: storageKey, iOptions: _ios, aOptions: _android);
}

/// A new random 256-bit key, as 64 hex characters (SQLCipher raw key).
String newDatabaseKey([Random? random]) {
  final r = random ?? Random.secure();
  return [
    for (var i = 0; i < 32; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

final _rawKey = RegExp(r'^[0-9a-f]{64}$');

/// The linked SQLite is not SQLCipher: nothing is stored unencrypted.
class LocalDatabaseNotEncrypted implements Exception {
  const LocalDatabaseNotEncrypted();
  @override
  String toString() => 'LocalDatabaseNotEncrypted';
}

/// The key could not be applied. Deliberately carries no SQL text, because
/// SQLite errors quote the statement and the statement contains the key.
class LocalDatabaseKeyError implements Exception {
  const LocalDatabaseKeyError();
  @override
  String toString() => 'LocalDatabaseKeyError';
}

/// Makes [db] an encrypted database with [hexKey]. Runs first on every
/// connection, before any other statement.
void applyDatabaseKey(Database db, String hexKey) {
  if (!_rawKey.hasMatch(hexKey)) throw const LocalDatabaseKeyError();
  // Plain SQLite answers this pragma with no rows; SQLCipher with its version.
  if (db.select('PRAGMA cipher_version').isEmpty) {
    throw const LocalDatabaseNotEncrypted();
  }
  try {
    db.execute("PRAGMA key = \"x'$hexKey'\"");
  } on SqliteException {
    throw const LocalDatabaseKeyError();
  }
}

/// Whether [file] opens with [hexKey] (true for a new, empty file).
bool _opensWith(File file, String hexKey) {
  if (!file.existsSync()) return true;
  final db = sqlite3.open(file.path);
  try {
    applyDatabaseKey(db, hexKey);
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on SqliteException {
    // SQLITE_NOTADB: written with another key (e.g. a restored backup whose
    // key stayed on the old phone).
    return false;
  } finally {
    db.close();
  }
}

/// Removes the database file and its journal files.
Future<void> deleteDatabaseFiles(File file) async {
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${file.path}$suffix');
    if (await f.exists()) await f.delete();
  }
}

/// Opens [file] encrypted with the key from [keys], creating the key on
/// first use. If the file can't be read with the stored key (no key, or a
/// different one), it is replaced by an empty database: it can never be
/// decrypted, and the server copy is pulled again. Refuses to open at all
/// if the library is not SQLCipher.
Future<QueryExecutor> openEncryptedDatabase({
  required File file,
  required DatabaseKeyStore keys,
  bool background = true,
}) async {
  var key = await keys.read();
  if (key == null || !_rawKey.hasMatch(key)) {
    await deleteDatabaseFiles(file);
    key = newDatabaseKey();
    await keys.write(key);
  } else if (!_opensWith(file, key)) {
    await deleteDatabaseFiles(file);
  }
  final hexKey = key;
  void setup(Database db) => applyDatabaseKey(db, hexKey);
  return background
      ? NativeDatabase.createInBackground(file, setup: setup)
      : NativeDatabase(file, setup: setup);
}
