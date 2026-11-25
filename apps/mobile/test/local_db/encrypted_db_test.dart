import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/local_db/encrypted_open.dart';
import 'package:livewell/core/local_db/local_database.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

import 'local_db_test_support.dart';

/// T-FND-08: the local database is SQLCipher-encrypted with a key from the
/// platform keystore (NFR-09).
void main() {
  late Directory dir;
  late File file;
  late MemoryKeyStore keys;

  const secret = 'walk-after-lunch-marker';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lw_db_');
    file = File('${dir.path}/local.db');
    keys = MemoryKeyStore();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> writeOne(LocalDatabase db) => db
      .into(db.localCheckIns)
      .insert(
        LocalCheckInsCompanion.insert(
          uid: 'u1',
          date: '2026-11-19',
          mood: 4,
          barrierText: const Value(secret),
          gentleDay: false,
          updatedAt: DateTime(2026, 11, 19),
        ),
      );

  test('the linked library is SQLCipher', () {
    final db = s3.sqlite3.openInMemory();
    addTearDown(db.close);
    expect(db.select('PRAGMA cipher_version'), isNotEmpty);
  });

  test('first open makes a random 256-bit key and stores it', () async {
    final db = await openTestDatabase(file, keys);
    await writeOne(db);
    await db.close();
    expect(keys.key, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(keys.writes, 1);
    expect(newDatabaseKey(), isNot(newDatabaseKey()));
  });

  test(
    'the file on disk is encrypted: no SQLite header, no plain text',
    () async {
      final db = await openTestDatabase(file, keys);
      await writeOne(db);
      await db.close();
      final bytes = await file.readAsBytes();
      expect(bytes, isNotEmpty);
      expect(
        latin1.decode(bytes.sublist(0, 15), allowInvalid: true),
        isNot('SQLite format 3'),
      );
      expect(
        latin1.decode(bytes, allowInvalid: true).contains(secret),
        isFalse,
      );
      // Plain SQLite (no key) can't read it.
      final raw = s3.sqlite3.open(file.path);
      addTearDown(raw.close);
      expect(
        () => raw.select('SELECT count(*) FROM sqlite_master'),
        throwsA(isA<s3.SqliteException>()),
      );
    },
  );

  test('reopens with the stored key and keeps the data', () async {
    var db = await openTestDatabase(file, keys);
    await writeOne(db);
    await db.close();
    db = await openTestDatabase(file, keys);
    final rows = await db.select(db.localCheckIns).get();
    await db.close();
    expect(rows.single.barrierText, secret);
    expect(keys.writes, 1, reason: 'same key reused');
  });

  test('a file the key cannot open (restored backup, lost key) is replaced, '
      'not a crash', () async {
    var db = await openTestDatabase(file, keys);
    await writeOne(db);
    await db.close();
    keys.key = newDatabaseKey(); // not the file's key
    db = await openTestDatabase(file, keys);
    expect(await db.select(db.localCheckIns).get(), isEmpty);
    await db.close();

    keys.key = null; // key gone (e.g. keystore reset)
    db = await openTestDatabase(file, keys);
    expect(await db.select(db.localCheckIns).get(), isEmpty);
    await db.close();
    expect(keys.key, isNotNull);
  });

  test('key errors never carry the key or the SQL', () {
    final db = s3.sqlite3.openInMemory();
    addTearDown(db.close);
    expect(
      () => applyDatabaseKey(db, "abc'; DROP TABLE x; --"),
      throwsA(isA<LocalDatabaseKeyError>()),
    );
    expect(const LocalDatabaseKeyError().toString(), 'LocalDatabaseKeyError');
  });

  test('wiping removes the file and its journals', () async {
    final db = await openTestDatabase(file, keys);
    await writeOne(db);
    await db.close();
    await deleteDatabaseFiles(file);
    expect(dir.listSync(), isEmpty);
  });

  test(
    'SecureDatabaseKeyStore keeps the key in flutter_secure_storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureDatabaseKeyStore();
      expect(await store.read(), isNull);
      final key = newDatabaseKey();
      await store.write(key);
      expect(await store.read(), key);
      expect(
        await const FlutterSecureStorage().read(
          key: SecureDatabaseKeyStore.storageKey,
        ),
        key,
      );
      await store.delete();
      expect(await store.read(), isNull);
    },
  );

  test('no key is written in the code (AGENTS.md)', () {
    final code = [
      for (final f in Directory('lib/core/local_db').listSync())
        if (f is File) f.readAsStringSync(),
    ].join();
    expect(RegExp(r'[0-9a-fA-F]{32,}').hasMatch(code), isFalse);
  });
}
