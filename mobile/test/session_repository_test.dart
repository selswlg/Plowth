import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plowth_app/core/database/app_database.dart';
import 'package:plowth_app/core/database/local_database_repository.dart';
import 'package:plowth_app/features/auth/session_repository.dart';

void main() {
  group('SessionRepository', () {
    late AppDatabase database;
    late LocalDatabaseRepository localRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase(executor: NativeDatabase.memory());
      localRepository = LocalDatabaseRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('register stores tokens, learning goal, and sync event', () async {
      final repository = _buildRepository(
        localRepository: localRepository,
        handler: (options) async {
          switch (options.uri.path) {
            case '/auth/register':
              final body = options.data as Map<String, dynamic>;
              expect(body['email'], 'learner@example.com');
              expect(body['password'], 'password123');
              expect(body['name'], 'Learner');
              return _jsonResponse({
                'access_token': 'register-access',
                'refresh_token': 'register-refresh',
              }, statusCode: 201);
            case '/auth/me':
              expect(
                options.headers['Authorization'],
                'Bearer register-access',
              );
              return _jsonResponse({
                'id': '16be4d4d-0b90-4b6a-b943-087c2ba7f35c',
                'email': 'learner@example.com',
                'name': 'Learner',
                'auth_provider': 'email',
                'is_guest': false,
                'preferences': <String, dynamic>{},
                'created_at': '2026-04-11T10:00:00Z',
              });
          }
          throw StateError('Unexpected request to ${options.uri.path}');
        },
      );

      await repository.register(
        learningGoal: 'exam',
        email: 'learner@example.com',
        password: 'password123',
        name: 'Learner',
      );

      final prefs = await SharedPreferences.getInstance();
      final queuedEvents = await localRepository.getQueuedSyncEvents();

      expect(prefs.getString('access_token'), 'register-access');
      expect(prefs.getString('refresh_token'), 'register-refresh');
      expect(
        prefs.getString('user_id'),
        '16be4d4d-0b90-4b6a-b943-087c2ba7f35c',
      );
      expect(prefs.getString('learning_goal'), 'exam');
      expect(prefs.getBool('onboarding_complete'), isTrue);
      expect(queuedEvents, hasLength(1));
      expect(queuedEvents.first.eventType, 'settings_update');
      expect(
        jsonDecode(queuedEvents.first.eventPayload),
        containsPair('learning_goal', 'exam'),
      );
      expect(
        jsonDecode(queuedEvents.first.eventPayload),
        containsPair('auth_provider', 'email'),
      );
    });

    test('login adopts the server profile learning goal', () async {
      final repository = _buildRepository(
        localRepository: localRepository,
        handler: (options) async {
          switch (options.uri.path) {
            case '/auth/login':
              return _jsonResponse({
                'access_token': 'login-access',
                'refresh_token': 'login-refresh',
              });
            case '/auth/me':
              return _jsonResponse({
                'id': '3a4d91ae-b8fd-4e6f-ac7a-35df0f5095c1',
                'email': 'returning@example.com',
                'name': 'Returning User',
                'auth_provider': 'email',
                'is_guest': false,
                'preferences': {'learning_goal': 'language'},
                'created_at': '2026-04-11T11:00:00Z',
              });
          }
          throw StateError('Unexpected request to ${options.uri.path}');
        },
      );

      await repository.login(
        email: 'returning@example.com',
        password: 'password123',
      );

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('access_token'), 'login-access');
      expect(prefs.getString('refresh_token'), 'login-refresh');
      expect(
        prefs.getString('user_id'),
        '3a4d91ae-b8fd-4e6f-ac7a-35df0f5095c1',
      );
      expect(prefs.getString('learning_goal'), 'language');
      expect(
        await localRepository.getMetadataValue('learning_goal'),
        'language',
      );
      expect(await localRepository.getPendingSyncEventCount(), 0);
    });

    test(
      'upgrade guest keeps goal, swaps tokens, and queues settings sync',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_id', 'device-123');
        await prefs.setString('access_token', 'guest-access');
        await prefs.setString('refresh_token', 'guest-refresh');
        await prefs.setString('learning_goal', 'professional');
        await prefs.setBool('onboarding_complete', true);
        await localRepository.saveSessionMetadata(
          deviceId: 'device-123',
          learningGoal: 'professional',
          onboardingComplete: true,
        );

        final repository = _buildRepository(
          localRepository: localRepository,
          handler: (options) async {
            switch (options.uri.path) {
              case '/auth/upgrade':
                expect(options.headers['Authorization'], 'Bearer guest-access');
                return _jsonResponse({
                  'access_token': 'upgraded-access',
                  'refresh_token': 'upgraded-refresh',
                });
              case '/auth/me':
                expect(
                  options.headers['Authorization'],
                  'Bearer upgraded-access',
                );
                return _jsonResponse({
                  'id': 'aa3390fc-9d4f-4d8d-b452-7384e6a163c7',
                  'email': 'guest@example.com',
                  'name': 'Guest Upgrade',
                  'auth_provider': 'email',
                  'is_guest': false,
                  'preferences': {'learning_goal': 'professional'},
                  'created_at': '2026-04-11T12:00:00Z',
                });
            }
            throw StateError('Unexpected request to ${options.uri.path}');
          },
        );

        await repository.upgradeGuest(
          email: 'guest@example.com',
          password: 'password123',
          name: 'Guest Upgrade',
        );

        final queuedEvents = await localRepository.getQueuedSyncEvents();

        expect(prefs.getString('access_token'), 'upgraded-access');
        expect(prefs.getString('refresh_token'), 'upgraded-refresh');
        expect(
          prefs.getString('user_id'),
          'aa3390fc-9d4f-4d8d-b452-7384e6a163c7',
        );
        expect(queuedEvents, hasLength(1));
        expect(
          jsonDecode(queuedEvents.first.eventPayload),
          containsPair('learning_goal', 'professional'),
        );
        expect(
          jsonDecode(queuedEvents.first.eventPayload),
          containsPair('auth_provider', 'email'),
        );
      },
    );

    test(
      'login clears queued sync state when a different user signs in',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_id', 'device-123');
        await prefs.setString('user_id', 'guest-user');
        await prefs.setString('learning_goal', 'professional');
        await prefs.setBool('onboarding_complete', true);
        await localRepository.saveSessionMetadata(
          deviceId: 'device-123',
          userId: 'guest-user',
          learningGoal: 'professional',
          onboardingComplete: true,
        );
        await localRepository.queueSyncEvent(
          id: 'evt-stale',
          eventType: 'review',
          eventPayload: '{"card_id":"card-1","rating":"good"}',
        );
        await localRepository.upsertCachedCard(
          id: 'card-1',
          sourceId: 'source-1',
          sourceTitle: 'Old Account',
          cardType: 'definition',
          question: 'Old question',
          answer: 'Old answer',
          difficulty: 3,
          isActive: true,
          updatedAt: DateTime.utc(2026, 4, 11, 9),
        );

        final repository = _buildRepository(
          localRepository: localRepository,
          handler: (options) async {
            switch (options.uri.path) {
              case '/auth/login':
                return _jsonResponse({
                  'access_token': 'new-access',
                  'refresh_token': 'new-refresh',
                });
              case '/auth/me':
                return _jsonResponse({
                  'id': 'new-user-id',
                  'email': 'new@example.com',
                  'name': 'New User',
                  'auth_provider': 'email',
                  'is_guest': false,
                  'preferences': <String, dynamic>{},
                  'created_at': '2026-04-11T13:00:00Z',
                });
            }
            throw StateError('Unexpected request to ${options.uri.path}');
          },
        );

        await repository.login(
          email: 'new@example.com',
          password: 'password123',
        );

        expect(prefs.getString('user_id'), 'new-user-id');
        expect(prefs.getString('learning_goal'), isNull);
        expect(await localRepository.getPendingSyncEventCount(), 0);
        expect(await localRepository.getCachedCard('card-1'), isNull);
        expect(await localRepository.getLastSyncAt(), isNull);
        expect(await localRepository.getLastSyncError(), isNull);
      },
    );

    test(
      'clearSession resets device identity and clears user-scoped cache',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_id', 'device-123');
        await prefs.setString('access_token', 'old-access');
        await prefs.setString('refresh_token', 'old-refresh');
        await prefs.setString('user_id', 'old-user');
        await prefs.setString('learning_goal', 'professional');
        await prefs.setBool('onboarding_complete', true);
        await localRepository.saveSessionMetadata(
          deviceId: 'device-123',
          userId: 'old-user',
          learningGoal: 'professional',
          onboardingComplete: true,
        );
        await localRepository.queueSyncEvent(
          id: 'evt-stale',
          eventType: 'review',
          eventPayload: '{"card_id":"card-1","rating":"good"}',
        );
        await localRepository.upsertCachedCard(
          id: 'card-1',
          sourceId: 'source-1',
          sourceTitle: 'Old Account',
          cardType: 'definition',
          question: 'Old question',
          answer: 'Old answer',
          difficulty: 3,
          isActive: true,
          updatedAt: DateTime.utc(2026, 4, 11, 9),
        );

        final repository = _buildRepository(
          localRepository: localRepository,
          handler: (_) async => throw UnimplementedError(),
        );

        await repository.clearSession();

        expect(prefs.getString('access_token'), isNull);
        expect(prefs.getString('refresh_token'), isNull);
        expect(prefs.getString('user_id'), isNull);
        expect(prefs.getString('device_id'), isNull);
        expect(prefs.getString('learning_goal'), 'professional');
        expect(prefs.getBool('onboarding_complete'), isTrue);
        expect(await localRepository.getPendingSyncEventCount(), 0);
        expect(await localRepository.getCachedCard('card-1'), isNull);
        expect(await localRepository.getMetadataValue('user_id'), isNull);

        final launchState = await repository.loadLaunchState();
        expect(launchState.deviceId, isNot('device-123'));
        expect(launchState.learningGoal, 'professional');
        expect(launchState.onboardingComplete, isTrue);
        expect(launchState.hasSession, isFalse);
      },
    );
  });
}

SessionRepository _buildRepository({
  required LocalDatabaseRepository localRepository,
  required Future<ResponseBody> Function(RequestOptions options) handler,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000',
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..httpClientAdapter = _MockHttpClientAdapter(handler);

  return SessionRepository(dio: dio, localDatabaseRepository: localRepository);
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
