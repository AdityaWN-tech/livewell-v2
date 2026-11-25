// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalCheckInsTable extends LocalCheckIns
    with TableInfo<$LocalCheckInsTable, LocalCheckIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<int> mood = GeneratedColumn<int>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
    'energy',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepMeta = const VerificationMeta('sleep');
  @override
  late final GeneratedColumn<int> sleep = GeneratedColumn<int>(
    'sleep',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stressMeta = const VerificationMeta('stress');
  @override
  late final GeneratedColumn<int> stress = GeneratedColumn<int>(
    'stress',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeAvailableMeta = const VerificationMeta(
    'timeAvailable',
  );
  @override
  late final GeneratedColumn<int> timeAvailable = GeneratedColumn<int>(
    'time_available',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barrierTextMeta = const VerificationMeta(
    'barrierText',
  );
  @override
  late final GeneratedColumn<String> barrierText = GeneratedColumn<String>(
    'barrier_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gentleDayMeta = const VerificationMeta(
    'gentleDay',
  );
  @override
  late final GeneratedColumn<bool> gentleDay = GeneratedColumn<bool>(
    'gentle_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("gentle_day" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uid,
    date,
    mood,
    energy,
    sleep,
    stress,
    timeAvailable,
    barrierText,
    gentleDay,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCheckIn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    }
    if (data.containsKey('sleep')) {
      context.handle(
        _sleepMeta,
        sleep.isAcceptableOrUnknown(data['sleep']!, _sleepMeta),
      );
    }
    if (data.containsKey('stress')) {
      context.handle(
        _stressMeta,
        stress.isAcceptableOrUnknown(data['stress']!, _stressMeta),
      );
    }
    if (data.containsKey('time_available')) {
      context.handle(
        _timeAvailableMeta,
        timeAvailable.isAcceptableOrUnknown(
          data['time_available']!,
          _timeAvailableMeta,
        ),
      );
    }
    if (data.containsKey('barrier_text')) {
      context.handle(
        _barrierTextMeta,
        barrierText.isAcceptableOrUnknown(
          data['barrier_text']!,
          _barrierTextMeta,
        ),
      );
    }
    if (data.containsKey('gentle_day')) {
      context.handle(
        _gentleDayMeta,
        gentleDay.isAcceptableOrUnknown(data['gentle_day']!, _gentleDayMeta),
      );
    } else if (isInserting) {
      context.missing(_gentleDayMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid, date};
  @override
  LocalCheckIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCheckIn(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood'],
      )!,
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy'],
      ),
      sleep: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sleep'],
      ),
      stress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stress'],
      ),
      timeAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_available'],
      ),
      barrierText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barrier_text'],
      ),
      gentleDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}gentle_day'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalCheckInsTable createAlias(String alias) {
    return $LocalCheckInsTable(attachedDatabase, alias);
  }
}

class LocalCheckIn extends DataClass implements Insertable<LocalCheckIn> {
  final String uid;

  /// Local date key, yyyy-mm-dd (the Firestore document id).
  final String date;
  final int mood;
  final int? energy;
  final int? sleep;
  final int? stress;
  final int? timeAvailable;
  final String? barrierText;
  final bool gentleDay;

