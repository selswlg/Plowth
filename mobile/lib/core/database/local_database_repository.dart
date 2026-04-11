import 'app_database.dart';

class LocalDatabaseRepository {
  LocalDatabaseRepository({AppDatabase? database})
    : _database = database ?? _sharedDatabase;

  static final AppDatabase _sharedDatabase = AppDatabase();

  final AppDatabase _database;

  Future<void> saveSessionMetadata({
    required String deviceId,
    String? userId,
    String? learningGoal,
    bool? onboardingComplete,
  }) {
    return _database.transaction(() async {
      await _database.setMetadataValue(key: 'device_id', value: deviceId);

      if (userId != null && userId.isNotEmpty) {
        await _database.setMetadataValue(key: 'user_id', value: userId);
      }

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

  Future<void> clearUserScopedState() {
    return _database.transaction(() async {
      await _database.clearPendingSyncEvents();
      await _database.clearCachedStudyData();
      await _database.removeMetadataKeys(const [
        'last_sync_at',
        'last_sync_error',
        'learning_goal',
        'onboarding_complete',
        'user_id',
      ]);
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

  Future<void> removeQueuedSyncEvents(Iterable<String> ids) {
    return _database.removePendingSyncEvents(ids);
  }

  Future<void> markSyncEventFailed({
    required String id,
    required int retryCount,
    String? lastError,
  }) {
    return _database.updatePendingSyncEventFailure(
      id: id,
      retryCount: retryCount,
      lastError: lastError,
    );
  }

  Future<void> saveLastSyncAt(DateTime timestamp) {
    return _database.setMetadataValue(
      key: 'last_sync_at',
      value: timestamp.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> getLastSyncAt() async {
    final value = await _database.getMetadataValue('last_sync_at');
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> saveLastSyncError(String? message) {
    return _database.setMetadataValue(
      key: 'last_sync_error',
      value: message ?? '',
    );
  }

  Future<String?> getLastSyncError() async {
    final value = await _database.getMetadataValue('last_sync_error');
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
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
    required DateTime updatedAt,
  }) {
    return _database.upsertCachedCard(
      id: id,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      cardType: cardType,
      question: question,
      answer: answer,
      difficulty: difficulty,
      isActive: isActive,
      tagsJson: tagsJson,
      updatedAt: updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<CachedCard?> getCachedCard(String id) {
    return _database.getCachedCard(id);
  }

  Future<List<CachedCard>> getCachedCards({String? sourceId}) {
    return _database.getCachedCards(sourceId: sourceId);
  }

  Future<void> upsertCachedMemoryState({
    required String cardId,
    required double stability,
    required double difficulty,
    required double retrievability,
    required int reps,
    required int lapses,
    required String state,
    DateTime? nextReviewAt,
    DateTime? lastReviewAt,
    required DateTime updatedAt,
  }) {
    return _database.upsertCachedMemoryState(
      cardId: cardId,
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      reps: reps,
      lapses: lapses,
      state: state,
      nextReviewAt: nextReviewAt?.toUtc().millisecondsSinceEpoch,
      lastReviewAt: lastReviewAt?.toUtc().millisecondsSinceEpoch,
      updatedAt: updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<CachedMemoryState?> getCachedMemoryState(String cardId) {
    return _database.getCachedMemoryState(cardId);
  }

  Future<List<CachedMemoryState>> getCachedMemoryStates() {
    return _database.getCachedMemoryStates();
  }
}
