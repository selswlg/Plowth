import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class PendingSyncEvents extends Table {
  TextColumn get id => text()();

  TextColumn get eventType => text()();

  TextColumn get eventPayload => text()();

  IntColumn get createdAt => integer()();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class CachedCards extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId => text()();

  TextColumn get sourceTitle => text().nullable()();

  TextColumn get cardType => text()();

  TextColumn get question => text()();

  TextColumn get answer => text()();

  IntColumn get difficulty => integer()();

  BoolColumn get isActive => boolean()();

  TextColumn get tagsJson => text().nullable()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CachedMemoryStates extends Table {
  TextColumn get cardId => text()();

  RealColumn get stability => real().withDefault(const Constant(0))();

  RealColumn get difficulty => real().withDefault(const Constant(0))();

  RealColumn get retrievability => real().withDefault(const Constant(1))();

  IntColumn get reps => integer().withDefault(const Constant(0))();

  IntColumn get lapses => integer().withDefault(const Constant(0))();

  TextColumn get state => text().withDefault(const Constant('new'))();

  IntColumn get nextReviewAt => integer().nullable()();

  IntColumn get lastReviewAt => integer().nullable()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {cardId};
}

@DriftDatabase(
  tables: [PendingSyncEvents, SyncMetadata, CachedCards, CachedMemoryStates],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(cachedCards);
        await migrator.createTable(cachedMemoryStates);
      }
    },
  );

  Future<void> setMetadataValue({required String key, required String value}) {
    return into(syncMetadata).insertOnConflictUpdate(
      SyncMetadataCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<String?> getMetadataValue(String key) async {
    final row =
        await (select(syncMetadata)
          ..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> addPendingSyncEvent({
    required String id,
    required String eventType,
    required String eventPayload,
    required int createdAt,
    int retryCount = 0,
    String? lastError,
  }) {
    return into(pendingSyncEvents).insert(
      PendingSyncEventsCompanion.insert(
        id: id,
        eventType: eventType,
        eventPayload: eventPayload,
        createdAt: createdAt,
        retryCount: Value(retryCount),
        lastError: Value(lastError),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<PendingSyncEvent>> getQueuedSyncEvents() {
    return (select(pendingSyncEvents)
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])).get();
  }

  Future<void> clearPendingSyncEvents() {
    return delete(pendingSyncEvents).go();
  }

  Future<void> removePendingSyncEvents(Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (delete(pendingSyncEvents)
      ..where((table) => table.id.isIn(ids.toList()))).go();
  }

  Future<void> updatePendingSyncEventFailure({
    required String id,
    required int retryCount,
    String? lastError,
  }) {
    return (update(pendingSyncEvents)
      ..where((table) => table.id.equals(id))).write(
      PendingSyncEventsCompanion(
        retryCount: Value(retryCount),
        lastError: Value(lastError),
      ),
    );
  }

  Future<int> getPendingSyncEventCount() async {
    final countExpression = pendingSyncEvents.id.count();
    final query = selectOnly(pendingSyncEvents)..addColumns([countExpression]);
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> removeMetadataKeys(Iterable<String> keys) async {
    if (keys.isEmpty) {
      return;
    }
    await (delete(syncMetadata)
      ..where((table) => table.key.isIn(keys.toList()))).go();
  }

  Future<void> upsertCachedCard({
    required String id,
    required String sourceId,
    String? sourceTitle,
    required String cardType,
    required String question,
    required String answer,
    required int difficulty,
    required bool isActive,
    String? tagsJson,
    required int updatedAt,
  }) {
    return into(cachedCards).insertOnConflictUpdate(
      CachedCardsCompanion(
        id: Value(id),
        sourceId: Value(sourceId),
        sourceTitle: Value(sourceTitle),
        cardType: Value(cardType),
        question: Value(question),
        answer: Value(answer),
        difficulty: Value(difficulty),
        isActive: Value(isActive),
        tagsJson: Value(tagsJson),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<CachedCard?> getCachedCard(String id) {
    return (select(cachedCards)
      ..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<List<CachedCard>> getCachedCards({String? sourceId}) {
    final query = select(cachedCards)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (sourceId != null) {
      query.where((table) => table.sourceId.equals(sourceId));
    }
    return query.get();
  }

  Future<void> upsertCachedMemoryState({
    required String cardId,
    required double stability,
    required double difficulty,
    required double retrievability,
    required int reps,
    required int lapses,
    required String state,
    int? nextReviewAt,
    int? lastReviewAt,
    required int updatedAt,
  }) {
    return into(cachedMemoryStates).insertOnConflictUpdate(
      CachedMemoryStatesCompanion(
        cardId: Value(cardId),
        stability: Value(stability),
        difficulty: Value(difficulty),
        retrievability: Value(retrievability),
        reps: Value(reps),
        lapses: Value(lapses),
        state: Value(state),
        nextReviewAt: Value(nextReviewAt),
        lastReviewAt: Value(lastReviewAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<CachedMemoryState?> getCachedMemoryState(String cardId) {
    return (select(cachedMemoryStates)
      ..where((table) => table.cardId.equals(cardId))).getSingleOrNull();
  }

  Future<List<CachedMemoryState>> getCachedMemoryStates() {
    return select(cachedMemoryStates).get();
  }

  Future<void> clearCachedStudyData() async {
    await delete(cachedMemoryStates).go();
    await delete(cachedCards).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'plowth.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
