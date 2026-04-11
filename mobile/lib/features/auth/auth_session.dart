import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import 'session_repository.dart';

class AuthSession {
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  @visibleForTesting
  static Dio Function()? dioFactoryOverride;

  static Future<String> authorize(Dio dio) async {
    final prefs = await SharedPreferences.getInstance();
    var accessToken = prefs.getString(accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthSessionException(
        'No authenticated session found on this device.',
      );
    }

    if (_isJwtExpired(accessToken)) {
      accessToken = await _refreshAccessToken(prefs);
    }

    dio.options.headers['Authorization'] = 'Bearer $accessToken';
    return accessToken;
  }

  static Future<String> _refreshAccessToken(SharedPreferences prefs) async {
    final refreshToken = prefs.getString(refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearStoredTokens();
      throw const AuthSessionException(
        'Your session expired. Start a new session.',
      );
    }

    try {
      final response = await _buildDio().post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final payload = response.data;
      final accessToken = payload?['access_token'] as String?;
      final nextRefreshToken = payload?['refresh_token'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          nextRefreshToken == null ||
          nextRefreshToken.isEmpty) {
        throw const AuthSessionException(
          'The API returned an incomplete auth response.',
        );
      }

      await prefs.setString(accessTokenKey, accessToken);
      await prefs.setString(refreshTokenKey, nextRefreshToken);
      return accessToken;
    } on DioException catch (error) {
      if (_shouldClearSession(error)) {
        await _clearStoredTokens();
        throw const AuthSessionException(
          'Your session expired. Start a new session.',
        );
      }
      throw AuthSessionException(_mapRefreshError(error));
    }
  }

  static Future<void> _clearStoredTokens() async {
    await SessionRepository.clearStoredSession(notify: true);
  }

  static bool _shouldClearSession(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == null) {
      return false;
    }
    return statusCode >= 400 && statusCode < 500;
  }

  static String _mapRefreshError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Unable to refresh the session while offline. Local data is still available on this device.';
      case DioExceptionType.badCertificate:
        return 'The API certificate was rejected.';
      case DioExceptionType.badResponse:
        return 'The session refresh request failed unexpectedly.';
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return 'Unable to refresh the session right now.';
    }
  }

  static Dio _buildDio() {
    final override = dioFactoryOverride;
    if (override != null) {
      return override();
    }
    return Dio(
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
    );
  }

  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return true;
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) {
        return true;
      }
      final expiresAtSeconds = payload['exp'];
      if (expiresAtSeconds is! num) {
        return true;
      }
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiresAtSeconds.toInt() * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().isAfter(
        expiresAt.subtract(const Duration(seconds: 30)),
      );
    } catch (_) {
      return true;
    }
  }
}

class AuthSessionException implements Exception {
  const AuthSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}
