import 'app_database.dart';

class LocalDatabaseRepository {
  LocalDatabaseRepository({AppDatabase? database})
    : _database = database ?? _sharedDatabase;

  static final AppDatabase _sharedDatabase = AppDatabase();

  final AppDatabase _database;

  Future<void> saveSessionMetadata({
    required String deviceId,
    String? learningGoal,
    bool? onboardingComplete,
  }) {
    return _database.transaction(() async {
      await _database.setMetadataValue(key: 'device_id', value: deviceId);

      if (learningGoal != null && learningGoal.isNotEmpty) {
        await _database.setMetadataValue(
          key: 'learning_goal',
          value: learningGoal,
        );
      }

      if (onboardingComplete != null) {
        await _database.setMetadataValue(
          key: 'onboarding_complete',
          value: onboardingComplete.toString(),
        );
      }
    });
  }

  Future<void> queueSyncEvent({
    required String id,
    required String eventType,
    required String eventPayload,
    DateTime? createdAt,
  }) {
    return _database.addPendingSyncEvent(
      id: id,
      eventType: eventType,
      eventPayload: eventPayload,
      createdAt: (createdAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
    );
  }

  Future<int> getPendingSyncEventCount() {
    return _database.getPendingSyncEventCount();
  }

  Future<String?> getMetadataValue(String key) {
    return _database.getMetadataValue(key);
  }

  Future<List<PendingSyncEvent>> getQueuedSyncEvents() {
    return _database.getQueuedSyncEvents();
  }
}
