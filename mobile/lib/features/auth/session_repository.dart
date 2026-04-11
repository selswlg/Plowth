import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/local_database_repository.dart';
import '../../core/config/api_config.dart';

class AppLaunchState {
  const AppLaunchState({
    required this.deviceId,
    required this.onboardingComplete,
    required this.learningGoal,
    required this.accessToken,
    required this.refreshToken,
  });

  final String deviceId;
  final bool onboardingComplete;
  final String? learningGoal;
  final String? accessToken;
  final String? refreshToken;

  bool get hasSession => accessToken != null && accessToken!.isNotEmpty;
}

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.authProvider,
    required this.isGuest,
    required this.preferences,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final String? name;
  final String authProvider;
  final bool isGuest;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;

  String? get learningGoal {
    final value = preferences['learning_goal'];
    return value is String && value.isNotEmpty ? value : null;
  }

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    if (email != null && email!.isNotEmpty) {
      return email!;
    }
    return isGuest ? 'Guest account' : 'Account';
  }

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    final rawPreferences = json['preferences'];
    return AppUserProfile(
      id: json['id'].toString(),
      email: json['email'] as String?,
      name: json['name'] as String?,
      authProvider: json['auth_provider'] as String? ?? 'unknown',
      isGuest: json['is_guest'] as bool? ?? false,
      preferences:
          rawPreferences is Map<String, dynamic>
              ? rawPreferences
              : <String, dynamic>{},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class SessionException implements Exception {
  const SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionRepository {
  SessionRepository({
    Dio? dio,
    LocalDatabaseRepository? localDatabaseRepository,
  }) : _dio = dio ?? _buildDio(),
       _localDatabaseRepository =
           localDatabaseRepository ?? LocalDatabaseRepository();

  static const _deviceIdKey = 'device_id';
  static const _learningGoalKey = 'learning_goal';
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static final ValueNotifier<int> sessionInvalidated = ValueNotifier<int>(0);

  final Dio _dio;
  final LocalDatabaseRepository _localDatabaseRepository;

  Future<AppLaunchState> loadLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);
    final accessToken = prefs.getString(_accessTokenKey);
    final storedUserId = prefs.getString(_userIdKey);
    final userId =
        storedUserId ??
        (accessToken == null ? null : _extractUserIdFromJwt(accessToken));
    if (storedUserId == null && userId != null) {
      await prefs.setString(_userIdKey, userId);
    }
    final learningGoal = prefs.getString(_learningGoalKey);
    final onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;

    await _localDatabaseRepository.saveSessionMetadata(
      deviceId: deviceId,
      userId: userId,
      learningGoal: learningGoal,
      onboardingComplete: onboardingComplete,
    );

    return AppLaunchState(
      deviceId: deviceId,
      onboardingComplete: onboardingComplete,
      learningGoal: learningGoal,
      accessToken: accessToken,
      refreshToken: prefs.getString(_refreshTokenKey),
    );
  }

  Future<void> createGuestSession({required String learningGoal}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/guest',
        data: {'device_id': deviceId, 'learning_goal': learningGoal},
      );

      final payload = response.data;
      final accessToken = payload?['access_token'] as String?;
      final refreshToken = payload?['refresh_token'] as String?;
      if (accessToken == null || refreshToken == null) {
        throw const SessionException(
          'The API returned an incomplete auth response.',
        );
      }
      final userId = _extractUserIdFromJwt(accessToken);
      if (userId == null) {
        throw const SessionException(
          'The API returned an unreadable access token.',
        );
      }

      await _persistSessionState(
        prefs: prefs,
        deviceId: deviceId,
        userId: userId,
        learningGoal: learningGoal,
        accessToken: accessToken,
        refreshToken: refreshToken,
        onboardingComplete: true,
      );
      await _queueSettingsUpdateEvent(
        learningGoal: learningGoal,
        onboardingComplete: true,
        authProvider: 'guest',
      );
    } on DioException catch (error) {
      throw SessionException(_mapDioError(error));
    }
  }

  Future<void> register({
    required String learningGoal,
    required String email,
    required String password,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      final (accessToken, refreshToken) = _extractTokens(response.data);
      final profile = await _fetchCurrentUserProfile(accessToken: accessToken);
      final resolvedLearningGoal = profile.learningGoal ?? learningGoal;

      await _persistSessionState(
        prefs: prefs,
        deviceId: deviceId,
        userId: profile.id,
        learningGoal: resolvedLearningGoal,
        accessToken: accessToken,
        refreshToken: refreshToken,
        onboardingComplete: true,
      );
      await _queueSettingsUpdateEvent(
        learningGoal: resolvedLearningGoal,
        onboardingComplete: true,
        authProvider: profile.authProvider,
      );
    } on DioException catch (error) {
      throw SessionException(_mapDioError(error));
    }
  }

  Future<void> login({required String email, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final (accessToken, refreshToken) = _extractTokens(response.data);
      final profile = await _fetchCurrentUserProfile(accessToken: accessToken);
      final previousUserId = prefs.getString(_userIdKey);
      final preservedLocalGoal =
          previousUserId == null || previousUserId == profile.id
              ? prefs.getString(_learningGoalKey)
              : null;

      await _persistSessionState(
        prefs: prefs,
        deviceId: deviceId,
        userId: profile.id,
        learningGoal: profile.learningGoal ?? preservedLocalGoal,
        accessToken: accessToken,
        refreshToken: refreshToken,
        onboardingComplete: true,
      );
    } on DioException catch (error) {
      throw SessionException(_mapDioError(error));
    }
  }

  Future<void> upgradeGuest({
    required String email,
    required String password,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);
    final accessToken = prefs.getString(_accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionException('No authenticated guest session is stored.');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/upgrade',
        data: {
          'email': email,
          'password': password,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final (nextAccessToken, nextRefreshToken) = _extractTokens(response.data);
      final profile = await _fetchCurrentUserProfile(
        accessToken: nextAccessToken,
      );
      final previousUserId = prefs.getString(_userIdKey);
      final preservedLocalGoal =
          previousUserId == null || previousUserId == profile.id
              ? prefs.getString(_learningGoalKey)
              : null;
      final resolvedLearningGoal = profile.learningGoal ?? preservedLocalGoal;

      await _persistSessionState(
        prefs: prefs,
        deviceId: deviceId,
        userId: profile.id,
        learningGoal: resolvedLearningGoal,
        accessToken: nextAccessToken,
        refreshToken: nextRefreshToken,
        onboardingComplete: true,
      );
      await _queueSettingsUpdateEvent(
        learningGoal: resolvedLearningGoal,
        onboardingComplete: true,
        authProvider: profile.authProvider,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await clearStoredSession(notify: true);
      }
      throw SessionException(_mapDioError(error));
    }
  }

  Future<AppUserProfile> fetchCurrentUserProfile() async {
    try {
      return await _fetchCurrentUserProfile();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await clearStoredSession(notify: true);
      }
      throw SessionException(_mapDioError(error));
    }
  }

  Future<void> updateLearningGoal(String learningGoal) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);
    final userId = prefs.getString(_userIdKey);
    await prefs.setString(_learningGoalKey, learningGoal);
    await prefs.setBool(_onboardingCompleteKey, true);
    await _localDatabaseRepository.saveSessionMetadata(
      deviceId: deviceId,
      userId: userId,
      learningGoal: learningGoal,
      onboardingComplete: true,
    );
    await _queueSettingsUpdateEvent(
      learningGoal: learningGoal,
      onboardingComplete: true,
      authProvider: null,
    );
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final preservedLearningGoal = prefs.getString(_learningGoalKey);
    final preservedOnboarding = prefs.getBool(_onboardingCompleteKey) ?? false;

    await clearStoredSession();
    await prefs.remove(_userIdKey);
    await prefs.remove(_deviceIdKey);
    if (preservedLearningGoal != null && preservedLearningGoal.isNotEmpty) {
      await prefs.setString(_learningGoalKey, preservedLearningGoal);
    }
    await prefs.setBool(_onboardingCompleteKey, preservedOnboarding);
    await _localDatabaseRepository.clearUserScopedState();
  }

  static Future<void> clearStoredSession({
    bool notify = false,
    bool clearOnboarding = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    if (clearOnboarding) {
      await prefs.remove(_onboardingCompleteKey);
    }
    if (notify) {
      sessionInvalidated.value += 1;
    }
  }

  static String describeLearningGoal(String? value) {
    switch (value) {
      case 'exam':
        return 'Exam Prep';
      case 'language':
        return 'Language Learning';
      case 'professional':
        return 'Professional Growth';
      case 'self_improvement':
        return 'Self Improvement';
      default:
        return 'Learning Focus';
    }
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _generateDeviceId();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  String _generateDeviceId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final suffix =
        List.generate(
          12,
          (_) => alphabet[random.nextInt(alphabet.length)],
        ).join();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'plowth-$timestamp-$suffix';
  }

  String _buildSyncEventId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random();
    final suffix = random.nextInt(1 << 20).toRadixString(36);
    return 'evt-$timestamp-$suffix';
  }

  String _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      return 'API request failed with status $statusCode.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The API request timed out. Check the backend server and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to reach the backend API. Verify the server is running and the base URL is correct.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'The API certificate was rejected.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'The guest session request failed unexpectedly.';
    }
  }

  Future<void> _persistSessionState({
    required SharedPreferences prefs,
    required String deviceId,
    required String userId,
    required String? learningGoal,
    required String accessToken,
    required String refreshToken,
    required bool onboardingComplete,
  }) async {
    await _resetScopedStateIfNeeded(prefs: prefs, nextUserId: userId);
    await prefs.setString(_userIdKey, userId);
    if (learningGoal != null && learningGoal.isNotEmpty) {
      await prefs.setString(_learningGoalKey, learningGoal);
    } else {
      await prefs.remove(_learningGoalKey);
    }
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setBool(_onboardingCompleteKey, onboardingComplete);

    await _localDatabaseRepository.saveSessionMetadata(
      deviceId: deviceId,
      userId: userId,
      learningGoal: learningGoal,
      onboardingComplete: onboardingComplete,
    );
  }

  Future<void> _queueSettingsUpdateEvent({
    required String? learningGoal,
    required bool onboardingComplete,
    required String? authProvider,
  }) async {
    final payload = <String, dynamic>{
      'onboarding_complete': onboardingComplete,
    };
    if (learningGoal != null && learningGoal.isNotEmpty) {
      payload['learning_goal'] = learningGoal;
    }
    if (authProvider != null && authProvider.isNotEmpty) {
      payload['auth_provider'] = authProvider;
    }

    await _localDatabaseRepository.queueSyncEvent(
      id: _buildSyncEventId(),
      eventType: 'settings_update',
      eventPayload: jsonEncode(payload),
    );
  }

  (String, String) _extractTokens(Map<String, dynamic>? payload) {
    final accessToken = payload?['access_token'] as String?;
    final refreshToken = payload?['refresh_token'] as String?;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const SessionException(
        'The API returned an incomplete auth response.',
      );
    }
    return (accessToken, refreshToken);
  }

  Future<AppUserProfile> _fetchCurrentUserProfile({String? accessToken}) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedAccessToken = accessToken ?? prefs.getString(_accessTokenKey);
    if (resolvedAccessToken == null || resolvedAccessToken.isEmpty) {
      throw const SessionException(
        'No authenticated session found on this device.',
      );
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(
        headers: {'Authorization': 'Bearer $resolvedAccessToken'},
      ),
    );
    final payload = response.data;
    if (payload == null) {
      throw const SessionException(
        'The API returned an incomplete profile response.',
      );
    }
    final profile = AppUserProfile.fromJson(payload);
    final storedUserId = prefs.getString(_userIdKey);
    if (storedUserId == null || storedUserId.isEmpty) {
      await prefs.setString(_userIdKey, profile.id);
    }
    final learningGoal = profile.learningGoal;
    final deviceId = await _getOrCreateDeviceId(prefs);
    if (learningGoal != null && learningGoal.isNotEmpty) {
      await prefs.setString(_learningGoalKey, learningGoal);
    }
    await _localDatabaseRepository.saveSessionMetadata(
      deviceId: deviceId,
      userId: profile.id,
      learningGoal: learningGoal,
    );
    return profile;
  }

  Future<void> _resetScopedStateIfNeeded({
    required SharedPreferences prefs,
    required String nextUserId,
  }) async {
    final previousUserId = prefs.getString(_userIdKey);
    if (previousUserId == null ||
        previousUserId.isEmpty ||
        previousUserId == nextUserId) {
      return;
    }

    await _localDatabaseRepository.clearUserScopedState();
    await prefs.remove(_learningGoalKey);
    await prefs.remove(_onboardingCompleteKey);
  }

  String? _extractUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final subject = payload['sub']?.toString();
      if (subject == null || subject.isEmpty) {
        return null;
      }
      return subject;
    } catch (_) {
      return null;
    }
  }
}
