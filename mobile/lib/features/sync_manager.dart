import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';
import '../core/database/local_database_repository.dart';
import 'auth/auth_session.dart';

enum SyncStatusPhase { idle, pending, syncing, error, synced }

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.phase,
    required this.pendingCount,
    required this.lastSyncAt,
    required this.lastError,
  });

  const SyncStatusSnapshot.initial()
    : phase = SyncStatusPhase.idle,
      pendingCount = 0,
      lastSyncAt = null,
      lastError = null;

  final SyncStatusPhase phase;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final String? lastError;

  String get label {
    switch (phase) {
      case SyncStatusPhase.syncing:
        return pendingCount > 0
            ? 'Syncing $pendingCount pending changes'
            : 'Syncing with server';
      case SyncStatusPhase.pending:
        return pendingCount > 0
            ? '$pendingCount changes waiting to sync'
            : 'Waiting to sync';
      case SyncStatusPhase.error:
        return lastError ?? 'Sync needs attention';
      case SyncStatusPhase.synced:
        if (lastSyncAt == null) {
          return 'All changes synced';
        }
        return 'Last synced ${_formatRelative(lastSyncAt!)}';
      case SyncStatusPhase.idle:
        return 'Sync idle';
    }
  }

  bool get showRetry =>
      phase == SyncStatusPhase.error || phase == SyncStatusPhase.pending;

  static String _formatRelative(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toLocal());
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class SyncManager {
  SyncManager({
    Dio? dio,
    LocalDatabaseRepository? localDatabaseRepository,
    Future<String> Function(Dio dio)? authorizeSession,
    Future<bool> Function(Dio dio)? reachabilityProbe,
    this.syncInterval = const Duration(seconds: 20),
    this.connectivityProbeInterval = const Duration(seconds: 5),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: ApiConfig.baseUrl,
               connectTimeout: const Duration(seconds: 10),
               sendTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               headers: const {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ),
       _localDatabaseRepository =
           localDatabaseRepository ?? LocalDatabaseRepository(),
       _authorizeSession = authorizeSession ?? AuthSession.authorize,
       _reachabilityProbe = reachabilityProbe ?? _defaultReachabilityProbe;

  static final SyncManager shared = SyncManager();

  static const int maxRetryCount = 5;

  final Dio _dio;
  final LocalDatabaseRepository _localDatabaseRepository;
  final Future<String> Function(Dio dio) _authorizeSession;
  final Future<bool> Function(Dio dio) _reachabilityProbe;
  final Duration syncInterval;
  final Duration connectivityProbeInterval;
  final ValueNotifier<SyncStatusSnapshot> status = ValueNotifier(
    const SyncStatusSnapshot.initial(),
  );

  Timer? _timer;
  Timer? _connectivityTimer;
  bool _started = false;
  bool _isSyncing = false;

  @visibleForTesting
  bool get connectivityMonitoringActive => _connectivityTimer != null;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await refreshStatus();
    _timer = Timer.periodic(
      syncInterval,
      (_) => unawaited(syncNow(reason: 'interval')),
    );
    unawaited(syncNow(reason: 'startup'));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopConnectivityMonitoring();
    _started = false;
  }

  Future<void> registerPendingWork({bool syncImmediately = true}) async {
    await refreshStatus(preferredPhase: SyncStatusPhase.pending);
    if (syncImmediately) {
      unawaited(syncNow(reason: 'pending-work'));
    }
  }

  Future<void> refreshStatus({SyncStatusPhase? preferredPhase}) async {
    final pendingCount =
        await _localDatabaseRepository.getPendingSyncEventCount();
    final lastSyncAt = await _localDatabaseRepository.getLastSyncAt();
    final lastError = await _localDatabaseRepository.getLastSyncError();
    status.value = SyncStatusSnapshot(
      phase:
          preferredPhase ??
          (pendingCount > 0 ? SyncStatusPhase.pending : SyncStatusPhase.synced),
      pendingCount: pendingCount,
      lastSyncAt: lastSyncAt,
      lastError: lastError,
    );
  }

  Future<void> syncNow({String reason = 'manual'}) async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;
    var queuedEvents = await _localDatabaseRepository.getQueuedSyncEvents();
    final pendingCount = queuedEvents.length;
    final deviceId = await _localDatabaseRepository.getMetadataValue(
      'device_id',
    );

    status.value = SyncStatusSnapshot(
      phase: SyncStatusPhase.syncing,
      pendingCount: pendingCount,
      lastSyncAt: await _localDatabaseRepository.getLastSyncAt(),
      lastError: null,
    );

    try {
      if (deviceId == null || deviceId.isEmpty) {
        throw const AuthSessionException(
          'No device identity is stored locally.',
        );
      }

      debugPrint(
        'SyncManager.syncNow reason=$reason start pending=$pendingCount deviceId=$deviceId',
      );
      await _authorizeSession(_dio);

      String? pushErrorMessage;
      if (queuedEvents.isNotEmpty) {
        final response = await _dio.post<Map<String, dynamic>>(
          '/sync/push',
          data: {
            'device_id': deviceId,
            'events':
                queuedEvents
                    .map(
                      (event) => {
                        'client_event_id': event.id,
                        'event_type': event.eventType,
                        'event_payload': jsonDecode(event.eventPayload),
                        'client_timestamp':
                            DateTime.fromMillisecondsSinceEpoch(
                              event.createdAt,
                              isUtc: true,
                            ).toIso8601String(),
                      },
                    )
                    .toList(),
          },
        );
        pushErrorMessage = await _applyPushResponse(
          response.data ?? const <String, dynamic>{},
          queuedEvents,
        );
        queuedEvents = await _localDatabaseRepository.getQueuedSyncEvents();
      }

      final pullResponse = await _dio.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {
          'device_id': deviceId,
          if (await _localDatabaseRepository.getLastSyncAt() != null)
            'since':
                (await _localDatabaseRepository.getLastSyncAt())!
                    .toIso8601String(),
        },
      );
      await _applyPullResponse(pullResponse.data ?? const <String, dynamic>{});
      _stopConnectivityMonitoring();
      final remainingPendingCount =
          await _localDatabaseRepository.getPendingSyncEventCount();
      if (pushErrorMessage == null || pushErrorMessage.isEmpty) {
        await _localDatabaseRepository.saveLastSyncError(null);
      } else {
        await _localDatabaseRepository.saveLastSyncError(pushErrorMessage);
      }
      await refreshStatus(
        preferredPhase:
            pushErrorMessage != null && remainingPendingCount > 0
                ? SyncStatusPhase.error
                : remainingPendingCount > 0
                ? SyncStatusPhase.pending
                : SyncStatusPhase.synced,
      );
    } on DioException catch (error) {
      final message = _mapDioError(error);
      await _markNetworkFailure(
        queuedEvents,
        message,
        shouldStartConnectivityMonitoring: _shouldStartConnectivityMonitoring(
          error,
        ),
      );
    } on AuthSessionException catch (error) {
      await _localDatabaseRepository.saveLastSyncError(error.message);
      status.value = SyncStatusSnapshot(
        phase: SyncStatusPhase.error,
        pendingCount: pendingCount,
        lastSyncAt: await _localDatabaseRepository.getLastSyncAt(),
        lastError: error.message,
      );
    } catch (error) {
      final message = error.toString();
      await _localDatabaseRepository.saveLastSyncError(message);
      status.value = SyncStatusSnapshot(
        phase: SyncStatusPhase.error,
        pendingCount: pendingCount,
        lastSyncAt: await _localDatabaseRepository.getLastSyncAt(),
        lastError: message,
      );
    } finally {
      _isSyncing = false;
      final phase = status.value.phase.name;
      final remainingPending =
          await _localDatabaseRepository.getPendingSyncEventCount();
      final lastError = await _localDatabaseRepository.getLastSyncError();
      debugPrint(
        'SyncManager.syncNow reason=$reason done phase=$phase pending=$remainingPending lastError=${lastError ?? "-"}',
      );
    }
  }

  Future<void> checkConnectivityNow() async {
    final isReachable = await _canReachServer();
    if (!isReachable) {
      return;
    }
    _stopConnectivityMonitoring();
    await syncNow(reason: 'connectivity-restored');
  }

  Future<void> cacheRemoteCards(List<Map<String, dynamic>> cards) async {
    for (final card in cards) {
      await _upsertCardPayload(card);
    }
  }

  Future<void> cacheReviewQueueItems(
    List<Map<String, dynamic>> queueItems,
  ) async {
    for (final item in queueItems) {
      await _localDatabaseRepository.upsertCachedCard(
        id: item['id'] as String,
        sourceId: item['source_id'] as String,
        sourceTitle: item['source_title'] as String?,
        cardType: item['card_type'] as String? ?? 'definition',
        question: item['question'] as String? ?? '',
        answer: item['answer'] as String? ?? '',
        difficulty: item['difficulty'] as int? ?? 3,
        isActive: true,
        tagsJson: _encodeJson(item['tags']),
        updatedAt: DateTime.now().toUtc(),
      );
      await _localDatabaseRepository.upsertCachedMemoryState(
        cardId: item['id'] as String,
        stability: 0,
        difficulty: ((item['difficulty'] as num?) ?? 3).toDouble(),
        retrievability: 1,
        reps: item['reps'] as int? ?? 0,
        lapses: item['lapses'] as int? ?? 0,
        state: item['state'] as String? ?? 'new',
        nextReviewAt:
            item['next_review_at'] == null
                ? null
                : DateTime.parse(item['next_review_at'] as String).toUtc(),
        lastReviewAt: null,
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  Future<String?> _applyPushResponse(
    Map<String, dynamic> payload,
    List<dynamic> queuedEvents,
  ) async {
    final processedIds =
        ((payload['processed_event_ids'] as List?) ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList();
    final skippedIds =
        ((payload['skipped_event_ids'] as List?) ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList();
    await _localDatabaseRepository.removeQueuedSyncEvents([
      ...processedIds,
      ...skippedIds,
    ]);

    final queuedById = {
      for (final event in queuedEvents) event.id.toString(): event,
    };
    final errors =
        ((payload['errors'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    debugPrint(
      'SyncManager.push processed=${processedIds.length} skipped=${skippedIds.length} errors=${errors.length}',
    );

    String? firstErrorDetail;
    for (final error in errors) {
      final eventId = error['client_event_id']?.toString();
      final detail = error['detail']?.toString();
      if (eventId == null) {
        continue;
      }
      if (firstErrorDetail == null && detail != null && detail.isNotEmpty) {
        firstErrorDetail = detail;
      }
      final existing = queuedById[eventId];
      final nextRetryCount = ((existing?.retryCount ?? 0) + 1);
      await _localDatabaseRepository.markSyncEventFailed(
        id: eventId,
        retryCount: nextRetryCount,
        lastError: detail,
      );
      debugPrint(
        'SyncManager.push error eventId=$eventId retry=$nextRetryCount detail=${detail ?? "unknown"}',
      );
    }

    for (final card
        in ((payload['updated_cards'] as List?) ?? const <dynamic>[])) {
      if (card is Map) {
        await _upsertCardPayload(card.cast<String, dynamic>());
      }
    }
    for (final memoryState
        in ((payload['updated_memory_states'] as List?) ?? const <dynamic>[])) {
      if (memoryState is Map) {
        await _upsertMemoryStatePayload(memoryState.cast<String, dynamic>());
      }
    }
    await _applyPreferences(payload['preferences']);

    if (errors.isEmpty) {
      return null;
    }
    final label = errors.length == 1 ? 'change' : 'changes';
    return 'Server rejected ${errors.length} $label. ${firstErrorDetail ?? 'Open the logs for details.'}';
  }

  Future<void> _applyPullResponse(Map<String, dynamic> payload) async {
    final serverTimestamp = payload['server_timestamp']?.toString();
    final changes = (payload['changes'] as Map?)?.cast<String, dynamic>();
    if (changes != null) {
      for (final card in ((changes['cards'] as List?) ?? const <dynamic>[])) {
        if (card is Map) {
          await _upsertCardPayload(card.cast<String, dynamic>());
        }
      }
      for (final memoryState
          in ((changes['memory_states'] as List?) ?? const <dynamic>[])) {
        if (memoryState is Map) {
          await _upsertMemoryStatePayload(memoryState.cast<String, dynamic>());
        }
      }
      await _applyPreferences(changes['preferences']);
    }

    if (serverTimestamp != null && serverTimestamp.isNotEmpty) {
      final parsed = DateTime.tryParse(serverTimestamp)?.toUtc();
      if (parsed != null) {
        await _localDatabaseRepository.saveLastSyncAt(parsed);
      }
    }
  }

  Future<void> _applyPreferences(Object? rawPreferences) async {
    if (rawPreferences is! Map) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final preferences = rawPreferences.cast<String, dynamic>();
    final learningGoal = preferences['learning_goal'];
    if (learningGoal is String && learningGoal.isNotEmpty) {
      await prefs.setString('learning_goal', learningGoal);
      final deviceId = await _localDatabaseRepository.getMetadataValue(
        'device_id',
      );
      if (deviceId != null && deviceId.isNotEmpty) {
        await _localDatabaseRepository.saveSessionMetadata(
          deviceId: deviceId,
          userId: prefs.getString('user_id'),
          learningGoal: learningGoal,
        );
      }
    }
  }

  Future<void> _upsertCardPayload(Map<String, dynamic> card) async {
    final updatedAt =
        DateTime.tryParse(card['updated_at']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    await _localDatabaseRepository.upsertCachedCard(
      id: card['id'].toString(),
      sourceId: card['source_id'].toString(),
      sourceTitle: card['source_title']?.toString(),
      cardType: card['card_type'] as String? ?? 'definition',
      question: card['question'] as String? ?? '',
      answer: card['answer'] as String? ?? '',
      difficulty: (card['difficulty'] as int?) ?? 3,
      isActive: card['is_active'] as bool? ?? true,
      tagsJson: _encodeJson(card['tags']),
      updatedAt: updatedAt,
    );
  }

  Future<void> _upsertMemoryStatePayload(
    Map<String, dynamic> memoryState,
  ) async {
    final updatedAt =
        DateTime.tryParse(
          memoryState['updated_at']?.toString() ?? '',
        )?.toUtc() ??
        DateTime.now().toUtc();
    await _localDatabaseRepository.upsertCachedMemoryState(
      cardId: memoryState['card_id'].toString(),
      stability: ((memoryState['stability'] as num?) ?? 0).toDouble(),
      difficulty: ((memoryState['difficulty'] as num?) ?? 0).toDouble(),
      retrievability: ((memoryState['retrievability'] as num?) ?? 1).toDouble(),
      reps: memoryState['reps'] as int? ?? 0,
      lapses: memoryState['lapses'] as int? ?? 0,
      state: memoryState['state'] as String? ?? 'new',
      nextReviewAt:
          memoryState['next_review_at'] == null
              ? null
              : DateTime.parse(memoryState['next_review_at'] as String).toUtc(),
      lastReviewAt:
          memoryState['last_review_at'] == null
              ? null
              : DateTime.parse(memoryState['last_review_at'] as String).toUtc(),
      updatedAt: updatedAt,
    );
  }

  Future<void> _markNetworkFailure(
    List<dynamic> queuedEvents,
    String message, {
    bool shouldStartConnectivityMonitoring = false,
  }) async {
    if (queuedEvents.isEmpty) {
      await _localDatabaseRepository.saveLastSyncError(message);
      status.value = SyncStatusSnapshot(
        phase: SyncStatusPhase.error,
        pendingCount: 0,
        lastSyncAt: await _localDatabaseRepository.getLastSyncAt(),
        lastError: message,
      );
      return;
    }
    var hasExhaustedRetry = false;
    for (final event in queuedEvents) {
      final nextRetryCount = (event.retryCount + 1);
      if (nextRetryCount >= maxRetryCount) {
        hasExhaustedRetry = true;
      }
      await _localDatabaseRepository.markSyncEventFailed(
        id: event.id,
        retryCount: nextRetryCount,
        lastError: message,
      );
    }
    await _localDatabaseRepository.saveLastSyncError(message);
    status.value = SyncStatusSnapshot(
      phase:
          hasExhaustedRetry ? SyncStatusPhase.error : SyncStatusPhase.pending,
      pendingCount: queuedEvents.length,
      lastSyncAt: await _localDatabaseRepository.getLastSyncAt(),
      lastError: message,
    );
    if (shouldStartConnectivityMonitoring) {
      _startConnectivityMonitoring();
    }
  }

  void _startConnectivityMonitoring() {
    if (_connectivityTimer != null) {
      return;
    }
    _connectivityTimer = Timer.periodic(
      connectivityProbeInterval,
      (_) => unawaited(checkConnectivityNow()),
    );
  }

  void _stopConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }

  Future<bool> _canReachServer() async {
    try {
      return await _reachabilityProbe(_dio);
    } catch (_) {
      return false;
    }
  }

  bool _shouldStartConnectivityMonitoring(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  static Future<bool> _defaultReachabilityProbe(Dio dio) async {
    final healthUri = Uri.parse(dio.options.baseUrl).resolve('/health');
    final response = await dio.getUri<dynamic>(healthUri);
    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 && statusCode < 400;
  }

  String _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      return 'Sync failed with status $statusCode.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Sync timed out. Waiting for the next retry.';
      case DioExceptionType.connectionError:
        return 'Offline. Changes will sync when the connection returns.';
      case DioExceptionType.cancel:
        return 'Sync was cancelled.';
      case DioExceptionType.badCertificate:
        return 'The API certificate was rejected.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Sync failed unexpectedly.';
    }
  }

  String? _encodeJson(Object? value) {
    if (value == null) {
      return null;
    }
    return jsonEncode(value);
  }
}
