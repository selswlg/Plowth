import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plowth_app/core/database/app_database.dart';
import 'package:plowth_app/core/database/local_database_repository.dart';
import 'package:plowth_app/features/sync_manager.dart';

void main() {
  group('SyncManager', () {
    late AppDatabase database;
    late LocalDatabaseRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalDatabaseRepository(database: database);
      await repository.saveSessionMetadata(
        deviceId: 'device-123',
        learningGoal: 'exam',
        onboardingComplete: true,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'retries queued work when connectivity returns and reconciles pull data',
      () async {
        var online = false;
        final adapter = _MockHttpClientAdapter((options) async {
          switch (options.uri.path) {
            case '/api/v1/sync/push':
              if (!online) {
                throw DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'offline',
                );
              }
              return _jsonResponse({
                'processed': 1,
                'skipped': 0,
                'errors': const [],
                'processed_event_ids': ['evt-1'],
                'skipped_event_ids': const [],
                'updated_cards': [
                  {
                    'id': 'card-1',
                    'source_id': 'source-1',
                    'source_title': 'Biology Notes',
                    'card_type': 'definition',
                    'question': 'What is ATP?',
                    'answer': 'Energy currency from push',
                    'difficulty': 3,
                    'is_active': true,
                    'tags': {'domain_hint': 'exam'},
                    'updated_at': '2026-04-11T12:00:00Z',
                  },
                ],
                'updated_memory_states': [
                  {
                    'card_id': 'card-1',
                    'stability': 1.4,
                    'difficulty': 3.5,
                    'retrievability': 0.6,
                    'reps': 1,
                    'lapses': 0,
                    'state': 'learning',
                    'next_review_at': '2026-04-12T12:00:00Z',
                    'last_review_at': '2026-04-11T12:00:00Z',
                    'updated_at': '2026-04-11T12:00:00Z',
                  },
                ],
                'preferences': null,
                'server_timestamp': '2026-04-11T12:00:00Z',
              });
            case '/api/v1/sync/pull':
              return _jsonResponse({
                'server_timestamp': '2026-04-11T12:05:00Z',
                'changes': {
                  'cards': [
                    {
                      'id': 'card-1',
                      'source_id': 'source-1',
                      'source_title': 'Biology Notes',
                      'card_type': 'definition',
                      'question': 'What is ATP?',
                      'answer': 'Energy currency from pull',
                      'difficulty': 4,
                      'is_active': true,
                      'tags': {'domain_hint': 'exam'},
                      'updated_at': '2026-04-11T12:05:00Z',
                    },
                  ],
                  'memory_states': [
                    {
                      'card_id': 'card-1',
                      'stability': 2.1,
                      'difficulty': 3.2,
                      'retrievability': 0.92,
                      'reps': 2,
                      'lapses': 0,
                      'state': 'review',
                      'next_review_at': '2026-04-13T12:05:00Z',
                      'last_review_at': '2026-04-11T12:05:00Z',
                      'updated_at': '2026-04-11T12:05:00Z',
                    },
                  ],
                  'preferences': {'learning_goal': 'exam'},
                },
              });
          }
          throw StateError('Unexpected request to ${options.uri}');
        });

        final manager = _buildManager(
          repository: repository,
          adapter: adapter,
          reachabilityProbe: (_) async => online,
        );
        addTearDown(manager.stop);

        await repository.queueSyncEvent(
          id: 'evt-1',
          eventType: 'review',
          eventPayload: jsonEncode({
            'card_id': 'card-1',
            'rating': 'good',
            'response_time_ms': 2200,
          }),
          createdAt: DateTime.utc(2026, 4, 11, 11, 59, 0),
        );

        await manager.syncNow(reason: 'offline-test');

        final pendingBeforeReconnect = await repository.getQueuedSyncEvents();
        expect(pendingBeforeReconnect, hasLength(1));
        expect(pendingBeforeReconnect.first.retryCount, 1);
        expect(manager.status.value.phase, SyncStatusPhase.pending);
        expect(manager.connectivityMonitoringActive, isTrue);

        online = true;
        await manager.checkConnectivityNow();

        expect(await repository.getPendingSyncEventCount(), 0);
        expect(manager.status.value.phase, SyncStatusPhase.synced);
        expect(manager.connectivityMonitoringActive, isFalse);
        expect(
          await repository.getLastSyncAt(),
          DateTime.utc(2026, 4, 11, 12, 5),
        );

        final card = await repository.getCachedCard('card-1');
        final memoryState = await repository.getCachedMemoryState('card-1');
        expect(card?.answer, 'Energy currency from pull');
        expect(card?.difficulty, 4);
        expect(memoryState?.state, 'review');
        expect(memoryState?.reps, 2);
        expect(memoryState?.retrievability, closeTo(0.92, 0.0001));
      },
    );

    test(
      'does not re-mark processed events when pull fails after push succeeds',
      () async {
        final adapter = _MockHttpClientAdapter((options) async {
          switch (options.uri.path) {
            case '/api/v1/sync/push':
              return _jsonResponse({
                'processed': 1,
                'skipped': 0,
                'errors': const [],
                'processed_event_ids': ['evt-2'],
                'skipped_event_ids': const [],
                'updated_cards': [
                  {
                    'id': 'card-2',
                    'source_id': 'source-2',
                    'source_title': 'Chemistry Notes',
                    'card_type': 'definition',
                    'question': 'What is a mole?',
                    'answer': 'An amount of substance.',
                    'difficulty': 2,
                    'is_active': true,
                    'tags': null,
                    'updated_at': '2026-04-11T13:00:00Z',
                  },
                ],
                'updated_memory_states': const [],
                'preferences': null,
                'server_timestamp': '2026-04-11T13:00:00Z',
              });
            case '/api/v1/sync/pull':
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'offline again',
              );
          }
          throw StateError('Unexpected request to ${options.uri}');
        });

        final manager = _buildManager(repository: repository, adapter: adapter);
        addTearDown(manager.stop);

        await repository.queueSyncEvent(
          id: 'evt-2',
          eventType: 'review',
          eventPayload: jsonEncode({
            'card_id': 'card-2',
            'rating': 'easy',
            'response_time_ms': 1800,
          }),
          createdAt: DateTime.utc(2026, 4, 11, 12, 59, 0),
        );

        await manager.syncNow(reason: 'push-then-pull-fail');

        expect(await repository.getPendingSyncEventCount(), 0);
        expect(manager.status.value.phase, SyncStatusPhase.error);
        expect(manager.status.value.pendingCount, 0);
        expect(manager.connectivityMonitoringActive, isFalse);

        final card = await repository.getCachedCard('card-2');
        expect(card?.sourceTitle, 'Chemistry Notes');
        expect(await repository.getLastSyncError(), contains('Offline'));
      },
    );

    test(
      'does not advance last sync watermark when pull reconciliation fails',
      () async {
        await repository.saveLastSyncAt(DateTime.utc(2026, 4, 11, 13, 30));

        final adapter = _MockHttpClientAdapter((options) async {
          switch (options.uri.path) {
            case '/api/v1/sync/pull':
              return _jsonResponse({
                'server_timestamp': '2026-04-11T14:00:00Z',
                'changes': {
                  'cards': const [],
                  'memory_states': [
                    {
                      'card_id': 'card-3',
                      'stability': 2.1,
                      'difficulty': 3.2,
                      'retrievability': 0.92,
                      'reps': 2,
                      'lapses': 0,
                      'state': 'review',
                      'next_review_at': 'not-a-date',
                      'last_review_at': '2026-04-11T12:05:00Z',
                      'updated_at': '2026-04-11T12:05:00Z',
                    },
                  ],
                  'preferences': null,
                },
              });
          }
          throw StateError('Unexpected request to ${options.uri}');
        });

        final manager = _buildManager(repository: repository, adapter: adapter);
        addTearDown(manager.stop);

        await manager.syncNow(reason: 'invalid-pull-payload');

        expect(
          await repository.getLastSyncAt(),
          DateTime.utc(2026, 4, 11, 13, 30),
        );
        expect(manager.status.value.phase, SyncStatusPhase.error);
        expect(
          await repository.getLastSyncError(),
          contains('FormatException'),
        );
      },
    );

    test(
      'surfaces push response errors instead of silently staying pending',
      () async {
        final adapter = _MockHttpClientAdapter((options) async {
          switch (options.uri.path) {
            case '/api/v1/sync/push':
              return _jsonResponse({
                'processed': 0,
                'skipped': 0,
                'errors': [
                  {'client_event_id': 'evt-3', 'detail': 'Card not found.'},
                ],
                'processed_event_ids': const [],
                'skipped_event_ids': const [],
                'updated_cards': const [],
                'updated_memory_states': const [],
                'preferences': null,
                'server_timestamp': '2026-04-11T14:00:00Z',
              });
            case '/api/v1/sync/pull':
              return _jsonResponse({
                'server_timestamp': '2026-04-11T14:05:00Z',
                'changes': {
                  'cards': const [],
                  'memory_states': const [],
                  'preferences': null,
                },
              });
          }
          throw StateError('Unexpected request to ${options.uri}');
        });

        final manager = _buildManager(repository: repository, adapter: adapter);
        addTearDown(manager.stop);

        await repository.queueSyncEvent(
          id: 'evt-3',
          eventType: 'review',
          eventPayload: jsonEncode({
            'card_id': 'missing-card',
            'rating': 'good',
            'response_time_ms': 1200,
          }),
          createdAt: DateTime.utc(2026, 4, 11, 13, 59, 0),
        );

        await manager.syncNow(reason: 'push-error');

        final queuedEvents = await repository.getQueuedSyncEvents();
        expect(queuedEvents, hasLength(1));
        expect(queuedEvents.first.retryCount, 1);
        expect(manager.status.value.phase, SyncStatusPhase.error);
        expect(
          await repository.getLastSyncError(),
          contains('Card not found.'),
        );
      },
    );
  });
}

SyncManager _buildManager({
  required LocalDatabaseRepository repository,
  required HttpClientAdapter adapter,
  Future<bool> Function(Dio dio)? reachabilityProbe,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000/api/v1',
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..httpClientAdapter = adapter;

  return SyncManager(
    dio: dio,
    localDatabaseRepository: repository,
    authorizeSession: (_) async => 'test-token',
    reachabilityProbe: reachabilityProbe ?? (_) async => true,
    connectivityProbeInterval: const Duration(minutes: 1),
  );
}

ResponseBody _jsonResponse(
  Map<String, Object?> payload, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}
