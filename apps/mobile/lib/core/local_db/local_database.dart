import 'package:drift/drift.dart';

part 'local_database.g.dart';

/// The encrypted on-device database (T-FND-08, spec 10.2 and NFR-05/NFR-09).
///
/// It is the phone's own copy of the user's data plus the sync queue
/// (outbox). It is opened only through `openEncryptedDatabase`
/// (SQLCipher, key from the platform keystore); see docs/data-model.md,
/// "Local database (on device)".
@DriftDatabase(tables: [LocalCheckIns, SyncOutbox])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e);

  /// Opens through [open] on first use.
  LocalDatabase.lazy(DatabaseOpener open) : this(LazyDatabase(open));

  Future<void>? _closing;

  /// Closes once, however many times it is called.
  Future<void> closeOnce() => _closing ??= close();

  /// Bump when a table changes, and add the step to [migration]
  /// (AGENTS.md: data change needs a migration). v1: check-ins + outbox.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}

/// The phone's copy of `users/{uid}/checkins/{date}` (FR-DLY-02).
@DataClassName('LocalCheckIn')
class LocalCheckIns extends Table {
  TextColumn get uid => text()();

  /// Local date key, yyyy-mm-dd (the Firestore document id).
  TextColumn get date => text()();
  IntColumn get mood => integer()();
  IntColumn get energy => integer().nullable()();
  IntColumn get sleep => integer().nullable()();
  IntColumn get stress => integer().nullable()();
  IntColumn get timeAvailable => integer().nullable()();
  TextColumn get barrierText => text().nullable()();
  BoolColumn get gentleDay => boolean()();

  /// When the day was first saved; kept on a same-day re-submit.
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {uid, date};
}

/// The offline sync queue (NFR-05). One row per record waiting to reach the
/// server. The [idempotencyKey] names the record (e.g.
/// `checkin:{uid}:{date}`), so saving the same record again while it waits
/// replaces the queued values (last writer wins) instead of queueing a
/// second write, and the server write targets the same document, so a
/// retry after a lost reply can never create a second record.
@DataClassName('OutboxEntry')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get uid => text()();

  /// What the record is, e.g. `checkin` (for counts; never its content).
  TextColumn get kind => text()();

  /// Firestore document path, e.g. `users/{uid}/checkins/2026-11-19`.
  TextColumn get docPath => text()();

  /// The fields to write, as JSON. A null value removes the field on an
  /// update and is left out on a create.
  TextColumn get fields => text()();

  /// Goes up each time the queued values are replaced, so a flush that sent
  /// an older revision does not remove the newer one.
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Error code of the last failed attempt (a code only, never content).
  TextColumn get lastError => text().nullable()();

  /// The server refused the write (rules or validation): kept, but no longer
  /// retried automatically, so it can't block the rest of the queue.
  BoolColumn get parked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
