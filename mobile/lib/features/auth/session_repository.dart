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
  static final ValueNotifier<int> sessionInvalidated = ValueNotifier<int>(0);

  final Dio _dio;
  final LocalDatabaseRepository _localDatabaseRepository;

  Future<AppLaunchState> loadLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getOrCreateDeviceId(prefs);
    final learningGoal = prefs.getString(_learningGoalKey);
    final onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;

    await _localDatabaseRepository.saveSessionMetadata(
      deviceId: deviceId,
      learningGoal: learningGoal,
      onboardingComplete: onboardingComplete,
    );

    return AppLaunchState(
      deviceId: deviceId,
      onboardingComplete: onboardingComplete,
      learningGoal: learningGoal,
      accessToken: prefs.getString(_accessTokenKey),
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

      await prefs.setString(_learningGoalKey, learningGoal);
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
      await prefs.setBool(_onboardingCompleteKey, true);

      await _localDatabaseRepository.saveSessionMetadata(
        deviceId: deviceId,
        learningGoal: learningGoal,
        onboardingComplete: true,
      );
      await _localDatabaseRepository.queueSyncEvent(
        id: _buildSyncEventId(),
        eventType: 'settings_update',
        eventPayload: jsonEncode({
          'learning_goal': learningGoal,
          'onboarding_complete': true,
          'auth_provider': 'guest',
        }),
      );
    } on DioException catch (error) {
      throw SessionException(_mapDioError(error));
    }
  }

  Future<void> clearSession() async {
    await clearStoredSession();
  }

  static Future<void> clearStoredSession({bool notify = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_onboardingCompleteKey);
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
}
