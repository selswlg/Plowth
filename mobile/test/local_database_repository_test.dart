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

    test('stores cached cards and memory states for offline review', () async {
      final updatedAt = DateTime.utc(2026, 4, 11, 10, 0);
      await repository.upsertCachedCard(
        id: 'card-1',
        sourceId: 'source-1',
        sourceTitle: 'Biology Notes',
        cardType: 'definition',
        question: 'What is ATP?',
        answer: 'Usable cellular energy.',
        difficulty: 3,
        isActive: true,
        tagsJson: '{"domain_hint":"exam"}',
        updatedAt: updatedAt,
      );
      await repository.upsertCachedMemoryState(
        cardId: 'card-1',
        stability: 1.5,
        difficulty: 4.0,
        retrievability: 0.9,
        reps: 2,
        lapses: 0,
        state: 'review',
        nextReviewAt: updatedAt.add(const Duration(days: 1)),
        lastReviewAt: updatedAt,
        updatedAt: updatedAt,
      );

      final card = await repository.getCachedCard('card-1');
      final memoryState = await repository.getCachedMemoryState('card-1');

      expect(card?.sourceTitle, 'Biology Notes');
      expect(card?.question, 'What is ATP?');
      expect(memoryState?.state, 'review');
      expect(memoryState?.reps, 2);
    });

    test('persists last sync timestamp and error state', () async {
      final timestamp = DateTime.utc(2026, 4, 11, 11, 30);

      await repository.saveLastSyncAt(timestamp);
      await repository.saveLastSyncError('Offline for now');

      expect(await repository.getLastSyncAt(), timestamp);
      expect(await repository.getLastSyncError(), 'Offline for now');

      await repository.saveLastSyncError(null);

      expect(await repository.getLastSyncError(), isNull);
    });
  });
}
