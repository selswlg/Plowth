// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PendingSyncEventsTable extends PendingSyncEvents
    with TableInfo<$PendingSyncEventsTable, PendingSyncEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventPayloadMeta = const VerificationMeta(
    'eventPayload',
  );
  @override
  late final GeneratedColumn<String> eventPayload = GeneratedColumn<String>(
    'event_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    eventPayload,
    createdAt,
    retryCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sync_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSyncEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('event_payload')) {
      context.handle(
        _eventPayloadMeta,
        eventPayload.isAcceptableOrUnknown(
          data['event_payload']!,
          _eventPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eventPayloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSyncEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSyncEvent(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      eventType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}event_type'],
          )!,
      eventPayload:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}event_payload'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}created_at'],
          )!,
      retryCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}retry_count'],
          )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingSyncEventsTable createAlias(String alias) {
    return $PendingSyncEventsTable(attachedDatabase, alias);
  }
}

class PendingSyncEvent extends DataClass
    implements Insertable<PendingSyncEvent> {
  final String id;
  final String eventType;
  final String eventPayload;
  final int createdAt;
  final int retryCount;
  final String? lastError;
  const PendingSyncEvent({
    required this.id,
    required this.eventType,
    required this.eventPayload,
    required this.createdAt,
    required this.retryCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_type'] = Variable<String>(eventType);
    map['event_payload'] = Variable<String>(eventPayload);
    map['created_at'] = Variable<int>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingSyncEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      eventPayload: Value(eventPayload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
    );
  }

  factory PendingSyncEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSyncEvent(
      id: serializer.fromJson<String>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      eventPayload: serializer.fromJson<String>(json['eventPayload']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventType': serializer.toJson<String>(eventType),
      'eventPayload': serializer.toJson<String>(eventPayload),
      'createdAt': serializer.toJson<int>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingSyncEvent copyWith({
    String? id,
    String? eventType,
    String? eventPayload,
    int? createdAt,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
  }) => PendingSyncEvent(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    eventPayload: eventPayload ?? this.eventPayload,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingSyncEvent copyWithCompanion(PendingSyncEventsCompanion data) {
    return PendingSyncEvent(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      eventPayload:
          data.eventPayload.present
              ? data.eventPayload.value
              : this.eventPayload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncEvent(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('eventPayload: $eventPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventType,
    eventPayload,
    createdAt,
    retryCount,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSyncEvent &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.eventPayload == this.eventPayload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class PendingSyncEventsCompanion extends UpdateCompanion<PendingSyncEvent> {
  final Value<String> id;
  final Value<String> eventType;
  final Value<String> eventPayload;
  final Value<int> createdAt;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const PendingSyncEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.eventPayload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingSyncEventsCompanion.insert({
    required String id,
    required String eventType,
    required String eventPayload,
    required int createdAt,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventType = Value(eventType),
       eventPayload = Value(eventPayload),
       createdAt = Value(createdAt);
  static Insertable<PendingSyncEvent> custom({
    Expression<String>? id,
    Expression<String>? eventType,
    Expression<String>? eventPayload,
    Expression<int>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (eventPayload != null) 'event_payload': eventPayload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingSyncEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventType,
    Value<String>? eventPayload,
    Value<int>? createdAt,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return PendingSyncEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      eventPayload: eventPayload ?? this.eventPayload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (eventPayload.present) {
      map['event_payload'] = Variable<String>(eventPayload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('eventPayload: $eventPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCardsTable extends CachedCards
    with TableInfo<$CachedCardsTable, CachedCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTitleMeta = const VerificationMeta(
    'sourceTitle',
  );
  @override
  late final GeneratedColumn<String> sourceTitle = GeneratedColumn<String>(
    'source_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardTypeMeta = const VerificationMeta(
    'cardType',
  );
  @override
  late final GeneratedColumn<String> cardType = GeneratedColumn<String>(
    'card_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    sourceTitle,
    cardType,
    question,
    answer,
    difficulty,
    isActive,
    tagsJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_title')) {
      context.handle(
        _sourceTitleMeta,
        sourceTitle.isAcceptableOrUnknown(
          data['source_title']!,
          _sourceTitleMeta,
        ),
      );
    }
    if (data.containsKey('card_type')) {
      context.handle(
        _cardTypeMeta,
        cardType.isAcceptableOrUnknown(data['card_type']!, _cardTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_cardTypeMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCard(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      sourceTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_title'],
      ),
      cardType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}card_type'],
          )!,
      question:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}question'],
          )!,
      answer:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}answer'],
          )!,
      difficulty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}difficulty'],
          )!,
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $CachedCardsTable createAlias(String alias) {
    return $CachedCardsTable(attachedDatabase, alias);
  }
}

class CachedCard extends DataClass implements Insertable<CachedCard> {
  final String id;
  final String sourceId;
  final String? sourceTitle;
  final String cardType;
  final String question;
  final String answer;
  final int difficulty;
  final bool isActive;
  final String? tagsJson;
  final int updatedAt;
  const CachedCard({
    required this.id,
    required this.sourceId,
    this.sourceTitle,
    required this.cardType,
    required this.question,
    required this.answer,
    required this.difficulty,
    required this.isActive,
    this.tagsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || sourceTitle != null) {
      map['source_title'] = Variable<String>(sourceTitle);
    }
    map['card_type'] = Variable<String>(cardType);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['difficulty'] = Variable<int>(difficulty);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CachedCardsCompanion toCompanion(bool nullToAbsent) {
    return CachedCardsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      sourceTitle:
          sourceTitle == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceTitle),
      cardType: Value(cardType),
      question: Value(question),
      answer: Value(answer),
      difficulty: Value(difficulty),
      isActive: Value(isActive),
      tagsJson:
          tagsJson == null && nullToAbsent
              ? const Value.absent()
              : Value(tagsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCard(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceTitle: serializer.fromJson<String?>(json['sourceTitle']),
      cardType: serializer.fromJson<String>(json['cardType']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      difficulty: serializer.fromJson<int>(json['difficulty']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceTitle': serializer.toJson<String?>(sourceTitle),
      'cardType': serializer.toJson<String>(cardType),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'difficulty': serializer.toJson<int>(difficulty),
      'isActive': serializer.toJson<bool>(isActive),
      'tagsJson': serializer.toJson<String?>(tagsJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CachedCard copyWith({
    String? id,
    String? sourceId,
    Value<String?> sourceTitle = const Value.absent(),
    String? cardType,
    String? question,
    String? answer,
    int? difficulty,
    bool? isActive,
    Value<String?> tagsJson = const Value.absent(),
    int? updatedAt,
  }) => CachedCard(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    sourceTitle: sourceTitle.present ? sourceTitle.value : this.sourceTitle,
    cardType: cardType ?? this.cardType,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    difficulty: difficulty ?? this.difficulty,
    isActive: isActive ?? this.isActive,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedCard copyWithCompanion(CachedCardsCompanion data) {
    return CachedCard(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceTitle:
          data.sourceTitle.present ? data.sourceTitle.value : this.sourceTitle,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCard(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceTitle: $sourceTitle, ')
          ..write('cardType: $cardType, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('difficulty: $difficulty, ')
          ..write('isActive: $isActive, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    sourceTitle,
    cardType,
    question,
    answer,
    difficulty,
    isActive,
    tagsJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCard &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.sourceTitle == this.sourceTitle &&
          other.cardType == this.cardType &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.difficulty == this.difficulty &&
          other.isActive == this.isActive &&
          other.tagsJson == this.tagsJson &&
          other.updatedAt == this.updatedAt);
}

class CachedCardsCompanion extends UpdateCompanion<CachedCard> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String?> sourceTitle;
  final Value<String> cardType;
  final Value<String> question;
  final Value<String> answer;
  final Value<int> difficulty;
  final Value<bool> isActive;
  final Value<String?> tagsJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CachedCardsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceTitle = const Value.absent(),
    this.cardType = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.isActive = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCardsCompanion.insert({
    required String id,
    required String sourceId,
    this.sourceTitle = const Value.absent(),
    required String cardType,
    required String question,
    required String answer,
    required int difficulty,
    required bool isActive,
    this.tagsJson = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       cardType = Value(cardType),
       question = Value(question),
       answer = Value(answer),
       difficulty = Value(difficulty),
       isActive = Value(isActive),
       updatedAt = Value(updatedAt);
  static Insertable<CachedCard> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? sourceTitle,
    Expression<String>? cardType,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<int>? difficulty,
    Expression<bool>? isActive,
    Expression<String>? tagsJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceTitle != null) 'source_title': sourceTitle,
      if (cardType != null) 'card_type': cardType,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (difficulty != null) 'difficulty': difficulty,
      if (isActive != null) 'is_active': isActive,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String?>? sourceTitle,
    Value<String>? cardType,
    Value<String>? question,
    Value<String>? answer,
    Value<int>? difficulty,
    Value<bool>? isActive,
    Value<String?>? tagsJson,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedCardsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      cardType: cardType ?? this.cardType,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      tagsJson: tagsJson ?? this.tagsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceTitle.present) {
      map['source_title'] = Variable<String>(sourceTitle.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(cardType.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCardsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceTitle: $sourceTitle, ')
          ..write('cardType: $cardType, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('difficulty: $difficulty, ')
          ..write('isActive: $isActive, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMemoryStatesTable extends CachedMemoryStates
    with TableInfo<$CachedMemoryStatesTable, CachedMemoryState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMemoryStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _retrievabilityMeta = const VerificationMeta(
    'retrievability',
  );
  @override
  late final GeneratedColumn<double> retrievability = GeneratedColumn<double>(
    'retrievability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<int> nextReviewAt = GeneratedColumn<int>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewAtMeta = const VerificationMeta(
    'lastReviewAt',
  );
  @override
  late final GeneratedColumn<int> lastReviewAt = GeneratedColumn<int>(
    'last_review_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cardId,
    stability,
    difficulty,
    retrievability,
    reps,
    lapses,
    state,
    nextReviewAt,
    lastReviewAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_memory_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMemoryState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('retrievability')) {
      context.handle(
        _retrievabilityMeta,
        retrievability.isAcceptableOrUnknown(
          data['retrievability']!,
          _retrievabilityMeta,
        ),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('last_review_at')) {
      context.handle(
        _lastReviewAtMeta,
        lastReviewAt.isAcceptableOrUnknown(
          data['last_review_at']!,
          _lastReviewAtMeta,
        ),
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
  Set<GeneratedColumn> get $primaryKey => {cardId};
  @override
  CachedMemoryState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMemoryState(
      cardId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}card_id'],
          )!,
      stability:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}stability'],
          )!,
      difficulty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}difficulty'],
          )!,
      retrievability:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}retrievability'],
          )!,
      reps:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}reps'],
          )!,
      lapses:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}lapses'],
          )!,
      state:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}state'],
          )!,
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_review_at'],
      ),
      lastReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_review_at'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $CachedMemoryStatesTable createAlias(String alias) {
    return $CachedMemoryStatesTable(attachedDatabase, alias);
  }
}

class CachedMemoryState extends DataClass
    implements Insertable<CachedMemoryState> {
  final String cardId;
  final double stability;
  final double difficulty;
  final double retrievability;
  final int reps;
  final int lapses;
  final String state;
  final int? nextReviewAt;
  final int? lastReviewAt;
  final int updatedAt;
  const CachedMemoryState({
    required this.cardId,
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.reps,
    required this.lapses,
    required this.state,
    this.nextReviewAt,
    this.lastReviewAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<String>(cardId);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['retrievability'] = Variable<double>(retrievability);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<int>(nextReviewAt);
    }
    if (!nullToAbsent || lastReviewAt != null) {
      map['last_review_at'] = Variable<int>(lastReviewAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CachedMemoryStatesCompanion toCompanion(bool nullToAbsent) {
    return CachedMemoryStatesCompanion(
      cardId: Value(cardId),
      stability: Value(stability),
      difficulty: Value(difficulty),
      retrievability: Value(retrievability),
      reps: Value(reps),
      lapses: Value(lapses),
      state: Value(state),
      nextReviewAt:
          nextReviewAt == null && nullToAbsent
              ? const Value.absent()
              : Value(nextReviewAt),
      lastReviewAt:
          lastReviewAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastReviewAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedMemoryState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMemoryState(
      cardId: serializer.fromJson<String>(json['cardId']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      retrievability: serializer.fromJson<double>(json['retrievability']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      state: serializer.fromJson<String>(json['state']),
      nextReviewAt: serializer.fromJson<int?>(json['nextReviewAt']),
      lastReviewAt: serializer.fromJson<int?>(json['lastReviewAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<String>(cardId),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'retrievability': serializer.toJson<double>(retrievability),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'state': serializer.toJson<String>(state),
      'nextReviewAt': serializer.toJson<int?>(nextReviewAt),
      'lastReviewAt': serializer.toJson<int?>(lastReviewAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CachedMemoryState copyWith({
    String? cardId,
    double? stability,
    double? difficulty,
    double? retrievability,
    int? reps,
    int? lapses,
    String? state,
    Value<int?> nextReviewAt = const Value.absent(),
    Value<int?> lastReviewAt = const Value.absent(),
    int? updatedAt,
  }) => CachedMemoryState(
    cardId: cardId ?? this.cardId,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    retrievability: retrievability ?? this.retrievability,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    state: state ?? this.state,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
    lastReviewAt: lastReviewAt.present ? lastReviewAt.value : this.lastReviewAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedMemoryState copyWithCompanion(CachedMemoryStatesCompanion data) {
    return CachedMemoryState(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      retrievability:
          data.retrievability.present
              ? data.retrievability.value
              : this.retrievability,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      state: data.state.present ? data.state.value : this.state,
      nextReviewAt:
          data.nextReviewAt.present
              ? data.nextReviewAt.value
              : this.nextReviewAt,
      lastReviewAt:
          data.lastReviewAt.present
              ? data.lastReviewAt.value
              : this.lastReviewAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMemoryState(')
          ..write('cardId: $cardId, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('retrievability: $retrievability, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('state: $state, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('lastReviewAt: $lastReviewAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    stability,
    difficulty,
    retrievability,
    reps,
    lapses,
    state,
    nextReviewAt,
    lastReviewAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMemoryState &&
          other.cardId == this.cardId &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.retrievability == this.retrievability &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.state == this.state &&
          other.nextReviewAt == this.nextReviewAt &&
          other.lastReviewAt == this.lastReviewAt &&
          other.updatedAt == this.updatedAt);
}

class CachedMemoryStatesCompanion extends UpdateCompanion<CachedMemoryState> {
  final Value<String> cardId;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<double> retrievability;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<String> state;
  final Value<int?> nextReviewAt;
  final Value<int?> lastReviewAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CachedMemoryStatesCompanion({
    this.cardId = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.state = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.lastReviewAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMemoryStatesCompanion.insert({
    required String cardId,
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.state = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.lastReviewAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       updatedAt = Value(updatedAt);
  static Insertable<CachedMemoryState> custom({
    Expression<String>? cardId,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<double>? retrievability,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<String>? state,
    Expression<int>? nextReviewAt,
    Expression<int>? lastReviewAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (retrievability != null) 'retrievability': retrievability,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (state != null) 'state': state,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (lastReviewAt != null) 'last_review_at': lastReviewAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMemoryStatesCompanion copyWith({
    Value<String>? cardId,
    Value<double>? stability,
    Value<double>? difficulty,
    Value<double>? retrievability,
    Value<int>? reps,
    Value<int>? lapses,
    Value<String>? state,
    Value<int?>? nextReviewAt,
    Value<int?>? lastReviewAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedMemoryStatesCompanion(
      cardId: cardId ?? this.cardId,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      state: state ?? this.state,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (retrievability.present) {
      map['retrievability'] = Variable<double>(retrievability.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<int>(nextReviewAt.value);
    }
    if (lastReviewAt.present) {
      map['last_review_at'] = Variable<int>(lastReviewAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMemoryStatesCompanion(')
          ..write('cardId: $cardId, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('retrievability: $retrievability, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('state: $state, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('lastReviewAt: $lastReviewAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PendingSyncEventsTable pendingSyncEvents =
      $PendingSyncEventsTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  late final $CachedCardsTable cachedCards = $CachedCardsTable(this);
  late final $CachedMemoryStatesTable cachedMemoryStates =
      $CachedMemoryStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pendingSyncEvents,
    syncMetadata,
    cachedCards,
    cachedMemoryStates,
  ];
}

typedef $$PendingSyncEventsTableCreateCompanionBuilder =
    PendingSyncEventsCompanion Function({
      required String id,
      required String eventType,
      required String eventPayload,
      required int createdAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$PendingSyncEventsTableUpdateCompanionBuilder =
    PendingSyncEventsCompanion Function({
      Value<String> id,
      Value<String> eventType,
      Value<String> eventPayload,
      Value<int> createdAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$PendingSyncEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSyncEventsTable> {
  $$PendingSyncEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventPayload => $composableBuilder(
    column: $table.eventPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingSyncEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSyncEventsTable> {
  $$PendingSyncEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventPayload => $composableBuilder(
    column: $table.eventPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSyncEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSyncEventsTable> {
  $$PendingSyncEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get eventPayload => $composableBuilder(
    column: $table.eventPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingSyncEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSyncEventsTable,
          PendingSyncEvent,
          $$PendingSyncEventsTableFilterComposer,
          $$PendingSyncEventsTableOrderingComposer,
          $$PendingSyncEventsTableAnnotationComposer,
          $$PendingSyncEventsTableCreateCompanionBuilder,
          $$PendingSyncEventsTableUpdateCompanionBuilder,
          (
            PendingSyncEvent,
            BaseReferences<
              _$AppDatabase,
              $PendingSyncEventsTable,
              PendingSyncEvent
            >,
          ),
          PendingSyncEvent,
          PrefetchHooks Function()
        > {
  $$PendingSyncEventsTableTableManager(
    _$AppDatabase db,
    $PendingSyncEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PendingSyncEventsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$PendingSyncEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$PendingSyncEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> eventPayload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingSyncEventsCompanion(
                id: id,
                eventType: eventType,
                eventPayload: eventPayload,
                createdAt: createdAt,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventType,
                required String eventPayload,
                required int createdAt,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingSyncEventsCompanion.insert(
                id: id,
                eventType: eventType,
                eventPayload: eventPayload,
                createdAt: createdAt,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingSyncEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSyncEventsTable,
      PendingSyncEvent,
      $$PendingSyncEventsTableFilterComposer,
      $$PendingSyncEventsTableOrderingComposer,
      $$PendingSyncEventsTableAnnotationComposer,
      $$PendingSyncEventsTableCreateCompanionBuilder,
      $$PendingSyncEventsTableUpdateCompanionBuilder,
      (
        PendingSyncEvent,
        BaseReferences<
          _$AppDatabase,
          $PendingSyncEventsTable,
          PendingSyncEvent
        >,
      ),
      PendingSyncEvent,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;
typedef $$CachedCardsTableCreateCompanionBuilder =
    CachedCardsCompanion Function({
      required String id,
      required String sourceId,
      Value<String?> sourceTitle,
      required String cardType,
      required String question,
      required String answer,
      required int difficulty,
      required bool isActive,
      Value<String?> tagsJson,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CachedCardsTableUpdateCompanionBuilder =
    CachedCardsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String?> sourceTitle,
      Value<String> cardType,
      Value<String> question,
      Value<String> answer,
      Value<int> difficulty,
      Value<bool> isActive,
      Value<String?> tagsJson,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CachedCardsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCardsTable> {
  $$CachedCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCardsTable> {
  $$CachedCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCardsTable> {
  $$CachedCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceTitle => $composableBuilder(
    column: $table.sourceTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCardsTable,
          CachedCard,
          $$CachedCardsTableFilterComposer,
          $$CachedCardsTableOrderingComposer,
          $$CachedCardsTableAnnotationComposer,
          $$CachedCardsTableCreateCompanionBuilder,
          $$CachedCardsTableUpdateCompanionBuilder,
          (
            CachedCard,
            BaseReferences<_$AppDatabase, $CachedCardsTable, CachedCard>,
          ),
          CachedCard,
          PrefetchHooks Function()
        > {
  $$CachedCardsTableTableManager(_$AppDatabase db, $CachedCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CachedCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CachedCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$CachedCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> sourceTitle = const Value.absent(),
                Value<String> cardType = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCardsCompanion(
                id: id,
                sourceId: sourceId,
                sourceTitle: sourceTitle,
                cardType: cardType,
                question: question,
                answer: answer,
                difficulty: difficulty,
                isActive: isActive,
                tagsJson: tagsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                Value<String?> sourceTitle = const Value.absent(),
                required String cardType,
                required String question,
                required String answer,
                required int difficulty,
                required bool isActive,
                Value<String?> tagsJson = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCardsCompanion.insert(
                id: id,
                sourceId: sourceId,
                sourceTitle: sourceTitle,
                cardType: cardType,
                question: question,
                answer: answer,
                difficulty: difficulty,
                isActive: isActive,
                tagsJson: tagsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCardsTable,
      CachedCard,
      $$CachedCardsTableFilterComposer,
      $$CachedCardsTableOrderingComposer,
      $$CachedCardsTableAnnotationComposer,
      $$CachedCardsTableCreateCompanionBuilder,
      $$CachedCardsTableUpdateCompanionBuilder,
      (
        CachedCard,
        BaseReferences<_$AppDatabase, $CachedCardsTable, CachedCard>,
      ),
      CachedCard,
      PrefetchHooks Function()
    >;
typedef $$CachedMemoryStatesTableCreateCompanionBuilder =
    CachedMemoryStatesCompanion Function({
      required String cardId,
      Value<double> stability,
      Value<double> difficulty,
      Value<double> retrievability,
      Value<int> reps,
      Value<int> lapses,
      Value<String> state,
      Value<int?> nextReviewAt,
      Value<int?> lastReviewAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CachedMemoryStatesTableUpdateCompanionBuilder =
    CachedMemoryStatesCompanion Function({
      Value<String> cardId,
      Value<double> stability,
      Value<double> difficulty,
      Value<double> retrievability,
      Value<int> reps,
      Value<int> lapses,
      Value<String> state,
      Value<int?> nextReviewAt,
      Value<int?> lastReviewAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CachedMemoryStatesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMemoryStatesTable> {
  $$CachedMemoryStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retrievability => $composableBuilder(
    column: $table.retrievability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMemoryStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMemoryStatesTable> {
  $$CachedMemoryStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retrievability => $composableBuilder(
    column: $table.retrievability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMemoryStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMemoryStatesTable> {
  $$CachedMemoryStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get retrievability => $composableBuilder(
    column: $table.retrievability,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedMemoryStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMemoryStatesTable,
          CachedMemoryState,
          $$CachedMemoryStatesTableFilterComposer,
          $$CachedMemoryStatesTableOrderingComposer,
          $$CachedMemoryStatesTableAnnotationComposer,
          $$CachedMemoryStatesTableCreateCompanionBuilder,
          $$CachedMemoryStatesTableUpdateCompanionBuilder,
          (
            CachedMemoryState,
            BaseReferences<
              _$AppDatabase,
              $CachedMemoryStatesTable,
              CachedMemoryState
            >,
          ),
          CachedMemoryState,
          PrefetchHooks Function()
        > {
  $$CachedMemoryStatesTableTableManager(
    _$AppDatabase db,
    $CachedMemoryStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CachedMemoryStatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$CachedMemoryStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CachedMemoryStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cardId = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> retrievability = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> nextReviewAt = const Value.absent(),
                Value<int?> lastReviewAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMemoryStatesCompanion(
                cardId: cardId,
                stability: stability,
                difficulty: difficulty,
                retrievability: retrievability,
                reps: reps,
                lapses: lapses,
                state: state,
                nextReviewAt: nextReviewAt,
                lastReviewAt: lastReviewAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardId,
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> retrievability = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> nextReviewAt = const Value.absent(),
                Value<int?> lastReviewAt = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedMemoryStatesCompanion.insert(
                cardId: cardId,
                stability: stability,
                difficulty: difficulty,
                retrievability: retrievability,
                reps: reps,
                lapses: lapses,
                state: state,
                nextReviewAt: nextReviewAt,
                lastReviewAt: lastReviewAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMemoryStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMemoryStatesTable,
      CachedMemoryState,
      $$CachedMemoryStatesTableFilterComposer,
      $$CachedMemoryStatesTableOrderingComposer,
      $$CachedMemoryStatesTableAnnotationComposer,
      $$CachedMemoryStatesTableCreateCompanionBuilder,
      $$CachedMemoryStatesTableUpdateCompanionBuilder,
      (
        CachedMemoryState,
        BaseReferences<
          _$AppDatabase,
          $CachedMemoryStatesTable,
          CachedMemoryState
        >,
      ),
      CachedMemoryState,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingSyncEventsTableTableManager get pendingSyncEvents =>
      $$PendingSyncEventsTableTableManager(_db, _db.pendingSyncEvents);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
  $$CachedCardsTableTableManager get cachedCards =>
      $$CachedCardsTableTableManager(_db, _db.cachedCards);
  $$CachedMemoryStatesTableTableManager get cachedMemoryStates =>
      $$CachedMemoryStatesTableTableManager(_db, _db.cachedMemoryStates);
}
