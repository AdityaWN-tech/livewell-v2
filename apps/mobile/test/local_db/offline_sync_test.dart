import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/local_db/local_database.dart';
import 'package:livewell/core/local_db/sync_queue.dart';
import 'package:livewell/features/checkin/data/checkin_repository.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';

import 'local_db_test_support.dart';

/// T-FND-08 "Done when": offline log, then reconnect, syncs exactly once.
/// Real encrypted database file, real queue and engine; the server is a
/// fake with Firestore's per-document semantics.
void main() {
  const uid = 'u1';
  const day = '2026-11-19';
  const path = 'users/$uid/checkins/$day';

  late Directory dir;
  late File file;
  late MemoryKeyStore keys;
  late FakeServer server;
  late LocalDatabase db;
  late SyncQueue queue;
  late SyncEngine engine;
  late LocalFirstCheckInRepository repo;

  Future<void> open() async {
    db = await openTestDatabase(file, keys);
    queue = SyncQueue(db);
    engine = SyncEngine(
      queue: queue,
      remote: server,
      uid: () => uid,
      listenToLifecycle: false,
    );
    repo = LocalFirstCheckInRepository(
      db: db,
      queue: queue,
      remote: FakeServerCheckIns(server, uid),
      uid: () => uid,
    );
  }

  Future<void> close() async {
    engine.dispose();
    await db.close();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lw_sync_');
    file = File('${dir.path}/local.db');
    keys = MemoryKeyStore();
    server = FakeServer();
    await open();
  });

  tearDown(() async {
    await close();
    await dir.delete(recursive: true);
  });

  test('offline log, then reconnect: synced exactly once', () async {
    server.online = false;
    await repo.save(const CheckIn(date: day, mood: 4, gentleDay: false));
    // A second offline save the same day replaces the queued values.
    await repo.save(
      const CheckIn(date: day, mood: 5, timeAvailable: 10, gentleDay: false),
    );
    expect((await repo.watchDay(day).first)!.mood, 5, reason: 'local copy');
    var queued = await queue.entries(uid);
    expect(queued, hasLength(1), reason: 'one queued write per record');
    expect(queued.single.idempotencyKey, 'checkin:$uid:$day');
    expect(queued.single.revision, 2);

    // Still offline: the try fails, the entry stays.
    final offline = await engine.flushNow();
    expect(offline!.offline, isTrue);
    expect(server.docs, isEmpty);
    expect(await queue.entries(uid), hasLength(1));

    // The app is closed and reopened: the queue survives (encrypted file).
    await close();
    await open();
    queued = await queue.entries(uid);
    expect(queued, hasLength(1));
    expect(queued.single.attempts, 1);

    // Reconnect.
    server.online = true;
    final synced = await engine.flushNow();
    expect(synced!.sent, 1);
    expect(synced.remaining, 0);
    expect(server.commits, {path: 1}, reason: 'exactly once');
    final docs = server.checkIns(uid);
    expect(docs.keys, [day]);
    expect(docs[day]!['mood'], 5);
    expect(docs[day]!['time_available'], 10);
    expect(docs[day]!['source'], 'app');
    expect(docs[day]!['created_at'], isNotNull);
    expect(await queue.entries(uid), isEmpty);

    // Flushing again (resume, timer) sends nothing more.
    await engine.flushNow();
    await engine.flushNow();
    expect(server.commits, {path: 1});
  });

  test('online re-submit updates the one record and keeps created_at, and a '
      'skipped answer clears the earlier one', () async {
    await repo.save(
      const CheckIn(date: day, mood: 4, stress: 2, gentleDay: false),
    );
    await engine.flushNow();
    final created = server.checkIns(uid)[day]!['created_at'];
    await repo.save(const CheckIn(date: day, mood: 2, gentleDay: true));
    await engine.flushNow();
    final doc = server.checkIns(uid)[day]!;
    expect(server.checkIns(uid), hasLength(1));
    expect(doc['mood'], 2);
    expect(doc['gentle_day'], isTrue);
    expect(doc.containsKey('stress'), isFalse);
    expect(doc['created_at'], created);
  });

  test('a lost reply is retried into the same document, never a second '
      'record', () async {
    server.loseNextReply = true;
    await repo.save(const CheckIn(date: day, mood: 4, gentleDay: false));
    expect((await engine.flushNow())!.offline, isTrue);
    expect(await queue.entries(uid), hasLength(1), reason: 'not confirmed');
    await engine.flushNow();
    expect(server.checkIns(uid), hasLength(1));
    expect(server.checkIns(uid)[day]!['mood'], 4);
    expect(await queue.entries(uid), isEmpty);
  });

  test('a save while its older value is being sent is not lost', () async {
    await repo.save(const CheckIn(date: day, mood: 3, gentleDay: false));
    server.during = () async {
      server.during = null;
      await repo.save(const CheckIn(date: day, mood: 5, gentleDay: false));
    };
    await engine.flushNow();
    expect(server.checkIns(uid)[day]!['mood'], 5, reason: 'last writer wins');
    expect(await queue.entries(uid), isEmpty);
    expect(server.commits[path], 2);
  });

  test('a refused write is parked and does not block the rest; a new save '
      'tries again', () async {
    server.refuse.add(path);
    await repo.save(const CheckIn(date: day, mood: 4, gentleDay: false));
    await repo.save(
      const CheckIn(date: '2026-11-20', mood: 4, gentleDay: false),
    );
    final r = await engine.flushNow();
    expect(r!.parked, 1);
    expect(r.sent, 1);
    expect(server.checkIns(uid).keys, ['2026-11-20']);
    final parked = (await queue.entries(uid)).single;
    expect(parked.parked, isTrue);
    expect(parked.lastError, 'permission-denied');

    server.refuse.clear();
    await repo.save(const CheckIn(date: day, mood: 3, gentleDay: false));
    await engine.flushNow();
    expect(server.checkIns(uid)[day]!['mood'], 3);
    expect(await queue.entries(uid), isEmpty);
  });

  test('only the signed-in person\'s queue is sent', () async {
    await queue.enqueue(
      idempotencyKey: 'checkin:other:$day',
      uid: 'other',
      kind: 'checkin',
      docPath: 'users/other/checkins/$day',
      fields: {'mood': 3},
    );
    await engine.flushNow();
    expect(server.docs, isEmpty);
    expect(await queue.entries('other'), hasLength(1));
  });

  test('reads: the server copy fills the phone, but a local change waiting '
      'to sync wins', () async {
    // Saved on another phone.
    server.docs['users/$uid/checkins/2026-11-18'] = {
      'mood': 2,
      'gentle_day': true,
    };
    server.docs[path] = {'mood': 1, 'gentle_day': true};
    server.online = false;
    await repo.save(const CheckIn(date: day, mood: 5, gentleDay: false));
    server.online = true;

    final days = await repo.range('2026-11-01', '2026-11-30');
    expect(
      [for (final c in days) (c.date, c.mood)],
      [('2026-11-18', 2), (day, 5)],
    );
    // Offline later: the phone still has both.
    server.online = false;
    expect(await repo.range('2026-11-01', '2026-11-30'), hasLength(2));
  });

  test('back-off: 5 s doubling to 5 min', () {
    expect(SyncEngine.backoff(1), const Duration(seconds: 5));
    expect(SyncEngine.backoff(2), const Duration(seconds: 10));
    expect(SyncEngine.backoff(4), const Duration(seconds: 40));
    expect(SyncEngine.backoff(20), const Duration(minutes: 5));
  });

  test('flushes do not overlap: a second call joins the running one', () async {
    await repo.save(const CheckIn(date: day, mood: 4, gentleDay: false));
    final a = engine.flushNow();
    final b = engine.flushNow();
    await Future.wait([a, b]);
    expect(server.commits, {path: 1});
  });
}
