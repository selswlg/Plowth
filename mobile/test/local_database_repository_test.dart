import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plowth_app/core/database/app_database.dart';
import 'package:plowth_app/core/database/local_database_repository.dart';

void main() {
  group('LocalDatabaseRepository', () {
    late AppDatabase database;
    late LocalDatabaseRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalDatabaseRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('stores session metadata', () async {
      await repository.saveSessionMetadata(
        deviceId: 'device-123',
        learningGoal: 'exam',
        onboardingComplete: true,
      );

      expect(await repository.getMetadataValue('device_id'), 'device-123');
      expect(await repository.getMetadataValue('learning_goal'), 'exam');
      expect(await repository.getMetadataValue('onboarding_complete'), 'true');
    });

    test('queues sync events in created order', () async {
      await repository.queueSyncEvent(
        id: 'evt-1',
        eventType: 'settings_update',
        eventPayload: '{"learning_goal":"exam"}',
        createdAt: DateTime.utc(2026, 4, 9, 0, 0, 1),
      );
      await repository.queueSyncEvent(
        id: 'evt-2',
        eventType: 'review',
        eventPayload: '{"card_id":"card-1"}',
        createdAt: DateTime.utc(2026, 4, 9, 0, 0, 2),
      );

      final queuedEvents = await repository.getQueuedSyncEvents();

      expect(await repository.getPendingSyncEventCount(), 2);
      expect(queuedEvents.map((event) => event.id), ['evt-1', 'evt-2']);
      expect(queuedEvents.map((event) => event.eventType), [
        'settings_update',
        'review',
      ]);
    });
  });
}