  /// When the day was first saved; kept on a same-day re-submit.
  final DateTime? createdAt;
  final DateTime updatedAt;
  const LocalCheckIn({
    required this.uid,
    required this.date,
    required this.mood,
    this.energy,
    this.sleep,
    this.stress,
    this.timeAvailable,
    this.barrierText,
    required this.gentleDay,
    this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['date'] = Variable<String>(date);
    map['mood'] = Variable<int>(mood);
    if (!nullToAbsent || energy != null) {
      map['energy'] = Variable<int>(energy);
    }
    if (!nullToAbsent || sleep != null) {
      map['sleep'] = Variable<int>(sleep);
    }
    if (!nullToAbsent || stress != null) {
      map['stress'] = Variable<int>(stress);
    }
    if (!nullToAbsent || timeAvailable != null) {
      map['time_available'] = Variable<int>(timeAvailable);
    }
    if (!nullToAbsent || barrierText != null) {
      map['barrier_text'] = Variable<String>(barrierText);
    }
    map['gentle_day'] = Variable<bool>(gentleDay);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalCheckInsCompanion toCompanion(bool nullToAbsent) {
    return LocalCheckInsCompanion(
      uid: Value(uid),
      date: Value(date),
      mood: Value(mood),
      energy: energy == null && nullToAbsent
          ? const Value.absent()
          : Value(energy),
      sleep: sleep == null && nullToAbsent
          ? const Value.absent()
          : Value(sleep),
      stress: stress == null && nullToAbsent
          ? const Value.absent()
          : Value(stress),
      timeAvailable: timeAvailable == null && nullToAbsent
          ? const Value.absent()
          : Value(timeAvailable),
      barrierText: barrierText == null && nullToAbsent
          ? const Value.absent()
          : Value(barrierText),
      gentleDay: Value(gentleDay),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalCheckIn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCheckIn(
      uid: serializer.fromJson<String>(json['uid']),
      date: serializer.fromJson<String>(json['date']),
      mood: serializer.fromJson<int>(json['mood']),
      energy: serializer.fromJson<int?>(json['energy']),
      sleep: serializer.fromJson<int?>(json['sleep']),
      stress: serializer.fromJson<int?>(json['stress']),
      timeAvailable: serializer.fromJson<int?>(json['timeAvailable']),
      barrierText: serializer.fromJson<String?>(json['barrierText']),
      gentleDay: serializer.fromJson<bool>(json['gentleDay']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'date': serializer.toJson<String>(date),
      'mood': serializer.toJson<int>(mood),
      'energy': serializer.toJson<int?>(energy),
      'sleep': serializer.toJson<int?>(sleep),
      'stress': serializer.toJson<int?>(stress),
      'timeAvailable': serializer.toJson<int?>(timeAvailable),
      'barrierText': serializer.toJson<String?>(barrierText),
      'gentleDay': serializer.toJson<bool>(gentleDay),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalCheckIn copyWith({
    String? uid,
    String? date,
    int? mood,
    Value<int?> energy = const Value.absent(),
    Value<int?> sleep = const Value.absent(),
    Value<int?> stress = const Value.absent(),
    Value<int?> timeAvailable = const Value.absent(),
    Value<String?> barrierText = const Value.absent(),
    bool? gentleDay,
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalCheckIn(
    uid: uid ?? this.uid,
    date: date ?? this.date,
    mood: mood ?? this.mood,
    energy: energy.present ? energy.value : this.energy,
    sleep: sleep.present ? sleep.value : this.sleep,
    stress: stress.present ? stress.value : this.stress,
    timeAvailable: timeAvailable.present
        ? timeAvailable.value
        : this.timeAvailable,
    barrierText: barrierText.present ? barrierText.value : this.barrierText,
    gentleDay: gentleDay ?? this.gentleDay,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalCheckIn copyWithCompanion(LocalCheckInsCompanion data) {
    return LocalCheckIn(
      uid: data.uid.present ? data.uid.value : this.uid,
      date: data.date.present ? data.date.value : this.date,
      mood: data.mood.present ? data.mood.value : this.mood,
      energy: data.energy.present ? data.energy.value : this.energy,
      sleep: data.sleep.present ? data.sleep.value : this.sleep,
      stress: data.stress.present ? data.stress.value : this.stress,
      timeAvailable: data.timeAvailable.present
          ? data.timeAvailable.value
          : this.timeAvailable,
      barrierText: data.barrierText.present
          ? data.barrierText.value
          : this.barrierText,
      gentleDay: data.gentleDay.present ? data.gentleDay.value : this.gentleDay,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCheckIn(')
          ..write('uid: $uid, ')
          ..write('date: $date, ')
          ..write('mood: $mood, ')
          ..write('energy: $energy, ')
          ..write('sleep: $sleep, ')
          ..write('stress: $stress, ')
          ..write('timeAvailable: $timeAvailable, ')
          ..write('barrierText: $barrierText, ')
          ..write('gentleDay: $gentleDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uid,
    date,
    mood,
    energy,
    sleep,
    stress,
    timeAvailable,
    barrierText,
    gentleDay,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCheckIn &&
          other.uid == this.uid &&
          other.date == this.date &&
          other.mood == this.mood &&
          other.energy == this.energy &&
          other.sleep == this.sleep &&
          other.stress == this.stress &&
          other.timeAvailable == this.timeAvailable &&
          other.barrierText == this.barrierText &&
          other.gentleDay == this.gentleDay &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalCheckInsCompanion extends UpdateCompanion<LocalCheckIn> {
  final Value<String> uid;
  final Value<String> date;
  final Value<int> mood;
  final Value<int?> energy;
  final Value<int?> sleep;
  final Value<int?> stress;
  final Value<int?> timeAvailable;
  final Value<String?> barrierText;
  final Value<bool> gentleDay;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalCheckInsCompanion({
    this.uid = const Value.absent(),
    this.date = const Value.absent(),
    this.mood = const Value.absent(),
    this.energy = const Value.absent(),
    this.sleep = const Value.absent(),
    this.stress = const Value.absent(),
    this.timeAvailable = const Value.absent(),
    this.barrierText = const Value.absent(),
    this.gentleDay = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCheckInsCompanion.insert({
    required String uid,
    required String date,
    required int mood,
    this.energy = const Value.absent(),
    this.sleep = const Value.absent(),
    this.stress = const Value.absent(),
    this.timeAvailable = const Value.absent(),
    this.barrierText = const Value.absent(),
    required bool gentleDay,
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : uid = Value(uid),
       date = Value(date),
       mood = Value(mood),
       gentleDay = Value(gentleDay),
       updatedAt = Value(updatedAt);
  static Insertable<LocalCheckIn> custom({
    Expression<String>? uid,
    Expression<String>? date,
    Expression<int>? mood,
    Expression<int>? energy,
    Expression<int>? sleep,
    Expression<int>? stress,
    Expression<int>? timeAvailable,
    Expression<String>? barrierText,
    Expression<bool>? gentleDay,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (date != null) 'date': date,
      if (mood != null) 'mood': mood,
      if (energy != null) 'energy': energy,
      if (sleep != null) 'sleep': sleep,
      if (stress != null) 'stress': stress,
      if (timeAvailable != null) 'time_available': timeAvailable,
      if (barrierText != null) 'barrier_text': barrierText,
      if (gentleDay != null) 'gentle_day': gentleDay,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCheckInsCompanion copyWith({
    Value<String>? uid,
    Value<String>? date,
    Value<int>? mood,
    Value<int?>? energy,
    Value<int?>? sleep,
    Value<int?>? stress,
    Value<int?>? timeAvailable,
    Value<String?>? barrierText,
    Value<bool>? gentleDay,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalCheckInsCompanion(
      uid: uid ?? this.uid,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      sleep: sleep ?? this.sleep,
      stress: stress ?? this.stress,
      timeAvailable: timeAvailable ?? this.timeAvailable,
      barrierText: barrierText ?? this.barrierText,
      gentleDay: gentleDay ?? this.gentleDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (mood.present) {
      map['mood'] = Variable<int>(mood.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (sleep.present) {
      map['sleep'] = Variable<int>(sleep.value);
    }
    if (stress.present) {
      map['stress'] = Variable<int>(stress.value);
    }
    if (timeAvailable.present) {
      map['time_available'] = Variable<int>(timeAvailable.value);
    }
    if (barrierText.present) {
      map['barrier_text'] = Variable<String>(barrierText.value);
    }
    if (gentleDay.present) {
      map['gentle_day'] = Variable<bool>(gentleDay.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCheckInsCompanion(')
          ..write('uid: $uid, ')
          ..write('date: $date, ')
          ..write('mood: $mood, ')
          ..write('energy: $energy, ')
          ..write('sleep: $sleep, ')
          ..write('stress: $stress, ')
          ..write('timeAvailable: $timeAvailable, ')
          ..write('barrierText: $barrierText, ')
          ..write('gentleDay: $gentleDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _docPathMeta = const VerificationMeta(
    'docPath',
  );
  @override
  late final GeneratedColumn<String> docPath = GeneratedColumn<String>(
    'doc_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsMeta = const VerificationMeta('fields');
  @override
  late final GeneratedColumn<String> fields = GeneratedColumn<String>(
    'fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parkedMeta = const VerificationMeta('parked');
  @override
  late final GeneratedColumn<bool> parked = GeneratedColumn<bool>(
    'parked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("parked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    idempotencyKey,
    uid,
    kind,
    docPath,
    fields,
    revision,
    attempts,
    lastError,
    parked,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('doc_path')) {
      context.handle(
        _docPathMeta,
        docPath.isAcceptableOrUnknown(data['doc_path']!, _docPathMeta),
      );
    } else if (isInserting) {
      context.missing(_docPathMeta);
    }
    if (data.containsKey('fields')) {
      context.handle(
        _fieldsMeta,
        fields.isAcceptableOrUnknown(data['fields']!, _fieldsMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldsMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('parked')) {
      context.handle(
        _parkedMeta,
        parked.isAcceptableOrUnknown(data['parked']!, _parkedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      docPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_path'],
      )!,
      fields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      parked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}parked'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;
  final String idempotencyKey;
  final String uid;

  /// What the record is, e.g. `checkin` (for counts; never its content).
  final String kind;

  /// Firestore document path, e.g. `users/{uid}/checkins/2026-11-19`.
  final String docPath;

  /// The fields to write, as JSON. A null value removes the field on an
  /// update and is left out on a create.
  final String fields;

  /// Goes up each time the queued values are replaced, so a flush that sent
  /// an older revision does not remove the newer one.
  final int revision;
  final int attempts;

  /// Error code of the last failed attempt (a code only, never content).
  final String? lastError;

  /// The server refused the write (rules or validation): kept, but no longer
  /// retried automatically, so it can't block the rest of the queue.
  final bool parked;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OutboxEntry({
    required this.id,
    required this.idempotencyKey,
    required this.uid,
    required this.kind,
    required this.docPath,
    required this.fields,
    required this.revision,
    required this.attempts,
    this.lastError,
    required this.parked,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['uid'] = Variable<String>(uid);
    map['kind'] = Variable<String>(kind);
    map['doc_path'] = Variable<String>(docPath);
    map['fields'] = Variable<String>(fields);
    map['revision'] = Variable<int>(revision);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['parked'] = Variable<bool>(parked);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      idempotencyKey: Value(idempotencyKey),
      uid: Value(uid),
      kind: Value(kind),
      docPath: Value(docPath),
      fields: Value(fields),
      revision: Value(revision),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      parked: Value(parked),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      uid: serializer.fromJson<String>(json['uid']),
      kind: serializer.fromJson<String>(json['kind']),
      docPath: serializer.fromJson<String>(json['docPath']),
      fields: serializer.fromJson<String>(json['fields']),
      revision: serializer.fromJson<int>(json['revision']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      parked: serializer.fromJson<bool>(json['parked']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'uid': serializer.toJson<String>(uid),
      'kind': serializer.toJson<String>(kind),
      'docPath': serializer.toJson<String>(docPath),
      'fields': serializer.toJson<String>(fields),
      'revision': serializer.toJson<int>(revision),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'parked': serializer.toJson<bool>(parked),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OutboxEntry copyWith({
    int? id,
    String? idempotencyKey,
    String? uid,
    String? kind,
    String? docPath,
    String? fields,
    int? revision,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    bool? parked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutboxEntry(
    id: id ?? this.id,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    uid: uid ?? this.uid,
    kind: kind ?? this.kind,
    docPath: docPath ?? this.docPath,
    fields: fields ?? this.fields,
    revision: revision ?? this.revision,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    parked: parked ?? this.parked,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OutboxEntry copyWithCompanion(SyncOutboxCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      uid: data.uid.present ? data.uid.value : this.uid,
      kind: data.kind.present ? data.kind.value : this.kind,
      docPath: data.docPath.present ? data.docPath.value : this.docPath,
      fields: data.fields.present ? data.fields.value : this.fields,
      revision: data.revision.present ? data.revision.value : this.revision,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      parked: data.parked.present ? data.parked.value : this.parked,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('uid: $uid, ')
          ..write('kind: $kind, ')
          ..write('docPath: $docPath, ')
          ..write('fields: $fields, ')
          ..write('revision: $revision, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idempotencyKey,
    uid,
    kind,
    docPath,
    fields,
    revision,
    attempts,
    lastError,
    parked,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.idempotencyKey == this.idempotencyKey &&
          other.uid == this.uid &&
          other.kind == this.kind &&
          other.docPath == this.docPath &&
          other.fields == this.fields &&
          other.revision == this.revision &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.parked == this.parked &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> idempotencyKey;
  final Value<String> uid;
  final Value<String> kind;
  final Value<String> docPath;
  final Value<String> fields;
  final Value<int> revision;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<bool> parked;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.uid = const Value.absent(),
    this.kind = const Value.absent(),
    this.docPath = const Value.absent(),
    this.fields = const Value.absent(),
    this.revision = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String idempotencyKey,
    required String uid,
    required String kind,
    required String docPath,
    required String fields,
    this.revision = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : idempotencyKey = Value(idempotencyKey),
       uid = Value(uid),
       kind = Value(kind),
       docPath = Value(docPath),
       fields = Value(fields),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? idempotencyKey,
    Expression<String>? uid,
    Expression<String>? kind,
    Expression<String>? docPath,
    Expression<String>? fields,
    Expression<int>? revision,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<bool>? parked,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (uid != null) 'uid': uid,
      if (kind != null) 'kind': kind,
      if (docPath != null) 'doc_path': docPath,
      if (fields != null) 'fields': fields,
      if (revision != null) 'revision': revision,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (parked != null) 'parked': parked,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? idempotencyKey,
    Value<String>? uid,
    Value<String>? kind,
    Value<String>? docPath,
    Value<String>? fields,
    Value<int>? revision,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<bool>? parked,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      uid: uid ?? this.uid,
      kind: kind ?? this.kind,
      docPath: docPath ?? this.docPath,
      fields: fields ?? this.fields,
      revision: revision ?? this.revision,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      parked: parked ?? this.parked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (docPath.present) {
      map['doc_path'] = Variable<String>(docPath.value);
    }
    if (fields.present) {
      map['fields'] = Variable<String>(fields.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (parked.present) {
      map['parked'] = Variable<bool>(parked.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('uid: $uid, ')
          ..write('kind: $kind, ')
          ..write('docPath: $docPath, ')
          ..write('fields: $fields, ')
          ..write('revision: $revision, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $LocalCheckInsTable localCheckIns = $LocalCheckInsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localCheckIns,
    syncOutbox,
  ];
}

typedef $$LocalCheckInsTableCreateCompanionBuilder =
    LocalCheckInsCompanion Function({
      required String uid,
      required String date,
      required int mood,
      Value<int?> energy,
      Value<int?> sleep,
      Value<int?> stress,
      Value<int?> timeAvailable,
      Value<String?> barrierText,
      required bool gentleDay,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalCheckInsTableUpdateCompanionBuilder =
    LocalCheckInsCompanion Function({
      Value<String> uid,
      Value<String> date,
      Value<int> mood,
      Value<int?> energy,
      Value<int?> sleep,
      Value<int?> stress,
      Value<int?> timeAvailable,
      Value<String?> barrierText,
      Value<bool> gentleDay,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalCheckInsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sleep => $composableBuilder(
    column: $table.sleep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stress => $composableBuilder(
    column: $table.stress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeAvailable => $composableBuilder(
    column: $table.timeAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barrierText => $composableBuilder(
    column: $table.barrierText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get gentleDay => $composableBuilder(
    column: $table.gentleDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCheckInsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sleep => $composableBuilder(
    column: $table.sleep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stress => $composableBuilder(
    column: $table.stress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeAvailable => $composableBuilder(
    column: $table.timeAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barrierText => $composableBuilder(
    column: $table.barrierText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get gentleDay => $composableBuilder(
    column: $table.gentleDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCheckInsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<int> get sleep =>
      $composableBuilder(column: $table.sleep, builder: (column) => column);

  GeneratedColumn<int> get stress =>
      $composableBuilder(column: $table.stress, builder: (column) => column);

  GeneratedColumn<int> get timeAvailable => $composableBuilder(
    column: $table.timeAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barrierText => $composableBuilder(
    column: $table.barrierText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get gentleDay =>
      $composableBuilder(column: $table.gentleDay, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalCheckInsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalCheckInsTable,
          LocalCheckIn,
          $$LocalCheckInsTableFilterComposer,
          $$LocalCheckInsTableOrderingComposer,
          $$LocalCheckInsTableAnnotationComposer,
          $$LocalCheckInsTableCreateCompanionBuilder,
          $$LocalCheckInsTableUpdateCompanionBuilder,
          (
            LocalCheckIn,
            BaseReferences<_$LocalDatabase, $LocalCheckInsTable, LocalCheckIn>,
          ),
          LocalCheckIn,
          PrefetchHooks Function()
        > {
  $$LocalCheckInsTableTableManager(
    _$LocalDatabase db,
    $LocalCheckInsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> mood = const Value.absent(),
                Value<int?> energy = const Value.absent(),
                Value<int?> sleep = const Value.absent(),
                Value<int?> stress = const Value.absent(),
                Value<int?> timeAvailable = const Value.absent(),
                Value<String?> barrierText = const Value.absent(),
                Value<bool> gentleDay = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCheckInsCompanion(
                uid: uid,
                date: date,
                mood: mood,
                energy: energy,
                sleep: sleep,
                stress: stress,
                timeAvailable: timeAvailable,
                barrierText: barrierText,
                gentleDay: gentleDay,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                required String date,
                required int mood,
                Value<int?> energy = const Value.absent(),
                Value<int?> sleep = const Value.absent(),
                Value<int?> stress = const Value.absent(),
                Value<int?> timeAvailable = const Value.absent(),
                Value<String?> barrierText = const Value.absent(),
                required bool gentleDay,
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalCheckInsCompanion.insert(
                uid: uid,
                date: date,
                mood: mood,
                energy: energy,
                sleep: sleep,
                stress: stress,
                timeAvailable: timeAvailable,
                barrierText: barrierText,
                gentleDay: gentleDay,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCheckInsTable, LocalCheckIn>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalCheckInsTable,
                    LocalCheckIn
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalCheckInsTable,
      LocalCheckIn,
      $$LocalCheckInsTableFilterComposer,
      $$LocalCheckInsTableOrderingComposer,
      $$LocalCheckInsTableAnnotationComposer,
      $$LocalCheckInsTableCreateCompanionBuilder,
      $$LocalCheckInsTableUpdateCompanionBuilder,
      (
        LocalCheckIn,
        BaseReferences<_$LocalDatabase, $LocalCheckInsTable, LocalCheckIn>,
      ),
      LocalCheckIn,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  required String idempotencyKey,
  required String uid,
  required String kind,
  required String docPath,
  required String fields,
  Value<int> revision,
  Value<int> attempts,
  Value<String?> lastError,
  Value<bool> parked,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  Value<String> idempotencyKey,
  Value<String> uid,
  Value<String> kind,
  Value<String> docPath,
  Value<String> fields,
  Value<int> revision,
  Value<int> attempts,
  Value<String?> lastError,
  Value<bool> parked,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$LocalDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docPath => $composableBuilder(
    column: $table.docPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get parked => $composableBuilder(
    column: $table.parked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$LocalDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docPath => $composableBuilder(
    column: $table.docPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get parked => $composableBuilder(
    column: $table.parked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get docPath =>
      $composableBuilder(column: $table.docPath, builder: (column) => column);

  GeneratedColumn<String> get fields =>
      $composableBuilder(column: $table.fields, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get parked =>
      $composableBuilder(column: $table.parked, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SyncOutboxTable,
          OutboxEntry,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$LocalDatabase, $SyncOutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$LocalDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> docPath = const Value.absent(),
                Value<String> fields = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> parked = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                idempotencyKey: idempotencyKey,
                uid: uid,
                kind: kind,
                docPath: docPath,
                fields: fields,
                revision: revision,
                attempts: attempts,
                lastError: lastError,
                parked: parked,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String idempotencyKey,
                required String uid,
                required String kind,
                required String docPath,
                required String fields,
                Value<int> revision = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> parked = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => SyncOutboxCompanion.insert(
                id: id,
                idempotencyKey: idempotencyKey,
                uid: uid,
                kind: kind,
                docPath: docPath,
                fields: fields,
                revision: revision,
                attempts: attempts,
                lastError: lastError,
                parked: parked,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, OutboxEntry>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $SyncOutboxTable,
                    OutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SyncOutboxTable,
      OutboxEntry,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$LocalDatabase, $SyncOutboxTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$LocalCheckInsTableTableManager get localCheckIns =>
      $$LocalCheckInsTableTableManager(_db, _db.localCheckIns);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
}
