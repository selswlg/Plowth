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

@DriftDatabase(tables: [PendingSyncEvents, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

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

  Future<int> getPendingSyncEventCount() async {
    final countExpression = pendingSyncEvents.id.count();
    final query = selectOnly(pendingSyncEvents)..addColumns([countExpression]);
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'plowth.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
